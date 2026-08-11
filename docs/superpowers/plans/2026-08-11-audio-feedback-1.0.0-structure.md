# audio-feedback 1.0.0 (Spec A: Runtime & Structure) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the clicks subsystem, adopt a freedesktop-inspired theme layout, and add a resident sounddevice daemon that collapses N concurrent `paplay` processes into one process + one PipeWire client.

**Architecture:** Bash owns config + event→WAV-path resolution (unchanged logic). A single python file `af-soundd` owns audio output. The per-event **client** path (`af-soundd play`) imports stdlib only and runs under bare `python3`: it connects to a Unix socket and sends the WAV path; if no daemon answers it spawns one (double-fork + flock) via `uv run --script af-soundd daemon`. The **daemon** holds one persistent sounddevice stream and mixes received WAVs with numpy, self-exiting after an idle timeout. Its python deps are declared as PEP 723 inline metadata and supplied by uv's cache — no venv. Missing `uv` or a disabled daemon fall back to `paplay` per event.

**Tech Stack:** bash, python3 (stdlib client), uv + PEP 723 (daemon env: sounddevice/soundfile/numpy), jq (subtype resolution only).

## Global Constraints

- Target: Linux + PipeWire (`paplay` from pipewire-pulse). No Pulse-only/ALSA fallback.
- Hook scripts use `set +e` (never fail a hook) and always `exit 0`. Config/entry scripts use `set -e`.
- Path resolution uses `readlink -f` on `$0` / `${BASH_SOURCE[0]}` (no reliance on `CLAUDE_PLUGIN_ROOT` inside sourced libs).
- Theme sounds are mono, 44100 Hz, 16-bit WAV. The daemon stream runs at 44100 Hz mono to match.
- All `.sh` must pass `shellcheck` clean.
- Comments/docs: ASCII only ([OK]/[WARN]/[INFO]); do not add new non-keyboard glyphs (preserve the existing check mark already in `config.sh` output).
- Config file: `~/.claude/.audio-feedback-config`, `KEY=VALUE` lines.
- Socket: `$XDG_RUNTIME_DIR/audio-feedback.sock`; spawn lockfile: `$XDG_RUNTIME_DIR/audio-feedback.spawn.lock`.
- **Dependency model:** the daemon's python deps are PEP 723 inline metadata in `af-soundd`, run via `uv run --script`. uv caches the env (`~/.cache/uv`); there is NO managed venv and NO bootstrap script. The client path is stdlib-only under bare `python3`. numpy/sounddevice/soundfile are imported lazily inside daemon-only functions so the client never imports them.
- **No plugin.json version bump in this plan** — CHANGELOG entries go under `[Unreleased]`; the 1.0.0 bump happens after Spec B (sound design).

---

## File Structure

- `plugins/audio-feedback/scripts/lib.sh` — config load/defaults, path resolution, event→sound resolution, playback dispatch (`af_play_event*` route through the daemon client or the `paplay` fallback).
- `plugins/audio-feedback/scripts/config.sh` — config viewer/validator; gains daemon keys.
- `plugins/audio-feedback/hooks/play-sound.sh` — hook client; resolves path, dispatches to `af_play_event_with_subtype`.
- `plugins/audio-feedback/bin/af-soundd` — python file with PEP 723 header and `daemon`, `play`, `raw-send`, `selftest` subcommands.
- `plugins/audio-feedback/sound-theme/default/theme.json` — theme metadata.
- `plugins/audio-feedback/sound-theme/default/sounds/*.wav` — migrated rendered sounds.
- `plugins/audio-feedback/sound-theme/default/src/.gitkeep` — empty; populated in Spec B.
- `plugins/audio-feedback/tests/test_resolution.sh` — event→path resolution tests.
- `plugins/audio-feedback/tests/test_config.sh` — config validation tests.
- `plugins/audio-feedback/tests/test_daemon.sh` — daemon lifecycle + concurrency + fallback tests.
- `plugins/audio-feedback/README.md`, `plugins/audio-feedback/skills/audio-feedback/SKILL.md`, `plugins/audio-feedback/CHANGELOG.md` — docs.

---

## Task 1: Finalize and commit clicks removal

The clicks subsystem was already stripped in the working tree this session (`lib.sh`, `config.sh`, `play-sound.sh`, docs; deleted `tests/test_clicks.sh` and `.superpowers/tools/click-designer/`; `sox` dropped). This task verifies and commits that as a clean unit.

**Files:**
- Modify (already edited): `plugins/audio-feedback/scripts/lib.sh`, `plugins/audio-feedback/scripts/config.sh`, `plugins/audio-feedback/hooks/play-sound.sh`, `plugins/audio-feedback/README.md`, `plugins/audio-feedback/skills/audio-feedback/SKILL.md`
- Delete (already removed): `plugins/audio-feedback/tests/test_clicks.sh`, `.superpowers/tools/click-designer/`

**Interfaces:**
- Produces: click-free `lib.sh` whose public playback function is `af_play_event_with_subtype <event> <subtype>`, resolver `af_sound_for_event <event>`, and single-event player `af_play_event <event>`; `_af_sounds_base` / `_af_sounds_dir` still point at `sounds/<theme>` (layout migration is Task 2).

- [ ] **Step 1: Verify no click references remain in code**

Run:
```bash
cd plugins/audio-feedback
grep -rniE 'af_render_clicks|af_play_clicks|af_tokens_from_transcript|AF_CLICK|CLICKS_' scripts hooks && echo "FOUND (fix before commit)" || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 2: Shellcheck the three scripts**

Run: `cd plugins/audio-feedback && shellcheck scripts/config.sh scripts/lib.sh hooks/play-sound.sh && echo OK`
Expected: `OK`.

- [ ] **Step 3: Smoke-test config + rejection of removed key**

Run:
```bash
cd plugins/audio-feedback
rm -rf /tmp/aftest && mkdir -p /tmp/aftest/.claude
HOME=/tmp/aftest ./bin/audio-feedback-config >/dev/null && echo "display OK"
HOME=/tmp/aftest ./bin/audio-feedback-config CLICKS_EVENTS=stop 2>&1; echo "exit=$?"
```
Expected: `display OK`, then "unknown key 'CLICKS_EVENTS'" with `exit=1`.

- [ ] **Step 4: Commit**

```bash
cd /home/cadrianmae/git/github.com/cadrianmae/claude-marketplace
git add plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh \
        plugins/audio-feedback/hooks/play-sound.sh plugins/audio-feedback/README.md \
        plugins/audio-feedback/skills/audio-feedback/SKILL.md
git rm -q --ignore-unmatch plugins/audio-feedback/tests/test_clicks.sh
git commit -m "feat(audio-feedback)!: remove clicks subsystem and sox dependency

Clicks never served their purpose. Removes CLICKS_* config, token-scaled
click synthesis, the click-play block in the hook, all click docs,
tests/test_clicks.sh, and the click-designer tool. sox is no longer a
runtime dependency; jq is retained for subtype resolution. Stale CLICKS_*
lines in existing configs are ignored as harmless orphans.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Freedesktop-inspired theme layout migration

Move to `sound-theme/<theme>/{sounds,src}` + `theme.json`, and repoint path resolution. Keep Claude event names.

**Files:**
- Create: `plugins/audio-feedback/sound-theme/default/theme.json`, `.../src/.gitkeep`
- Move: `plugins/audio-feedback/sounds/default/*.wav` → `plugins/audio-feedback/sound-theme/default/sounds/`
- Delete: `plugins/audio-feedback/sounds/` (old tree, incl. click-era `sounds/src/`)
- Modify: `plugins/audio-feedback/scripts/lib.sh`, `plugins/audio-feedback/scripts/config.sh`
- Test: `plugins/audio-feedback/tests/test_resolution.sh`

**Interfaces:**
- Consumes: `af_sound_for_event`, `af_play_event_with_subtype` (Task 1).
- Produces: `_af_sounds_base()` prints `<plugin>/sound-theme`; `_af_sounds_dir()` prints `<plugin>/sound-theme/<AF_THEME>/sounds`; `af_list_themes()` prints one theme name per line (dirs under `sound-theme/` containing `theme.json`).

- [ ] **Step 1: Write the failing resolution test**

Create `plugins/audio-feedback/tests/test_resolution.sh`:
```bash
#!/bin/bash
# Resolution tests: path layout, theme listing.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
# shellcheck source=../scripts/lib.sh disable=SC1091
source "$PLUGIN/scripts/lib.sh"

fail=0
check() { if [ "$1" = "$2" ]; then echo "[OK] $3"; else echo "[FAIL] $3: got '$1' want '$2'"; fail=1; fi; }

base="$(_af_sounds_base)"
check "$(basename "$base")" "sound-theme" "base is sound-theme/"
AF_THEME="default"
dir="$(_af_sounds_dir)"
check "$dir" "$base/default/sounds" "dir is <base>/default/sounds"
[ -f "$dir/stop.wav" ] && check yes yes "stop.wav present in new layout" || check no yes "stop.wav present in new layout"
themes="$(af_list_themes)"
case "$themes" in *default*) check yes yes "af_list_themes finds default";; *) check no yes "af_list_themes finds default";; esac

exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_resolution.sh; echo "exit=$?"`
Expected: FAIL (base/dir still `sounds/`, `af_list_themes` undefined), `exit=1`.

- [ ] **Step 3: Migrate the files**

`sounds/src/` holds TRACKED sound-design source (`audio-feedback.rpp`,
`vital-fxchain.rpp-fragment`, `DESIGN-NOTES.md`) — the redesign/Spec B
source. It must be **migrated** into the new theme `src/`, NOT deleted.
Only the untracked click-era `click_pyo.py` is dropped.
```bash
cd plugins/audio-feedback
mkdir -p sound-theme/default/sounds sound-theme/default/src
git mv sounds/default/*.wav sound-theme/default/sounds/
# migrate the tracked sound-design source into the theme's src/
git mv sounds/src/DESIGN-NOTES.md sounds/src/audio-feedback.rpp \
       sounds/src/vital-fxchain.rpp-fragment sound-theme/default/src/
rm -f sounds/src/click_pyo.py            # untracked click-era scratch
touch sound-theme/default/src/.gitkeep
rmdir sounds/src sounds/default sounds 2>/dev/null || true
```

- [ ] **Step 4: Create `theme.json`**

Create `plugins/audio-feedback/sound-theme/default/theme.json`:
```json
{
  "name": "Default",
  "comment": "Lo-fi minimal event cues, mono 44.1kHz with reverb"
}
```

- [ ] **Step 5: Repoint path resolution in `lib.sh`**

Replace the two path helpers:
```bash
# Resolve the plugin's sound-theme base directory (contains theme subdirs).
_af_sounds_base() {
    printf '%s' "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../sound-theme"
}

# Resolve the active theme's rendered-sounds directory.
# Must call af_load_config first so AF_THEME is set.
_af_sounds_dir() {
    printf '%s' "$(_af_sounds_base)/${AF_THEME:-default}/sounds"
}
```
Add near `af_list_sounds`:
```bash
# List available theme names (one per line): subdirs of sound-theme/
# that contain a theme.json.
af_list_themes() {
    local base f
    base="$(_af_sounds_base)"
    [ -d "$base" ] || return 0
    for f in "$base"/*/theme.json; do
        [ -e "$f" ] || continue
        basename "$(dirname "$f")"
    done | sort
}
```

- [ ] **Step 6: Use `af_list_themes` in `config.sh`**

Replace the two `find ... -type d` theme-listing expressions (no-arg display block and `THEME)` validation arm). Display:
```bash
    echo "Available themes: $(af_list_themes | tr '\n' ' ')"
```
`THEME)` arm:
```bash
        THEME)
            if [ ! -f "$(_af_sounds_base)/$value/theme.json" ]; then
                echo "Error: theme '$value' not found. Available: $(af_list_themes | tr '\n' ' ')" >&2
                exit 1
            fi
            ;;
```

- [ ] **Step 7: Run the resolution test — expect PASS**

Run: `bash plugins/audio-feedback/tests/test_resolution.sh; echo "exit=$?"`
Expected: all `[OK]`, `exit=0`.

- [ ] **Step 8: Shellcheck + commit**

Run: `shellcheck plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh plugins/audio-feedback/tests/test_resolution.sh && echo OK`
```bash
git add -A plugins/audio-feedback/sound-theme plugins/audio-feedback/scripts/lib.sh \
          plugins/audio-feedback/scripts/config.sh plugins/audio-feedback/tests/test_resolution.sh
git add -A plugins/audio-feedback/sounds 2>/dev/null || true
git commit -m "feat(audio-feedback): freedesktop-inspired theme layout

Move sounds/<theme>/*.wav to sound-theme/<theme>/sounds/, add per-theme
theme.json and an empty src/ (Spec B populates it). Repoint
_af_sounds_base/_af_sounds_dir, add af_list_themes; config.sh lists and
validates themes via theme.json.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Daemon config keys

Add `DAEMON_ENABLED`, `DAEMON_IDLE_TIMEOUT`, `DAEMON_MAX_VOICES`.

**Files:**
- Modify: `plugins/audio-feedback/scripts/lib.sh`, `plugins/audio-feedback/scripts/config.sh`
- Test: `plugins/audio-feedback/tests/test_config.sh`

**Interfaces:**
- Produces: after `af_load_config`, shell vars `AF_DAEMON_ENABLED` (true|false), `AF_DAEMON_IDLE_TIMEOUT` (int seconds), `AF_DAEMON_MAX_VOICES` (int). Defaults `true`, `30`, `8`.

- [ ] **Step 1: Write the failing config test**

Create `plugins/audio-feedback/tests/test_config.sh`:
```bash
#!/bin/bash
# Config validation tests for daemon keys and removed clicks keys.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
CFG=/tmp/aftest-cfg
run() { rm -rf "$CFG" && mkdir -p "$CFG/.claude"; HOME="$CFG" "$PLUGIN/bin/audio-feedback-config" "$@"; }

fail=0
expect_ok()  { if run "$@" >/dev/null 2>&1; then echo "[OK] accept $*"; else echo "[FAIL] accept $*"; fail=1; fi; }
expect_err() { if run "$@" >/dev/null 2>&1; then echo "[FAIL] reject $*"; fail=1; else echo "[OK] reject $*"; fi; }

expect_ok  DAEMON_ENABLED=false
expect_ok  DAEMON_IDLE_TIMEOUT=15
expect_ok  DAEMON_MAX_VOICES=4
expect_err DAEMON_ENABLED=maybe
expect_err DAEMON_IDLE_TIMEOUT=0
expect_err DAEMON_MAX_VOICES=0
expect_err CLICKS_ENABLED=true

run DAEMON_IDLE_TIMEOUT=42 >/dev/null 2>&1
if grep -q '^DAEMON_IDLE_TIMEOUT=42$' "$CFG/.claude/.audio-feedback-config"; then
  echo "[OK] persists DAEMON_IDLE_TIMEOUT"; else echo "[FAIL] persists DAEMON_IDLE_TIMEOUT"; fail=1; fi

exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_config.sh; echo "exit=$?"`
Expected: FAILs on `DAEMON_*` accepts + persistence, `exit=1`.

- [ ] **Step 3: Add defaults + loader + ensure-config in `lib.sh`**

Defaults after `af_default_enabled`:
```bash
af_default_daemon_enabled="true"
af_default_daemon_idle_timeout="30"
af_default_daemon_max_voices="8"
```
In `af_load_config`, after `AF_ENABLED=...` init:
```bash
    AF_DAEMON_ENABLED="$af_default_daemon_enabled"
    AF_DAEMON_IDLE_TIMEOUT="$af_default_daemon_idle_timeout"
    AF_DAEMON_MAX_VOICES="$af_default_daemon_max_voices"
```
In the load `case "$key"`, after `ENABLED)`:
```bash
            DAEMON_ENABLED) AF_DAEMON_ENABLED="$value" ;;
            DAEMON_IDLE_TIMEOUT) AF_DAEMON_IDLE_TIMEOUT="$value" ;;
            DAEMON_MAX_VOICES) AF_DAEMON_MAX_VOICES="$value" ;;
```
In `af_ensure_config`'s heredoc, after `ENABLED=...`:
```bash
DAEMON_ENABLED=$af_default_daemon_enabled
DAEMON_IDLE_TIMEOUT=$af_default_daemon_idle_timeout
DAEMON_MAX_VOICES=$af_default_daemon_max_voices
```

- [ ] **Step 4: Add validation + display in `config.sh`**

Extend `VALID_KEYS`:
```bash
VALID_KEYS="THEME ENABLED DAEMON_ENABLED DAEMON_IDLE_TIMEOUT DAEMON_MAX_VOICES STOP_SOUND NOTIFICATION_SOUND PRE_COMPACT_SOUND USER_PROMPT_SOUND SESSION_START_SOUND SUBAGENT_STOP_SOUND PRE_TOOL_USE_SOUND POST_TOOL_USE_SOUND"
```
Display block, after `ENABLED`:
```bash
    echo "  DAEMON_ENABLED=$AF_DAEMON_ENABLED"
    echo "  DAEMON_IDLE_TIMEOUT=$AF_DAEMON_IDLE_TIMEOUT"
    echo "  DAEMON_MAX_VOICES=$AF_DAEMON_MAX_VOICES"
```
Validation `case "$key"`:
```bash
        ENABLED|DAEMON_ENABLED)
            case "$value" in
                true|false) ;;
                *) echo "Error: $key must be true|false (got '$value')" >&2; exit 1 ;;
            esac
            ;;
        DAEMON_IDLE_TIMEOUT|DAEMON_MAX_VOICES)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
                echo "Error: $key must be a positive integer (got '$value')" >&2
                exit 1
            fi
            ;;
```

- [ ] **Step 5: Run the config test — expect PASS**

Run: `bash plugins/audio-feedback/tests/test_config.sh; echo "exit=$?"`
Expected: all `[OK]`, `exit=0`.

- [ ] **Step 6: Shellcheck + commit**

Run: `shellcheck plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh plugins/audio-feedback/tests/test_config.sh && echo OK`
```bash
git add plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh plugins/audio-feedback/tests/test_config.sh
git commit -m "feat(audio-feedback): add DAEMON_* config keys

DAEMON_ENABLED (true|false), DAEMON_IDLE_TIMEOUT (int seconds, default 30),
DAEMON_MAX_VOICES (int, default 8). Loaded, defaulted, validated, displayed.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `af-soundd` daemon core (PEP 723 + socket + mixer + idle-exit)

The python file: PEP 723 header declaring the daemon deps; `daemon` subcommand (persistent stream, mixing, idle-exit), plus `raw-send` (stdlib socket write, for testing) and `selftest` (mixer math). `--no-audio` skips the real stream. Client `play` is Task 5.

**Files:**
- Create: `plugins/audio-feedback/bin/af-soundd`
- Test: `plugins/audio-feedback/tests/test_daemon.sh` (created here; extended in Task 5)

**Interfaces:**
- Produces (CLI):
  - `af-soundd daemon --socket PATH [--idle-timeout N] [--max-voices V] [--no-audio]` — foreground daemon. Prints `READY` (stderr) on start, `PLAY <path>` per received path, `IDLE-EXIT` then exit 0 on idle.
  - `af-soundd raw-send --socket PATH` — write stdin to the socket (no spawn). stdlib only.
  - `af-soundd selftest` — mixer assertions; exit 0/1. (Run via `uv run --script`.)
- Produces (python): `Mixer(max_voices)` with `.add(samples)`, `.render(frames)->np.float32[frames]`, `.active()->bool`.

- [ ] **Step 1: Write the failing daemon lifecycle + selftest test**

Create `plugins/audio-feedback/tests/test_daemon.sh`:
```bash
#!/bin/bash
# Daemon lifecycle tests (no real audio). Daemon/selftest run via uv.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
SOUNDD="$PLUGIN/bin/af-soundd"
fail=0
ok()  { echo "[OK] $1"; }
bad() { echo "[FAIL] $1"; fail=1; }

if ! command -v uv >/dev/null 2>&1; then
  echo "[SKIP] uv not installed; skipping daemon tests"; exit 0
fi

# selftest (mixer math), env supplied by uv from PEP 723 metadata
if uv run --script "$SOUNDD" selftest; then ok "selftest passes"; else bad "selftest passes"; fi

# lifecycle: start daemon (no-audio), send a path via stdlib client, expect PLAY + IDLE-EXIT
SOCK="/tmp/aftest-daemon.sock"; rm -f "$SOCK"
log="/tmp/aftest-daemon.log"; : > "$log"
uv run --script "$SOUNDD" daemon --socket "$SOCK" --idle-timeout 2 --no-audio >"$log" 2>&1 &
dpid=$!
for _ in $(seq 1 100); do grep -q READY "$log" 2>/dev/null && break; sleep 0.1; done
grep -q READY "$log" && ok "daemon READY" || bad "daemon READY"

printf '%s\n' "/tmp/does-not-matter.wav" | python3 "$SOUNDD" raw-send --socket "$SOCK"
for _ in $(seq 1 30); do grep -q 'PLAY ' "$log" 2>/dev/null && break; sleep 0.1; done
grep -q 'PLAY /tmp/does-not-matter.wav' "$log" && ok "daemon received PLAY" || bad "daemon received PLAY"

for _ in $(seq 1 80); do kill -0 "$dpid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$dpid" 2>/dev/null; then bad "daemon idle-exited"; kill "$dpid" 2>/dev/null; else ok "daemon idle-exited"; fi
grep -q IDLE-EXIT "$log" && ok "logged IDLE-EXIT" || bad "logged IDLE-EXIT"

exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_daemon.sh; echo "exit=$?"`
Expected: `[SKIP]` if uv missing (install uv first), else FAIL because `af-soundd` does not exist, `exit=1`.

- [ ] **Step 3: Implement `af-soundd` (PEP 723 header + daemon + raw-send + selftest)**

Create `plugins/audio-feedback/bin/af-soundd`:
```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["sounddevice", "soundfile", "numpy"]
# ///
"""af-soundd: resident audio-feedback playback daemon + client.

Subcommands:
  daemon    run the mixing daemon (foreground) on a Unix socket
  play      ensure a daemon exists (auto-spawn via uv) then send a path [Task 5]
  raw-send  write stdin lines to an existing socket (no spawn) [testing]
  selftest  run internal mixer assertions

Client subcommands (play, raw-send) import stdlib only and run fine under a
bare python3. Only the daemon needs numpy/sounddevice/soundfile, imported
lazily below and supplied by uv from the PEP 723 block when launched with
`uv run --script`.
"""
import argparse
import os
import socket
import sys
import threading
import time

SAMPLE_RATE = 44100
CHANNELS = 1
BLOCK = 1024


class Mixer:
    """Sum active voices into fixed-size float32 blocks."""

    def __init__(self, max_voices):
        self.max_voices = max_voices
        self._voices = []  # list of [samples(np.float32), pos(int)]
        self._lock = threading.Lock()

    def add(self, samples):
        with self._lock:
            if len(self._voices) >= self.max_voices:
                self._voices.pop(0)  # drop oldest
            self._voices.append([samples, 0])

    def active(self):
        with self._lock:
            return len(self._voices) > 0

    def render(self, frames):
        import numpy as np
        out = np.zeros(frames, dtype="float32")
        with self._lock:
            keep = []
            for v in self._voices:
                s, pos = v
                chunk = s[pos:pos + frames]
                out[:len(chunk)] += chunk
                v[1] = pos + len(chunk)
                if v[1] < len(s):
                    keep.append(v)
            self._voices = keep
        np.clip(out, -1.0, 1.0, out=out)
        return out


def _load_wav(path, cache):
    """Load a mono float32 array at SAMPLE_RATE, or None on failure."""
    import numpy as np
    import soundfile as sf
    if path in cache:
        return cache[path]
    try:
        data, sr = sf.read(path, dtype="float32", always_2d=False)
    except Exception:
        cache[path] = None
        return None
    if data.ndim > 1:
        data = data.mean(axis=1).astype("float32")
    if sr != SAMPLE_RATE:
        n = int(round(len(data) * SAMPLE_RATE / sr))
        if n > 0:
            xp = np.linspace(0.0, 1.0, num=len(data), endpoint=False)
            x = np.linspace(0.0, 1.0, num=n, endpoint=False)
            data = np.interp(x, xp, data).astype("float32")
    cache[path] = data
    return data


def run_daemon(args):
    mixer = Mixer(args.max_voices)
    cache = {}
    last = [time.monotonic()]

    if os.path.exists(args.socket):
        os.unlink(args.socket)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(args.socket)
    srv.listen(16)
    srv.settimeout(0.25)

    stream = None
    if not args.no_audio:
        import sounddevice as sd

        def callback(outdata, frames, time_info, status):
            outdata[:, 0] = mixer.render(frames)

        stream = sd.OutputStream(
            samplerate=SAMPLE_RATE, channels=CHANNELS,
            blocksize=BLOCK, dtype="float32", callback=callback,
        )
        stream.start()

    print("READY", file=sys.stderr, flush=True)
    try:
        while True:
            if (time.monotonic() - last[0] > args.idle_timeout) and not mixer.active():
                break
            try:
                conn, _ = srv.accept()
            except socket.timeout:
                continue
            with conn:
                data = conn.recv(8192).decode("utf-8", "replace")
            for line in data.splitlines():
                path = line.strip()
                if not path:
                    continue
                print("PLAY " + path, file=sys.stderr, flush=True)
                last[0] = time.monotonic()
                if args.no_audio:
                    continue
                samples = _load_wav(path, cache)
                if samples is not None:
                    mixer.add(samples)
    finally:
        if stream is not None:
            stream.stop(); stream.close()
        srv.close()
        try:
            os.unlink(args.socket)
        except OSError:
            pass
        print("IDLE-EXIT", file=sys.stderr, flush=True)


def run_raw_send(args):
    data = sys.stdin.read()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(args.socket)
    s.sendall(data.encode("utf-8"))
    s.close()


def run_selftest(_args):
    import numpy as np
    m = Mixer(max_voices=2)
    m.add(np.ones(3, dtype="float32") * 0.5)
    assert np.allclose(m.render(2), [0.5, 0.5])
    assert m.active()
    assert np.allclose(m.render(2)[0], 0.5)
    assert not m.active()
    m.add(np.ones(1, dtype="float32") * 0.8)
    m.add(np.ones(1, dtype="float32") * 0.8)
    assert np.allclose(m.render(1), [1.0])  # 1.6 clipped
    m2 = Mixer(max_voices=1)
    m2.add(np.zeros(1, dtype="float32"))
    m2.add(np.ones(1, dtype="float32"))
    assert np.allclose(m2.render(1), [1.0])  # oldest dropped
    print("selftest OK")


def main():
    ap = argparse.ArgumentParser(prog="af-soundd")
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("daemon")
    d.add_argument("--socket", required=True)
    d.add_argument("--idle-timeout", type=float, default=30.0)
    d.add_argument("--max-voices", type=int, default=8)
    d.add_argument("--no-audio", action="store_true")
    d.set_defaults(func=run_daemon)

    r = sub.add_parser("raw-send")
    r.add_argument("--socket", required=True)
    r.set_defaults(func=run_raw_send)

    t = sub.add_parser("selftest")
    t.set_defaults(func=run_selftest)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Make executable + run selftest via uv**

Run:
```bash
chmod +x plugins/audio-feedback/bin/af-soundd
uv run --script plugins/audio-feedback/bin/af-soundd selftest
```
Expected: `selftest OK`, exit 0. (First run may download wheels; subsequent runs are cached.)

- [ ] **Step 5: Run the daemon test — expect PASS (or SKIP)**

Run: `bash plugins/audio-feedback/tests/test_daemon.sh; echo "exit=$?"`
Expected: all `[OK]`, `exit=0`, or `[SKIP]` without uv.

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/bin/af-soundd plugins/audio-feedback/tests/test_daemon.sh
git commit -m "feat(audio-feedback): af-soundd daemon core (PEP 723 + socket + mixer)

Single persistent output stream mixes received WAV paths with numpy; voice
cap drops oldest; self-exits after idle-timeout with no active voices.
Daemon deps declared as PEP 723 inline metadata (run via uv run --script);
--no-audio and selftest make it testable without a sound card. raw-send is
a stdlib-only test client.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `af-soundd play` client (stdlib, auto-spawn via uv)

Add `play`: stdlib-only client. Connect to the socket; if refused, spawn a detached daemon under a flock via `uv run --script af-soundd daemon`, wait for readiness, then send the path.

**Files:**
- Modify: `plugins/audio-feedback/bin/af-soundd`
- Test: `plugins/audio-feedback/tests/test_daemon.sh` (append concurrency test)

**Interfaces:**
- Consumes: `run_daemon` + socket protocol (Task 4).
- Produces (CLI): `af-soundd play --socket PATH --path WAV [--idle-timeout N] [--max-voices V] [--no-audio]` — idempotently ensures one daemon and sends `WAV`. Exit 0 on success; non-zero if undeliverable (caller falls back to paplay). Uses `shutil.which("uv")`; if uv absent, exits non-zero without spawning.

- [ ] **Step 1: Append the failing concurrency test**

Append to `plugins/audio-feedback/tests/test_daemon.sh` before the final `exit "$fail"`:
```bash
# Concurrency: many parallel 'play' calls spawn exactly ONE daemon.
SOCK2="/tmp/aftest-daemon2.sock"; rm -f "$SOCK2" "$SOCK2.spawn.lock"
WAV="/tmp/aftest-silence.wav"
uv run --script "$SOUNDD" selftest >/dev/null 2>&1  # warm cache
python3 - "$WAV" <<'PY'
import sys, wave, struct
w = wave.open(sys.argv[1], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
w.writeframes(struct.pack("<" + "h"*2205, *([0]*2205))); w.close()
PY
for _ in $(seq 1 10); do
  python3 "$SOUNDD" play --socket "$SOCK2" --path "$WAV" --idle-timeout 2 --no-audio &
done
wait
n="$(pgrep -fc -- "af-soundd daemon --socket $SOCK2" || true)"
if [ "${n:-0}" -le 1 ]; then ok "single daemon under concurrency (n=${n:-0})"; else bad "single daemon under concurrency (n=$n)"; fi
sleep 3
if pgrep -f -- "af-soundd daemon --socket $SOCK2" >/dev/null; then bad "concurrent daemon idle-exited"; else ok "concurrent daemon idle-exited"; fi
```
Note: the silence WAV is written with stdlib `wave` (no numpy needed in the test driver).

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_daemon.sh; echo "exit=$?"`
Expected: FAIL — `play` does not exist (or `[SKIP]`).

- [ ] **Step 3: Implement `play` (stdlib client, auto-spawn via uv under flock)**

In `plugins/audio-feedback/bin/af-soundd`, add before `main()`:
```python
def _try_send(sock_path, payload):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        s.sendall(payload.encode("utf-8"))
        s.close()
        return True
    except (FileNotFoundError, ConnectionRefusedError, OSError):
        return False


def _spawn_daemon(args):
    """Ensure exactly one daemon. Fork+exec it via `uv run --script`, then
    HOLD the flock until the new daemon is actually listening on the socket.
    Concurrent callers block on the lock; when it releases the daemon is up,
    so their re-check succeeds and they never spawn a duplicate. (Releasing
    the lock right after fork() — before the daemon binds — is the race that
    lets N callers each spawn a daemon.) Returns False only if uv is
    missing."""
    import fcntl
    import shutil
    uv = shutil.which("uv")
    if uv is None:
        return False
    lock_path = args.socket + ".spawn.lock"
    lf = open(lock_path, "w")
    try:
        fcntl.flock(lf, fcntl.LOCK_EX)
        if _try_send(args.socket, ""):  # someone already started it
            return True
        cmd = [uv, "run", "--script", os.path.abspath(__file__), "daemon",
               "--socket", args.socket,
               "--idle-timeout", str(args.idle_timeout),
               "--max-voices", str(args.max_voices)]
        if args.no_audio:
            cmd.append("--no-audio")
        devnull = os.open(os.devnull, os.O_RDWR)
        pid = os.fork()
        if pid == 0:
            os.setsid()
            os.dup2(devnull, 0); os.dup2(devnull, 1); os.dup2(devnull, 2)
            os.execv(cmd[0], cmd)
            os._exit(127)
        os.close(devnull)
        # Hold the lock until the daemon is reachable (~15s covers a cold uv
        # cache). Queued callers then find it up and skip their own spawn.
        for _ in range(300):
            if _try_send(args.socket, ""):
                break
            time.sleep(0.05)
        return True
    finally:
        fcntl.flock(lf, fcntl.LOCK_UN)
        lf.close()


def run_play(args):
    payload = args.path + "\n"
    if _try_send(args.socket, payload):
        return
    if not _spawn_daemon(args):
        sys.exit(1)  # no uv; caller falls back to paplay
    for _ in range(100):  # up to ~5s for the daemon to bind
        if _try_send(args.socket, payload):
            return
        time.sleep(0.05)
    sys.exit(1)
```
Note: an empty payload is a harmless liveness probe (daemon reads zero lines).

Register in `main()` after the `raw-send` parser:
```python
    p = sub.add_parser("play")
    p.add_argument("--socket", required=True)
    p.add_argument("--path", required=True)
    p.add_argument("--idle-timeout", type=float, default=30.0)
    p.add_argument("--max-voices", type=int, default=8)
    p.add_argument("--no-audio", action="store_true")
    p.set_defaults(func=run_play)
```

- [ ] **Step 4: Run the daemon test — expect PASS (or SKIP)**

Run: `bash plugins/audio-feedback/tests/test_daemon.sh; echo "exit=$?"`
Expected: all `[OK]` incl single-daemon-under-concurrency, `exit=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/bin/af-soundd plugins/audio-feedback/tests/test_daemon.sh
git commit -m "feat(audio-feedback): af-soundd play client (stdlib, uv auto-spawn)

play is stdlib-only (runs under bare python3): connects to the socket and,
on refusal, double-forks a detached daemon via uv run --script under a
flock (concurrent agents spawn exactly one), waits for readiness, sends the
path. Missing uv or delivery failure exits non-zero so the hook falls back
to paplay.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Hook integration + playback dispatch

Route `af_play_event*` through `af-soundd play` (bare `python3`), with the full `paplay` fallback ladder.

**Files:**
- Modify: `plugins/audio-feedback/scripts/lib.sh`
- Verify (no change): `plugins/audio-feedback/hooks/play-sound.sh`
- Test: `plugins/audio-feedback/tests/test_daemon.sh` (append fallback test)

**Interfaces:**
- Consumes: `af-soundd play` (Task 5); `AF_DAEMON_*` (Task 3); `af_sound_for_event`, `_af_sounds_dir` (Tasks 1-2).
- Produces: `af_dispatch_play <wav_path>` — plays one resolved WAV via the daemon client, falling back to `paplay`. `af_play_event` and `af_play_event_with_subtype` call it instead of `paplay`.

- [ ] **Step 1: Append the failing fallback test**

Append to `plugins/audio-feedback/tests/test_daemon.sh` before the final `exit "$fail"`:
```bash
# Fallback: DAEMON_ENABLED=false uses paplay, not the daemon.
STUB="/tmp/aftest-stub"; rm -rf "$STUB"; mkdir -p "$STUB"
cat >"$STUB/paplay" <<EOF
#!/bin/bash
echo "PAPLAY \$*" >> /tmp/aftest-calls.log
EOF
chmod +x "$STUB/paplay"
: > /tmp/aftest-calls.log
CFG3=/tmp/aftest-cfg3; rm -rf "$CFG3"; mkdir -p "$CFG3/.claude"
printf 'DAEMON_ENABLED=false\n' > "$CFG3/.claude/.audio-feedback-config"
HOME="$CFG3" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'
  af_load_config
  af_dispatch_play '$WAV'
"
if grep -q "PAPLAY $WAV" /tmp/aftest-calls.log; then ok "DAEMON_ENABLED=false falls back to paplay"; else bad "DAEMON_ENABLED=false falls back to paplay"; fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_daemon.sh; echo "exit=$?"`
Expected: FAIL — `af_dispatch_play` undefined (or `[SKIP]`).

- [ ] **Step 3: Implement `af_dispatch_play` and route playback in `lib.sh`**

Add near `af_play_event`:
```bash
# Absolute path to the daemon socket, or empty if no runtime dir.
_af_daemon_socket() {
    [ -n "${XDG_RUNTIME_DIR:-}" ] || return 0
    printf '%s/audio-feedback.sock' "$XDG_RUNTIME_DIR"
}

# Path to the af-soundd python tool (sibling bin/).
_af_soundd() {
    printf '%s' "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin/af-soundd"
}

# Daemon usable? Needs python3 (stdlib client) + uv (to spawn the daemon).
_af_deps_ok() {
    command -v python3 >/dev/null 2>&1 && command -v uv >/dev/null 2>&1
}

# Play one resolved WAV. Prefer the single daemon; fall back to paplay.
# Ladder: daemon disabled -> no runtime dir -> no python3/uv -> delivery
# failure. Any miss falls through to paplay so we are never silent.
af_dispatch_play() {
    local wav="$1" sock
    [ -f "$wav" ] || return 0
    sock="$(_af_daemon_socket)"
    if [ "${AF_DAEMON_ENABLED:-true}" = "true" ] && [ -n "$sock" ] && _af_deps_ok; then
        if python3 "$(_af_soundd)" play \
                --socket "$sock" --path "$wav" \
                --idle-timeout "${AF_DAEMON_IDLE_TIMEOUT:-30}" \
                --max-voices "${AF_DAEMON_MAX_VOICES:-8}" 2>/dev/null; then
            return 0
        fi
    fi
    paplay "$wav" 2>/dev/null || true
}
```
Replace the two direct `paplay "$sound_file" 2>/dev/null || true` calls (in `af_play_event` and the fallback tail of `af_play_event_with_subtype`) with:
```bash
    af_dispatch_play "$sound_file"
```
In `af_play_event_with_subtype`, replace the subtype-file branch body:
```bash
        if [ -f "$subtype_file" ]; then
            af_dispatch_play "$subtype_file"
            return 0
        fi
```

- [ ] **Step 4: Confirm the hook needs no change**

Read `plugins/audio-feedback/hooks/play-sound.sh`; it calls `af_play_event_with_subtype "$EVENT" "$SUBTYPE"` in a detached `&`/`disown`. Dispatch returns quickly (client sends and exits), so the existing detach stays correct. Verify:
```bash
shellcheck plugins/audio-feedback/hooks/play-sound.sh && echo OK
```

- [ ] **Step 5: Run all tests — expect PASS (or SKIP)**

Run:
```bash
for t in resolution config daemon; do
  echo "== $t =="; bash "plugins/audio-feedback/tests/test_$t.sh"; echo "exit=$?"
done
```
Expected: each `exit=0` (daemon may `[SKIP]` without uv).

- [ ] **Step 6: Shellcheck + commit**

Run: `shellcheck plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/tests/test_daemon.sh && echo OK`
```bash
git add plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/tests/test_daemon.sh
git commit -m "feat(audio-feedback): route playback through af-soundd with paplay fallback

af_dispatch_play runs af-soundd play under bare python3 (stdlib client),
falling back to paplay when the daemon is disabled, there is no
XDG_RUNTIME_DIR, python3/uv are missing, or delivery fails.
af_play_event/af_play_event_with_subtype dispatch through it, so N
concurrent events share one player.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Documentation

Document the daemon, uv dependency, setup pre-warm, and new config in README + SKILL; record changes in CHANGELOG under `[Unreleased]`. No version bump.

**Files:**
- Modify: `plugins/audio-feedback/README.md`, `plugins/audio-feedback/skills/audio-feedback/SKILL.md`, `plugins/audio-feedback/CHANGELOG.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update README prerequisites + config + daemon section**

In `plugins/audio-feedback/README.md`:
- Prerequisites table, add:
  `| uv | \`uv --version\` | Optional — enables the single-process playback daemon (supplies its python deps via PEP 723); without it, falls back to paplay per event |`
- Configuration table, add rows: `DAEMON_ENABLED` (`true`), `DAEMON_IDLE_TIMEOUT` (`30`), `DAEMON_MAX_VOICES` (`8`) per the spec descriptions.
- Add a "## Playback daemon" section (4-5 sentences): one resident `af-soundd` process holds a single PipeWire client and mixes all events; auto-spawns on first event via `uv run --script`, self-exits after `DAEMON_IDLE_TIMEOUT`; collapses N concurrent `paplay` calls into one process/one PipeWire client; the per-event client path is stdlib-only under bare `python3`; falls back to `paplay` when `uv` is absent. First spawn on a cold uv cache downloads wheels once; pre-warm with `uv run --script bin/af-soundd selftest`.

- [ ] **Step 2: Update SKILL notes + config table**

In `plugins/audio-feedback/skills/audio-feedback/SKILL.md`:
- In "Important Notes", replace the PipeWire line with:
  `- Requires PipeWire (\`paplay\`). The optional playback daemon (\`af-soundd\`) needs \`uv\` (which supplies sounddevice/soundfile/numpy via PEP 723) and collapses concurrent playback into one process / one PipeWire client; without uv, each event uses paplay. Subtype resolution needs \`jq\`.`
- Add `DAEMON_ENABLED`, `DAEMON_IDLE_TIMEOUT`, `DAEMON_MAX_VOICES` to the config reference table.

- [ ] **Step 3: Update CHANGELOG under [Unreleased]**

In `plugins/audio-feedback/CHANGELOG.md`, under `## [Unreleased]`, add (keep the existing Fixed entries for #40/#41):
```markdown
### Added
- Single-process playback daemon (`bin/af-soundd`): holds one persistent
  PipeWire client and mixes all event sounds, so N concurrent agents
  produce one player process instead of N `paplay` processes. The per-event
  client is stdlib-only under bare `python3`; the daemon's deps
  (sounddevice/soundfile/numpy) are PEP 723 inline metadata supplied by
  `uv run --script` (no venv). Auto-spawns on first event, self-exits after
  `DAEMON_IDLE_TIMEOUT`. Config: `DAEMON_ENABLED`, `DAEMON_IDLE_TIMEOUT`,
  `DAEMON_MAX_VOICES`. Falls back to `paplay` when `uv` is unavailable.

### Changed
- Sound themes now live under `sound-theme/<theme>/{sounds,src}` with a
  `theme.json` metadata file (freedesktop-inspired layout; Claude event
  names kept). Existing `sounds/<theme>/` is migrated.

### Removed
- Click-sounds subsystem and all `CLICKS_*` config keys. `sox` is no longer
  a runtime dependency. Stale `CLICKS_*` lines in existing configs are
  ignored.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/audio-feedback/README.md plugins/audio-feedback/skills/audio-feedback/SKILL.md plugins/audio-feedback/CHANGELOG.md
git commit -m "docs(audio-feedback): document playback daemon (uv/PEP 723), theme layout

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Clicks removal → Task 1. Freedesktop layout + theme.json → Task 2. Daemon config keys → Task 3. Daemon (socket, persistent stream, mixing, voice cap, idle-exit) + PEP 723/uv dep model → Tasks 4-5. Client stdlib + auto-spawn via uv + flock → Task 5. Hook dispatch + fallback ladder → Task 6. Docs → Task 7. Testing (test_config/test_resolution/test_daemon, shellcheck, --no-audio, selftest via uv) distributed across Tasks 2-6. All spec sections covered.
- Fallback ladder: `DAEMON_ENABLED=false` (Task 6 dispatch), no XDG_RUNTIME_DIR (`_af_daemon_socket` empty → Task 6), no python3/uv (`_af_deps_ok` → Task 6; `_spawn_daemon` uv check → Task 5), delivery failure (`run_play` non-zero → Task 6). Covered.
- "No version bump in Spec A" → honored (Task 7 uses `[Unreleased]`).

**Placeholder scan:** No TBD/TODO; every code step has literal code. `DAEMON_MAX_VOICES` default is concrete `8`.

**Type/name consistency:** `af_dispatch_play`, `_af_daemon_socket`, `_af_soundd`, `_af_deps_ok` defined and used within Task 6. `Mixer.add/render/active` consistent (Task 4 selftest, callback, Task 5). `af-soundd` subcommands `daemon`/`raw-send`/`play`/`selftest` consistent across implementation + tests. `_try_send`/`_spawn_daemon`/`run_play` defined and cross-referenced within Task 5. `af_list_themes` defined + used in Task 2. Daemon launched via `uv run --script` consistently in tests (Task 4/5) and `_spawn_daemon` (Task 5); client run via bare `python3` in tests and `af_dispatch_play` (Task 6).
