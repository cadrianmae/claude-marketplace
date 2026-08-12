# audio-feedback 1.0.0 — Spec B: Sound Design & Generation

Date: 2026-08-12
Branch: `feat/audio-feedback-sound-redesign`
Status: Approved design, pre-implementation
Depends on: Spec A (`2026-08-11-audio-feedback-1.0.0-structure-design.md`) — theme layout, daemon, hook.

## Context

Spec A delivered the runtime + structure: the `sound-theme/<theme>/{sounds,src}`
layout, the mixing playback daemon, and the hook that resolves an event (with
subtype) to a WAV. It shipped **no sound content** — the default theme still
holds the old sox-era WAVs.

Spec B generates the actual default-theme sounds **programmatically** and wires
up subagent-aware variants. A prior (paused) redesign left a locked note-map, a
design brief (`DESIGN-NOTES.md`), and a verification tool (`analyze.py` +
`sound_targets.json`), plus a now-superseded REAPER pipeline
(`scaffold_rpp.py`, `render-sounds.py`, the `.rpp`, a Vital patch). The manual
REAPER step is what stalled the prior effort; Spec B replaces it with code.

## Decisions (locked with Mae)

- **Method:** programmatic synthesis (no DAW step).
- **Library:** `signalflow` 0.5.3 — verified to render offline to WAV under an
  uv-managed Python 3.12 (cp312 wheel). Run via `uv run --script` with PEP 723
  inline metadata, exactly like af-soundd: uv fetches Python 3.12 and the deps,
  no pyenv / manual venv / toolbox. (pyo was rejected: no 3.14 wheels, and its C
  fails to build against Fedora 44's GCC 15.)
- **Palette scope:** full 27 — 8 base events + 19 category variants.
- **Variant mechanism:** declarative accent-delta + optional added layer
  (resynthesized), inheriting a base event.
- **Subagent variants:** realized as a mixed **overlay layer** (`agent_id`-gated).
- **REAPER artifacts:** remove the dead pipeline; archive the `.rpp` + Vital
  patch as reference.
- **Version:** bump `plugin.json` 0.2.2 -> 1.0.0 in this spec.

## Live-verified hook facts (empirical, this session)

Captured real hook payloads via a temporary logging hook:

- `agent_id` is present on `PreToolUse`/`PostToolUse` **only when the tool runs
  on behalf of a subagent**; absent on the main agent. `agent_type` names the
  subagent kind (e.g. `general-purpose`, `Explore`).
- `SubagentStop` always carries `agent_id`, `agent_type`, `agent_transcript_path`.
- Subtype fields used by Spec A's resolver: `notification.notification_type`,
  `session_start.source`, `pre/post_tool_use.tool_name` (confirmed field names;
  `notification`/`session_start` payloads to be confirmed opportunistically —
  they are situational to trigger).

`agent_id` presence is the reliable subagent signal.

---

## Section 1 — Architecture & pipeline

### 1.1 Note-map as data

Lift the note-map out of the dead `scaffold_rpp.py` into
`sound-theme/default/src/note_map.json` — the single source of truth, consumed
by the generator and cross-checked against `analyze.py` targets. Shape per event:

```json
{
  "stop": {"mode": "seq",   "notes": [[72, "quaver"], [71, "quaver"], [67, "quaver"], [64, "quaver"], [60, "minim"]]},
  "pre-compact": {"mode": "chord", "notes": [[43, "minim"], [46, "minim"]]}
}
```

MIDI pitches and rhythm are exactly the locked note-map (session-start
48-52-55-58-60 rise; stop 72-71-67-64-60 fall; notification 60-67-70; etc.).

### 1.2 Generator

`sound-theme/default/src/generate.py` (signalflow + numpy/scipy):

- For each note in a phrase, synthesize one **struck inharmonic bell** in
  signalflow: a small set of `SineOscillator` partials at slightly-inharmonic
  ratios (e.g. 1.0, 2.01, 2.99, 4.07) with per-partial amplitude, each gated by
  an `ASREnvelope` (fast attack ~3 ms, zero sustain, exponential-ish release) —
  struck, not sustained.
- Render each bell offline
  (`AudioGraph(config=AudioGraphConfig(sample_rate=44100), output_device="dummy")`,
  `patch.play()`, `render_to_new_buffer(n)`), take the mono downmix of the
  stereo buffer.
- **Assemble the phrase** in numpy: place each bell at its onset sample per the
  rhythm; `chord` mode overlays notes at t=0; `seq` mode spaces them by note
  value. Sum.
- Post: light convolution reverb (short IR, ~8 ms pre-delay), gentle EQ per the
  premium tips (cut ~300-500 Hz mud, high-shelf air, tame 2.5-4 kHz), fade the
  last ~100 ms, normalize to ceiling **-1 dBFS**.
- Write mono 44100 Hz 16-bit WAV to `sound-theme/default/sounds/<name>.wav`.

The synthesis honours the premium tips: inharmonic partials, soft attack,
light pre-delay reverb, palette-consistent loudness.

### 1.3 Cleanup

- Delete: `scripts/scaffold_rpp.py`, `scripts/render-sounds.py`,
  `tests/test_scaffold.py`, `tests/test_render_lint.py`.
- Keep: `DESIGN-NOTES.md`, `scripts/analyze.py`, `scripts/sound_targets.json`,
  `tests/test_analyze.py`, `tests/test_targets.py`.
- Archive in place (reference, unused by signalflow):
  `sound-theme/default/src/audio-feedback.rpp`,
  `sound-theme/default/src/vital-fxchain.rpp-fragment`.

### 1.4 Dev environment (uv + PEP 723)

Generation is dev-time only (output WAVs are committed; not a runtime dep). No
pyenv, manual venv, or toolbox — `generate.py` carries PEP 723 inline metadata
and is run with `uv run --script`, which fetches Python 3.12 and the deps into
uv's cache:

```python
# /// script
# requires-python = ">=3.12,<3.13"       # signalflow has no 3.13/3.14 wheel yet
# dependencies = ["signalflow", "numpy", "scipy"]
# ///
```

```bash
# from repo root; only-managed avoids pyenv shims shadowing python3.12
UV_PYTHON_PREFERENCE=only-managed \
  uv run --script plugins/audio-feedback/sound-theme/default/src/generate.py
python plugins/audio-feedback/scripts/analyze.py --palette \
  plugins/audio-feedback/sound-theme/default/sounds
```

(`analyze.py` is numpy/scipy-only and can run under any interpreter with those,
including `uv run --with numpy --with scipy`.) No `requirements-gen.txt` — the
PEP 723 block is the single dependency source.

---

## Section 2 — Sound model & variant extension

### 2.1 Base semantics (from DESIGN-NOTES, unchanged)

Two orthogonal axes: **mode** (Mixolydian flat-7 = "more coming" for starts;
Ionian leading-tone = closure for finishes) and **contour** (rise = start, fall
= finish). Key C, warm register, consonant intervals. Frequent events short;
rare events (stop, session-start) get the full bar.

### 2.2 Variant extension (accent-delta + layer)

`sound-theme/default/src/variants.json` — each variant inherits a base event and
declares an accent from a small vocabulary:

```json
{
  "pre-tool-use-network":  {"base": "pre-tool-use",  "brightness": 1.3, "air_db": -12},
  "pre-tool-use-execute":  {"base": "pre-tool-use",  "transpose": -2,  "punch": 1.2},
  "pre-tool-use-modify":   {"base": "pre-tool-use",  "layer": "shimmer"},
  "notification-permission": {"base": "notification", "transpose": 0, "brightness": 1.15}
}
```

Accent vocabulary:
- `transpose` — semitone shift of the phrase (keeps mode/contour).
- `brightness` — tilt partial amplitudes toward the highs.
- `detune_cents` — micro-detune between layers for richness.
- `decay_scale` — scale the release time.
- `air_db` / `sub_db` — level of an added high-air / sub-octave layer.
- `layer` — named added signalflow layer (`shimmer`, `sub`, `transient`).

The generator resolves `base note-map + variant accent` -> a fresh signalflow
patch -> `<event>-<variant>.wav`. Variants stay within their base's
mode/contour identity; the accent only differentiates the tool group by ear.

The 19 variants: `pre-tool-use-{execute,observe,modify,network,dispatch,interact}`,
`post-tool-use-{…same six…}`, `notification-{permission,idle,auth,elicitation}`,
`session-start-{resume,compact,clear}`.

### 2.3 Subagent accent (overlay)

A single extra file `sound-theme/default/sounds/subagent-accent.wav` — a quiet
shimmer/sub layer generated by the same mechanism (a bare accent layer, no base
phrase). It is **not** a per-event variant; it is mixed on top at runtime, so it
composes with any resolved sound (incl. tool-group variants) without a
combinatorial file explosion.

---

## Section 3 — Runtime wiring (Spec A hook extension)

`hooks/play-sound.sh` gains subagent awareness:

- Extract `agent_id` from the hook JSON (via `jq`, like existing subtypes).
- After resolving and dispatching the event's sound as today, **if** `agent_id`
  is non-empty **and** `SUBAGENT_ACCENT=true`, also dispatch
  `subagent-accent.wav`. The daemon mixes the two; under the `paplay` fallback
  only the base sound plays (accent silently dropped — acceptable degradation).
- The accent only sounds when the underlying tool event is itself enabled (an
  `off` event stays silent regardless).

New config key (validated in `config.sh`, defaulted/loaded in `lib.sh`):

| Key | Default | Purpose |
|---|---|---|
| `SUBAGENT_ACCENT` | `true` | Mix `subagent-accent.wav` over tool sounds fired on behalf of a subagent (`agent_id` present) |

No new daemon capability is needed — Spec A's mixer already overlays multiple
paths.

---

## Section 4 — Verification

`analyze.py` is the acceptance gate (repointed to `sound-theme/default/sounds`):

- **Per base sound:** `analyze.py <wav> <event>` — dominant pitch matches the
  note-map tonic, envelope is struck (attack/decay windows), peak within target.
  `sound_targets.json` holds the 8 base targets.
- **Transposed variants** get their own target entry (their dominant pitch
  shifts); non-transposed variants inherit their base target. Untransposed
  variants are checked by the palette gate only.
- **Palette:** `analyze.py --palette sound-theme/default/sounds` — RMS spread
  <= 3 dB and peak <= -0.7 dBFS across all files (28: 8 base + 19 variants +
  `subagent-accent`). This guards the "no sound startlingly louder than another"
  premium rule.

The generator must produce a palette that passes both gates; that is the
definition of done for the sounds.

Existing pytest (`test_analyze.py`, `test_targets.py`) keep `analyze.py` and the
targets honest; add a lightweight `test_generate.py` that runs the generator via
`uv run --script` and asserts it emits all 28 files that pass the palette gate
(guarded to skip when `uv` is unavailable, like the daemon tests).

---

## Section 5 — Version & docs

- Bump `plugin.json` **0.2.2 -> 1.0.0**.
- Promote CHANGELOG `[Unreleased]` (Spec A entries) to `[1.0.0]`, adding the
  sound-system entry (programmatic signalflow generation, 27-sound palette,
  subagent accent, REAPER pipeline removed).
- README/SKILL: document the sound-design system, the regenerate workflow, and
  `SUBAGENT_ACCENT`.

---

## Open items (resolved during implementation)

- Exact inharmonic partial ratios + per-event decay times (tuned against
  `analyze.py` targets and by ear).
- The specific accent values per variant (the 19 deltas) — tuned by ear so tool
  groups are distinguishable without leaving the base identity.
- The `subagent-accent.wav` timbre + level (subtle; must not overpower).
- Whether any `notification`/`session_start` subtype field names differ from the
  Spec A assumptions (confirm from the opportunistic capture before relying on
  them; base sounds work regardless via fallback).

## Non-goals

- Additional themes beyond `default` (the layout supports them; not in scope).
- Real-time/runtime synthesis (sounds are pre-rendered and committed).
- Per-`agent_type` distinct sounds (only a single subagent accent for now;
  `agent_type` branching is a later possibility).
