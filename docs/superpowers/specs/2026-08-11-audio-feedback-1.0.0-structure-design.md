# audio-feedback 1.0.0 — Spec A: Runtime & Structure

Date: 2026-08-11
Branch: `feat/audio-feedback-sound-redesign`
Status: Approved design, pre-implementation

## Context

The audio-feedback plugin plays non-speech WAV cues on Claude Code hook
events. Today it is pure bash + `paplay`: `hooks/play-sound.sh` resolves an
event to a WAV via `scripts/lib.sh` and spawns a detached `paplay` per event.

Two problems motivate 1.0.0:

1. **Process/resource proliferation.** Every event spawns its own `paplay`
   process. With N concurrent agents (e.g. SubagentStop across a fan-out),
   up to N `paplay` processes appear in the process list and N transient
   PipeWire client entries churn, consuming resources.
2. **Accumulated cruft.** The click-sounds subsystem (token-scaled click
   sequences) never served its purpose and is being removed, along with its
   `sox` runtime dependency.

The 1.0.0 work was decomposed into two specs:

- **Spec A (this document) — Runtime & Structure:** clicks removal,
  freedesktop-style theme layout, and a resident playback daemon that
  collapses N players into one.
- **Spec B (later) — Sound design & generation pipeline:** the pyo-based
  generation of the actual default-theme timbres, populating each theme's
  `src/` and `sounds/` directories.

Spec A is purely runtime and structure. It ships no new sound content.

## Goals

- Collapse concurrent playback to **one process and one PipeWire client**,
  regardless of agent count.
- Remove the click subsystem and the `sox` runtime dependency entirely.
- Adopt a freedesktop-*inspired* theme directory layout (layout only, not
  full XDG spec compliance).
- Preserve the existing bash config/resolution layer (themes, per-event
  sounds, `off` gate, subtype resolution) unchanged.
- Degrade gracefully: the plugin must never go silent if the daemon or its
  dependencies are unavailable.

## Non-goals

- Full freedesktop XDG sound-theme-spec compliance (standard event names,
  theme inheritance). We borrow the folder shape only.
- The actual sound design / generation pipeline (Spec B).
- systemd unit management (auto-spawn is used instead).

---

## Section 1 — Structure

### 1.1 Clicks removal

The click-sounds subsystem is removed. Already implemented this session:

- `scripts/lib.sh`: removed `af_default_clicks_*`, `AF_CLICKS_*` load +
  init, `af_clicks_enabled_for`, `af_tokens_from_transcript`,
  `af_clicks_duration`, `af_clicks_base_gap`, `af_render_clicks`,
  `af_play_clicks`, `AF_CLICK_DUR`.
- `scripts/config.sh`: removed `CLICKS_*` from `VALID_KEYS`, the display
  block, and the validation case arms.
- `hooks/play-sound.sh`: removed token extraction and the click-play block.
- Docs (`README.md`, `skills/audio-feedback/SKILL.md`): removed click
  feature descriptions, config tables, and trigger phrases.
- Deleted `tests/test_clicks.sh` and `.superpowers/tools/click-designer/`.
- `sox` dropped as a runtime dependency (`jq` retained for subtype
  resolution).

Existing user configs may carry stale `CLICKS_*` lines; `af_load_config`
ignores unknown keys, so they become harmless orphans. Noted in CHANGELOG.

### 1.2 Freedesktop-inspired theme layout (layout only)

New per-theme structure:

```
plugins/audio-feedback/
  sound-theme/
    default/
      theme.json           # {"name": "Default", "comment": "..."}
      sounds/              # rendered WAVs (stop.wav, pre-tool-use-execute.wav, ...)
      src/                 # generators (populated in Spec B; empty for now)
```

- Metadata file is `theme.json` (not XDG's `index.theme`) — consistent with
  `plugin.json` across the marketplace, parsed with `jq` (already a dep).
  Shape: `{"name": "Default", "comment": "short description"}`.
- Claude event names are kept (`stop.wav`, `pre-tool-use-execute.wav`, ...).
  No remapping to XDG standard names, no inheritance.

Code changes:

- `_af_sounds_base` → `.../sound-theme`.
- `_af_sounds_dir` → `.../sound-theme/<theme>/sounds`.
- `config.sh` theme listing enumerates `sound-theme/*/` directories that
  contain a `theme.json`; may surface `name`/`comment`.

Migration:

- Move existing `sounds/default/*.wav` → `sound-theme/default/sounds/`.
- Add `sound-theme/default/theme.json`.
- Remove the click-era `sounds/src/` scratch (venv, `click_pyo.py`).
- Assert no code references the old `sounds/<theme>/` path.

---

## Section 2 — Playback daemon architecture

Two components with a clean split: bash owns config/resolution, the daemon
owns audio output.

### 2.1 `play-sound.sh` (hook client — stays bash)

Per event:

1. Resolve event → absolute WAV path via existing `lib.sh` logic (theme +
   subtype + `off` gate — unchanged).
2. If `ENABLED=false` or the resolved sound is `off`: send nothing, exit.
3. Otherwise run `af-soundd play` under the **bare system `python3`**
   (stdlib only — `socket`/`os`/`fcntl`), which connects to the daemon
   socket and sends the path.
4. If no daemon is running: `play` spawns it detached (`setsid` +
   double-fork) via `uv run --script af-soundd daemon …`, guarded by a
   `flock` so concurrent agents cannot race two daemons into existence.
5. If `uv` is absent (or delivery fails): fall back to `paplay <path>`
   (today's behaviour). The `uv` probe result is cached.

### 2.2 Dependency model — uv + PEP 723 (no managed venv)

The daemon's python deps (`sounddevice`, `soundfile`, `numpy`) are declared
as **PEP 723 inline script metadata** at the top of `af-soundd`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["sounddevice", "soundfile", "numpy"]
# ///
```

The daemon is launched with `uv run --script af-soundd daemon …`; uv builds
and **caches** an ephemeral environment (`~/.cache/uv`) from that block —
no venv to create or manage, no bootstrap step. The **client** path
(`play`, and the socket send) imports only stdlib, so it runs under bare
`python3` with zero deps — that is the per-event hot path. numpy et al. are
imported lazily inside daemon-only functions, so `python3 af-soundd play`
never touches them. Net runtime dependency added: **`uv`** (plus a
near-universal `python3`).

### 2.3 `af-soundd` daemon behaviour

- Listens on a Unix domain socket at
  `$XDG_RUNTIME_DIR/audio-feedback.sock` (per-user, tmpfs, auto-cleaned).
- Holds **one** persistent `sounddevice` output stream — one PipeWire
  client — for its whole lifetime.
- On each received path: load the WAV via `soundfile` (with an in-memory
  cache keyed by path), mix it into the running output buffer via numpy
  addition.
- Overlap is allowed. Simultaneous voices are capped at `DAEMON_MAX_VOICES`
  (drop the oldest voice beyond the cap) to bound CPU. **The cap value is to
  be tuned during implementation.**
- Self-exits after `DAEMON_IDLE_TIMEOUT` seconds with no events, releasing
  the PipeWire client and returning idle footprint to zero.

### 2.4 IPC message format

One absolute WAV path per line, newline-terminated. The daemon is
deliberately dumb: it has zero config knowledge and only plays the paths it
is given. A `quit` control verb may be added later; not required for 1.0.0.

### 2.5 Data flow

```
hook event -> lib.sh resolves path -> python3 af-soundd play -> socket -> daemon mixes -> 1 PipeWire stream
                                                                 |
                                                                 +-- (no daemon) --> uv run --script daemon (flock)
                                                                 |
                                                                 +-- (no uv / send fails) --> paplay fallback
```

---

## Section 3 — Config, defaults, fallback

### 3.1 New config keys

Stored in `~/.claude/.audio-feedback-config`, validated by `config.sh`.

| Key | Default | Purpose |
|---|---|---|
| `DAEMON_ENABLED` | `true` | `false` -> skip the daemon, always `paplay` per event |
| `DAEMON_IDLE_TIMEOUT` | `30` | Seconds of no events before the daemon self-exits |
| `DAEMON_MAX_VOICES` | `8` (to tune) | Max simultaneous mixed sounds; drop oldest beyond |

### 3.2 Fallback ladder

Each step degrades gracefully; the plugin is never silent:

1. `DAEMON_ENABLED=false` -> `paplay` per event.
2. `uv` missing -> `paplay` per event (probe cached).
3. `$XDG_RUNTIME_DIR` unset -> `paplay` per event (no socket home).
4. Socket connect fails after spawn + retry -> `paplay` that one event,
   continue.

### 3.3 Performance & resource profile

- **Startup cost:** the first event in an idle period pays daemon spawn.
  On a warm uv cache this is ~200-400ms (`uv run` resolve-from-cache +
  python start); on a **cold** uv cache the first ever spawn also downloads
  the wheels (seconds, one time). Spawn is backgrounded and does not block
  the hook. A `/audio-feedback setup` pre-warms the cache via
  `uv run --script af-soundd selftest`. Subsequent events hit the live
  daemon instantly; during a multi-agent burst the daemon is already warm.
- **Idle:** zero footprint — the daemon has exited.
- **Active:** one python process (~25-40MB RSS) + one PipeWire client,
  regardless of agent count. 10 agents -> 1 daemon, not 10 `paplay`.

---

## Section 4 — Testing

Real audio output is not CI-testable; test the logic around it.

| Test | Verifies |
|---|---|
| `test_config.sh` | new daemon keys validate/reject; removed `CLICKS_*` keys rejected; sound-value validation intact |
| `test_resolution.sh` | event->WAV path: `off` gate silences, subtype resolution, theme dir, new `sound-theme/<theme>/sounds/` layout |
| `test_daemon.sh` | spawn-if-absent; concurrent connects -> exactly one daemon (flock); send path -> daemon ACKs receipt; idle timeout -> self-exit; deps-absent -> fallback selected |
| `shellcheck` gate | all `.sh` clean |

- **Daemon tests avoid real audio:** run the daemon with a `--no-audio`
  flag that skips the stream but exercises socket + lifecycle + mixing math,
  and a `selftest` subcommand for the pure mixer logic. Both run via
  `uv run --script af-soundd …`; tests `[SKIP]` cleanly when `uv` is
  unavailable. This verifies process-collapse, idle-exit, and voice-cap
  logic without a sound card.
- **Migration check:** after the move, assert
  `sound-theme/default/sounds/stop.wav` resolves and no code references the
  old `sounds/<theme>/` path.

---

## Open items (resolved during implementation)

- `DAEMON_MAX_VOICES` default value — to tune.
- Exact daemon spawn/retry/backoff timing constants.
- Whether the `uv`-present probe result is cached in `$XDG_RUNTIME_DIR` or
  re-derived per hook invocation.

## Deferred to Spec B

- pyo-based generation pipeline and the `src/` generator scripts.
- The actual default-theme sound design (timbres, per-event character).
