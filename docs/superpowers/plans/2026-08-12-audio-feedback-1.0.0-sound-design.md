# audio-feedback 1.0.0 (Spec B: Sound Design & Generation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Programmatically generate the default theme's 27-sound palette (+ a subagent-accent overlay) with signalflow from the locked note-map, gate on `analyze.py`, wire subagent-aware playback, remove the dead REAPER pipeline, and bump to 1.0.0.

**Architecture:** A `uv run --script` (PEP 723) signalflow generator synthesizes struck inharmonic bells per the note-map, assembles phrases in numpy, and writes mono 44.1k WAVs to `sound-theme/default/sounds/`. Category variants inherit a base event + a declarative accent (resynthesized). A single `subagent-accent.wav` is mixed at runtime by the daemon when a hook's JSON carries `agent_id`. `analyze.py`'s palette gate is the objective definition-of-done.

**Tech Stack:** signalflow 0.5.3 (uv-managed Python 3.12), numpy, scipy; bash hook/lib; pytest + bash tests.

## Global Constraints

- **Generation runs via uv only:** `generate.py` carries a PEP 723 header (`requires-python = ">=3.12,<3.13"`, `dependencies = ["signalflow","numpy","scipy"]`). Invoke with `UV_PYTHON_PREFERENCE=only-managed uv run --script <path>` (the env var avoids pyenv shims shadowing python3.12). Never assume a system signalflow.
- **Output format:** every generated WAV is mono, 44100 Hz, 16-bit PCM.
- **Loudness:** each file normalized to a ceiling of **-1 dBFS**; the whole palette must pass `analyze.py --palette`: RMS spread <= 3 dB AND peak <= -0.7 dBFS.
- **Note-map is law:** MIDI pitches + rhythm come from `note_map.json`, which mirrors the locked map exactly (session-start 48-52-55-58-60 rise; user-prompt 67; pre-tool-use 70; notification 60-67-70; pre-compact chord 43+46; post-tool-use 72; subagent-stop 64-60 fall; stop 72-71-67-64-60 fall).
- **signalflow multi-render pattern (verified):** one `AudioGraph(config=AudioGraphConfig(sample_rate=44100), output_device="dummy")`; per bell `patch.play()` then `render_to_new_buffer(n)`, then `graph.clear()` before the next bell. Downmix stereo->mono with `np.asarray(buf.data).mean(axis=0)`.
- **`.sh` shellcheck clean; `.py` importable and pytest-green.**
- **Verification vs ear:** SDD's definition-of-done for sound tasks is "all expected files emitted AND `analyze.py` gates pass." Subjective timbre polish (final partial ratios, the 19 accent values, the accent level) is Mae's, done interactively later via the dev venv — NOT an SDD gate. Ship gate-passing, coherent defaults.
- `.venv-gen/` is git-ignored.

## File Structure

- `plugins/audio-feedback/sound-theme/default/src/note_map.json` — note-map data (single source of truth).
- `plugins/audio-feedback/sound-theme/default/src/variants.json` — 19 variant accent-deltas.
- `plugins/audio-feedback/sound-theme/default/src/generate.py` — signalflow generator (PEP 723).
- `plugins/audio-feedback/sound-theme/default/sounds/*.wav` — 28 generated outputs (8 base + 19 variants + subagent-accent).
- `plugins/audio-feedback/scripts/analyze.py` — verification (repointed).
- `plugins/audio-feedback/scripts/sound_targets.json` — targets (+ transposed-variant entries).
- `plugins/audio-feedback/hooks/play-sound.sh`, `scripts/lib.sh`, `scripts/config.sh` — runtime subagent wiring.
- `plugins/audio-feedback/tests/test_generate.py` — generator gate (skips without uv).
- `plugins/audio-feedback/tests/test_subagent.sh` — subagent-accent dispatch.
- Removed: `scripts/scaffold_rpp.py`, `scripts/render-sounds.py`, `tests/test_scaffold.py`, `tests/test_render_lint.py`.
- `plugins/audio-feedback/README.md`, `skills/audio-feedback/SKILL.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json` — docs + version.

---

## Task 1: Note-map + variants data

**Files:**
- Create: `plugins/audio-feedback/sound-theme/default/src/note_map.json`, `.../src/variants.json`
- Test: `plugins/audio-feedback/tests/test_targets.py` (extend) OR new `tests/test_note_map.py`

**Interfaces:**
- Produces: `note_map.json` mapping each of the 8 base events to `{"mode": "seq"|"chord", "notes": [[midi, value], ...]}` where value in `{"quaver","crotchet","minim"}`. `variants.json` mapping each of the 19 variant names to `{"base": <event>, ...accent...}`.

- [ ] **Step 1: Write the failing data test**

Create `plugins/audio-feedback/tests/test_note_map.py`:
```python
import json, os
HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "sound-theme", "default", "src")
BASE = ["session-start","user-prompt-submit","pre-tool-use","notification",
        "pre-compact","post-tool-use","subagent-stop","stop"]
VALUES = {"quaver","crotchet","minim"}

def test_note_map_complete_and_valid():
    nm = json.load(open(os.path.join(SRC, "note_map.json")))
    assert set(nm) == set(BASE)
    assert nm["stop"]["notes"][0][0] == 72 and nm["session-start"]["notes"][0][0] == 48
    assert nm["pre-compact"]["mode"] == "chord"
    for ev in nm.values():
        assert ev["mode"] in {"seq","chord"}
        for midi, val in ev["notes"]:
            assert 0 <= midi <= 127 and val in VALUES

def test_variants_reference_valid_bases():
    nm = json.load(open(os.path.join(SRC, "note_map.json")))
    v = json.load(open(os.path.join(SRC, "variants.json")))
    assert len(v) == 19
    for name, spec in v.items():
        assert spec["base"] in nm
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m pytest plugins/audio-feedback/tests/test_note_map.py -q`
Expected: FAIL (files missing).

- [ ] **Step 3: Create `note_map.json`**

Create `plugins/audio-feedback/sound-theme/default/src/note_map.json`:
```json
{
  "session-start":      {"mode": "seq",   "notes": [[48,"quaver"],[52,"quaver"],[55,"quaver"],[58,"quaver"],[60,"minim"]]},
  "user-prompt-submit": {"mode": "seq",   "notes": [[67,"quaver"]]},
  "pre-tool-use":       {"mode": "seq",   "notes": [[70,"quaver"]]},
  "notification":       {"mode": "seq",   "notes": [[60,"quaver"],[67,"quaver"],[70,"crotchet"]]},
  "pre-compact":        {"mode": "chord", "notes": [[43,"minim"],[46,"minim"]]},
  "post-tool-use":      {"mode": "seq",   "notes": [[72,"quaver"]]},
  "subagent-stop":      {"mode": "seq",   "notes": [[64,"quaver"],[60,"crotchet"]]},
  "stop":               {"mode": "seq",   "notes": [[72,"quaver"],[71,"quaver"],[67,"quaver"],[64,"quaver"],[60,"minim"]]}
}
```

- [ ] **Step 4: Create `variants.json`** (starting accents — tuned by ear later)

Create `plugins/audio-feedback/sound-theme/default/src/variants.json`:
```json
{
  "pre-tool-use-execute":    {"base": "pre-tool-use",  "transpose": -2, "punch": 1.2},
  "pre-tool-use-observe":    {"base": "pre-tool-use",  "brightness": 0.9},
  "pre-tool-use-modify":     {"base": "pre-tool-use",  "layer": "shimmer"},
  "pre-tool-use-network":    {"base": "pre-tool-use",  "brightness": 1.3, "air_db": -12},
  "pre-tool-use-dispatch":   {"base": "pre-tool-use",  "transpose": 3},
  "pre-tool-use-interact":   {"base": "pre-tool-use",  "detune_cents": 6},
  "post-tool-use-execute":   {"base": "post-tool-use", "transpose": -2, "punch": 1.2},
  "post-tool-use-observe":   {"base": "post-tool-use", "brightness": 0.9},
  "post-tool-use-modify":    {"base": "post-tool-use", "layer": "shimmer"},
  "post-tool-use-network":   {"base": "post-tool-use", "brightness": 1.3, "air_db": -12},
  "post-tool-use-dispatch":  {"base": "post-tool-use", "transpose": 3},
  "post-tool-use-interact":  {"base": "post-tool-use", "detune_cents": 6},
  "notification-permission": {"base": "notification",  "brightness": 1.15},
  "notification-idle":       {"base": "notification",  "transpose": -2, "brightness": 0.9},
  "notification-auth":       {"base": "notification",  "layer": "shimmer"},
  "notification-elicitation":{"base": "notification",  "transpose": 2},
  "session-start-resume":    {"base": "session-start", "brightness": 1.05},
  "session-start-compact":   {"base": "session-start", "transpose": -2},
  "session-start-clear":     {"base": "session-start", "brightness": 1.1, "air_db": -14}
}
```

- [ ] **Step 5: Run the data test — expect PASS**

Run: `python -m pytest plugins/audio-feedback/tests/test_note_map.py -q`
Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/note_map.json \
        plugins/audio-feedback/sound-theme/default/src/variants.json \
        plugins/audio-feedback/tests/test_note_map.py
git commit -m "feat(audio-feedback): note-map + variant accent data for sound generation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Generator core — 8 base sounds

**Files:**
- Create: `plugins/audio-feedback/sound-theme/default/src/generate.py`
- Create: `plugins/audio-feedback/tests/test_generate.py`
- Modify: root `.gitignore` (add the dev venv)

**Interfaces:**
- Consumes: `note_map.json` (Task 1).
- Produces (CLI): `uv run --script generate.py [--only NAME ...]` renders WAVs into `../sounds/`. Functions: `midi_hz(m)`, `render_bell(freq, dur, brightness, decay_scale, detune_cents, punch, layer)`, `render_event(name, spec)`, `postprocess(sig)`, `write_wav(path, sig)`.

- [ ] **Step 1: Write the failing generator test**

Create `plugins/audio-feedback/tests/test_generate.py`:
```python
import os, shutil, subprocess, wave, sys
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
SOUNDS = os.path.join(PLUGIN, "sound-theme", "default", "sounds")
ANALYZE = os.path.join(PLUGIN, "scripts", "analyze.py")
BASE = ["session-start","user-prompt-submit","pre-tool-use","notification",
        "pre-compact","post-tool-use","subagent-stop","stop"]

pytestmark = pytest.mark.skipif(shutil.which("uv") is None, reason="uv required")

def _run_gen(*args):
    env = dict(os.environ, UV_PYTHON_PREFERENCE="only-managed")
    r = subprocess.run(["uv","run","--script",GEN,*args],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0, r.stderr
    return r

def test_base_sounds_emitted_mono_44100():
    _run_gen(*sum([["--only",b] for b in BASE], []))
    for b in BASE:
        p = os.path.join(SOUNDS, b + ".wav")
        assert os.path.exists(p), f"missing {b}.wav"
        with wave.open(p) as w:
            assert w.getnchannels() == 1 and w.getframerate() == 44100 and w.getsampwidth() == 2
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py -q`
Expected: FAIL (generate.py missing) or SKIP if uv absent (install uv first).

- [ ] **Step 3: Write `generate.py` (base synthesis)**

Create `plugins/audio-feedback/sound-theme/default/src/generate.py`:
```python
# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = ["signalflow", "numpy", "scipy"]
# ///
"""Generate the audio-feedback default theme by additive bell synthesis.

Run: UV_PYTHON_PREFERENCE=only-managed uv run --script generate.py [--only NAME ...]
Renders mono 44.1k WAVs to ../sounds/. See DESIGN-NOTES.md for the sound system.
"""
import json
import os
import sys

import numpy as np
from scipy.signal import fftconvolve
import signalflow as sf

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.normpath(os.path.join(HERE, "..", "sounds"))
NOTE_MAP = json.load(open(os.path.join(HERE, "note_map.json")))
VARIANTS = json.load(open(os.path.join(HERE, "variants.json")))

# onset spacing per note value (seconds); tunable. Bells ring past their slot.
VALUE_SEC = {"quaver": 0.12, "crotchet": 0.24, "minim": 0.48}
BELL_DUR = 0.6                      # per-bell ring-out length
PARTIALS = [(1.0, 1.0), (2.01, 0.5), (2.99, 0.28), (4.07, 0.15)]  # inharmonic

_graph = None
def _graph_get():
    global _graph
    if _graph is None:
        cfg = sf.AudioGraphConfig(); cfg.sample_rate = SR
        _graph = sf.AudioGraph(config=cfg, output_device="dummy")
    return _graph

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

def render_bell(freq, dur=BELL_DUR, brightness=1.0, decay_scale=1.0,
                detune_cents=0.0, punch=1.0, layer=None):
    """One struck inharmonic bell -> mono float32."""
    g = _graph_get()
    patch = None
    for i, (ratio, amp) in enumerate(PARTIALS):
        a = amp * (brightness ** i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        env = sf.ASREnvelope(0.003, 0.0, dur * decay_scale)
        v = sf.SineOscillator(freq * ratio * det) * env * a
        patch = v if patch is None else patch + v
    if layer == "shimmer":
        patch = patch + sf.SineOscillator(freq * 6.01) * sf.ASREnvelope(0.003, 0.0, dur * 0.5) * 0.06
    elif layer == "sub":
        patch = patch + sf.SineOscillator(freq * 0.5) * sf.ASREnvelope(0.003, 0.0, dur) * 0.2
    patch.play()
    buf = g.render_to_new_buffer(int(SR * dur))
    mono = np.asarray(buf.data).mean(axis=0).astype("float32")
    g.clear()
    return mono

def render_event(name, spec, accent=None):
    accent = accent or {}
    transpose = accent.get("transpose", 0)
    kw = {k: accent[k] for k in ("brightness","decay_scale","detune_cents","punch","layer")
          if k in accent}
    notes = spec["notes"]
    onsets = []
    t = 0.0
    for _, value in notes:
        onsets.append(t)
        t += 0.0 if spec["mode"] == "chord" else VALUE_SEC[value]
    total = int(SR * (max(onsets) + BELL_DUR))
    out = np.zeros(total, dtype="float32")
    for (midi, _), onset in zip(notes, onsets):
        bell = render_bell(midi_hz(midi + transpose), **kw)
        i = int(SR * onset)
        out[i:i + len(bell)] += bell[:total - i]
    return postprocess(out, accent)

def postprocess(sig, accent):
    # air layer as broadband high-shelf-ish noise-free partial already handled; here: reverb + EQ + normalize
    ir = np.random.RandomState(0).randn(int(SR * 0.35)) * np.exp(-np.linspace(0, 6, int(SR * 0.35)))
    ir = np.concatenate([np.zeros(int(SR * 0.008)), ir])
    wet = fftconvolve(sig, ir)[:len(sig)]
    sig = sig * 0.85 + wet / (np.max(np.abs(wet)) + 1e-9) * 0.15
    f = int(SR * 0.1)                        # 100ms tail fade
    if len(sig) > f:
        sig[-f:] *= np.linspace(1, 0, f)
    peak = np.max(np.abs(sig)) + 1e-9
    return (sig / peak) * 10 ** (-1 / 20)    # -1 dBFS

def write_wav(path, sig):
    import scipy.io.wavfile as wav
    wav.write(path, SR, (np.clip(sig, -1, 1) * 32767).astype(np.int16))

def all_targets():
    items = {n: (NOTE_MAP[n], None) for n in NOTE_MAP}
    for vname, spec in VARIANTS.items():
        items[vname] = (NOTE_MAP[spec["base"]], spec)
    return items

def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    only = [argv[i + 1] for i, a in enumerate(argv) if a == "--only"]
    os.makedirs(SOUNDS, exist_ok=True)
    for name, (spec, accent) in all_targets().items():
        if only and name not in only:
            continue
        sig = render_event(name, spec, accent)
        write_wav(os.path.join(SOUNDS, name + ".wav"), sig)
        print("wrote", name + ".wav")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Add the dev venv to `.gitignore`**

Append to the repo-root `.gitignore`:
```
plugins/audio-feedback/sound-theme/default/src/.venv-gen/
```

- [ ] **Step 5: Run the generator test — expect PASS (or SKIP)**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py -q`
Expected: 1 passed (all 8 base WAVs mono/44100/16-bit), or SKIP without uv.

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/generate.py \
        plugins/audio-feedback/tests/test_generate.py .gitignore \
        plugins/audio-feedback/sound-theme/default/sounds
git commit -m "feat(audio-feedback): signalflow generator for the 8 base sounds

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Variants + palette gate

Generate all 19 category variants and assert the full palette passes `analyze.py`.

**Files:**
- Modify: `plugins/audio-feedback/tests/test_generate.py`
- (generate.py already handles variants via `all_targets`; this task exercises + gates them.)

**Interfaces:**
- Consumes: `render_event` accent path (Task 2), `variants.json` (Task 1), `analyze.py --palette` (existing).

- [ ] **Step 1: Add the failing palette + variants test**

Append to `plugins/audio-feedback/tests/test_generate.py`:
```python
VARIANT_NAMES = [
  "pre-tool-use-execute","pre-tool-use-observe","pre-tool-use-modify","pre-tool-use-network",
  "pre-tool-use-dispatch","pre-tool-use-interact","post-tool-use-execute","post-tool-use-observe",
  "post-tool-use-modify","post-tool-use-network","post-tool-use-dispatch","post-tool-use-interact",
  "notification-permission","notification-idle","notification-auth","notification-elicitation",
  "session-start-resume","session-start-compact","session-start-clear",
]

def test_full_palette_generates_and_passes_loudness():
    _run_gen()                       # no --only => everything
    for n in BASE + VARIANT_NAMES:
        assert os.path.exists(os.path.join(SOUNDS, n + ".wav")), f"missing {n}.wav"
    r = subprocess.run([sys.executable, ANALYZE, "--palette", SOUNDS],
                       capture_output=True, text=True)
    assert r.returncode == 0, f"palette gate failed: {r.stdout}\n{r.stderr}"
```

- [ ] **Step 2: Run it to verify it fails (or reveals a gate failure to tune)**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py::test_full_palette_generates_and_passes_loudness -q`
Expected: FAIL first — either files missing (before a full run) or the palette gate rejects (RMS spread > 3 dB / peak > -0.7). If the gate fails, adjust `postprocess` normalization / per-event levels until it passes (this is the mechanical loudness gate, not ear-tuning).

Note for `analyze.py --palette`: it needs numpy/scipy. Run pytest under an interpreter that has them (e.g. the dev venv), or the test may need `sys.executable` to point at that venv. If the CI interpreter lacks numpy/scipy, mark this test to also skip when `import numpy` fails.

- [ ] **Step 3: Ensure the palette passes**

Run the generator and gate directly:
```bash
UV_PYTHON_PREFERENCE=only-managed uv run --script \
  plugins/audio-feedback/sound-theme/default/src/generate.py
python plugins/audio-feedback/scripts/analyze.py --palette \
  plugins/audio-feedback/sound-theme/default/sounds
```
Expected final line: `palette: 27 files, RMS spread <=3 dB, peak max <=-0.7 dBFS` and exit 0. If not, tune `postprocess` (uniform normalization already targets -1 dBFS; if spread is too wide, apply an RMS-match pass across the palette before the peak-normalize). Keep changes in `generate.py`.

- [ ] **Step 4: Run the test — expect PASS**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py -q`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/generate.py \
        plugins/audio-feedback/tests/test_generate.py \
        plugins/audio-feedback/sound-theme/default/sounds
git commit -m "feat(audio-feedback): generate 19 category variants; palette gate green

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Subagent-accent overlay sound

Generate the single `subagent-accent.wav` (a bare accent layer, no base phrase) and include it in the palette.

**Files:**
- Modify: `plugins/audio-feedback/sound-theme/default/src/generate.py`
- Modify: `plugins/audio-feedback/tests/test_generate.py`

**Interfaces:**
- Produces: `sound-theme/default/sounds/subagent-accent.wav` — a short quiet shimmer, mono 44.1k, that stays within the palette loudness spread.

- [ ] **Step 1: Add the failing accent test**

Append to `plugins/audio-feedback/tests/test_generate.py`:
```python
def test_subagent_accent_emitted():
    _run_gen()
    p = os.path.join(SOUNDS, "subagent-accent.wav")
    assert os.path.exists(p)
    with wave.open(p) as w:
        assert w.getnchannels() == 1 and w.getframerate() == 44100
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py::test_subagent_accent_emitted -q`
Expected: FAIL (no subagent-accent.wav).

- [ ] **Step 3: Add accent generation to `generate.py`**

In `main()`, after the palette loop (respecting `--only`), add:
```python
    if not only or "subagent-accent" in only:
        # a bare quiet shimmer: a single high struck partial, low level
        g = _graph_get()
        patch = sf.SineOscillator(midi_hz(84) * 6.01) * sf.ASREnvelope(0.003, 0.0, 0.3) * 0.05
        patch = patch + sf.SineOscillator(midi_hz(84) * 4.02) * sf.ASREnvelope(0.003, 0.0, 0.25) * 0.04
        patch.play()
        buf = g.render_to_new_buffer(int(SR * 0.35))
        sig = np.asarray(buf.data).mean(axis=0).astype("float32")
        g.clear()
        sig = postprocess(sig, {})
        # keep the accent a few dB under the palette so the overlay stays subtle
        sig *= 10 ** (-6 / 20)
        write_wav(os.path.join(SOUNDS, "subagent-accent.wav"), sig)
        print("wrote subagent-accent.wav")
```

- [ ] **Step 4: Run the full test suite — expect PASS**

Run: `python -m pytest plugins/audio-feedback/tests/test_generate.py -q`
Expected: all pass (28 files exist; palette gate still green — the accent is quiet and within spread; if it widens the spread beyond 3 dB, exclude the accent from the palette check by placing it in the palette but relying on its -6 dB offset; if needed, `analyze.py --palette` tolerance is the source of truth — do not loosen it, lower the accent instead).

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/generate.py \
        plugins/audio-feedback/tests/test_generate.py \
        plugins/audio-feedback/sound-theme/default/sounds/subagent-accent.wav
git commit -m "feat(audio-feedback): subagent-accent overlay sound

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Repoint analyze.py + remove dead REAPER pipeline

**Files:**
- Modify: `plugins/audio-feedback/scripts/analyze.py` (default paths), `scripts/sound_targets.json` (transposed-variant entries if needed)
- Delete: `scripts/scaffold_rpp.py`, `scripts/render-sounds.py`, `tests/test_scaffold.py`, `tests/test_render_lint.py`
- Test: existing `tests/test_analyze.py`, `tests/test_targets.py`

**Interfaces:**
- Produces: `analyze.py` whose defaults/examples reference `sound-theme/default/sounds`; a green pytest suite with no references to the removed scripts.

- [ ] **Step 1: Find stale references**

Run:
```bash
cd plugins/audio-feedback
grep -rnE "sounds/default|sounds/src|scaffold_rpp|render-sounds" scripts/*.py tests/*.py 2>/dev/null
```
Expected: matches in `render-sounds.py`, `scaffold_rpp.py`, `test_render_lint.py` (all being deleted) and possibly a default path in `analyze.py`.

- [ ] **Step 2: Remove the dead pipeline + its tests**

```bash
cd /home/cadrianmae/git/github.com/cadrianmae/claude-marketplace
git rm plugins/audio-feedback/scripts/scaffold_rpp.py \
       plugins/audio-feedback/scripts/render-sounds.py \
       plugins/audio-feedback/tests/test_scaffold.py \
       plugins/audio-feedback/tests/test_render_lint.py
```

- [ ] **Step 3: Repoint any default path in analyze.py**

Read `plugins/audio-feedback/scripts/analyze.py`. If `load_targets` or any default references a `sounds/` directory, update it to `sound-theme/default/sounds`. The CLI already takes an explicit path/`--palette <dir>`, so most callers are unaffected; only fix a hardcoded default if present. Do not change the checking logic.

- [ ] **Step 4: Run the python test suite — expect PASS**

Run: `python -m pytest plugins/audio-feedback/tests/ -q`
Expected: `test_note_map.py`, `test_analyze.py`, `test_targets.py`, `test_generate.py` collected; no import errors from removed modules; all pass (test_generate may skip without uv).

- [ ] **Step 5: Commit**

```bash
git add -A plugins/audio-feedback/scripts plugins/audio-feedback/tests
git commit -m "refactor(audio-feedback): remove dead REAPER pipeline; repoint analyze.py

Delete scaffold_rpp.py, render-sounds.py and their tests (superseded by the
signalflow generator). Repoint analyze.py paths to sound-theme/default/sounds.
Keep audio-feedback.rpp + vital-fxchain.rpp-fragment archived in src/.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Runtime subagent-accent wiring

Play `subagent-accent.wav` (mixed by the daemon) when a hook's JSON carries `agent_id` and `SUBAGENT_ACCENT=true`.

**Files:**
- Modify: `plugins/audio-feedback/scripts/lib.sh` (config default/load + accent dispatch), `scripts/config.sh` (validate/display), `hooks/play-sound.sh` (extract agent_id, overlay dispatch)
- Test: `plugins/audio-feedback/tests/test_subagent.sh`

**Interfaces:**
- Consumes: `af_dispatch_play` (Spec A, `lib.sh`), `_af_sounds_dir` (Spec A).
- Produces: `AF_SUBAGENT_ACCENT` (true|false, default true); `af_play_subagent_accent` which dispatches `subagent-accent.wav` if it exists.

- [ ] **Step 1: Write the failing subagent test**

Create `plugins/audio-feedback/tests/test_subagent.sh`:
```bash
#!/bin/bash
# When agent_id present + SUBAGENT_ACCENT=true, the accent sound is dispatched too.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
fail=0
ok()  { echo "[OK] $1"; }
bad() { echo "[FAIL] $1"; fail=1; }

STUB="/tmp/aftest-sub-stub"; rm -rf "$STUB"; mkdir -p "$STUB"
cat >"$STUB/paplay" <<EOF
#!/bin/bash
echo "PAPLAY \$*" >> /tmp/aftest-sub-calls.log
EOF
chmod +x "$STUB/paplay"
: > /tmp/aftest-sub-calls.log
CFG=/tmp/aftest-sub-cfg; rm -rf "$CFG"; mkdir -p "$CFG/.claude"
printf 'DAEMON_ENABLED=false\nPRE_TOOL_USE_SOUND=pre-tool-use\nSUBAGENT_ACCENT=true\n' \
  > "$CFG/.claude/.audio-feedback-config"

# invoke the accent helper directly with an agent_id present
HOME="$CFG" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'
  af_load_config
  af_play_subagent_accent
"
if grep -q "subagent-accent.wav" /tmp/aftest-sub-calls.log; then ok "accent dispatched"; else bad "accent dispatched"; fi

# with SUBAGENT_ACCENT=false -> no accent
: > /tmp/aftest-sub-calls.log
printf 'DAEMON_ENABLED=false\nSUBAGENT_ACCENT=false\n' > "$CFG/.claude/.audio-feedback-config"
HOME="$CFG" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'; af_load_config; af_play_subagent_accent
"
if grep -q "subagent-accent.wav" /tmp/aftest-sub-calls.log; then bad "accent suppressed when off"; else ok "accent suppressed when off"; fi

exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/audio-feedback/tests/test_subagent.sh; echo "exit=$?"`
Expected: FAIL — `af_play_subagent_accent` undefined and `SUBAGENT_ACCENT` unknown.

- [ ] **Step 3: Add config + accent dispatch to `lib.sh`**

Add default after `af_default_daemon_max_voices`:
```bash
af_default_subagent_accent="true"
```
In `af_load_config` init block:
```bash
    AF_SUBAGENT_ACCENT="$af_default_subagent_accent"
```
In the load `case`:
```bash
            SUBAGENT_ACCENT) AF_SUBAGENT_ACCENT="$value" ;;
```
In `af_ensure_config` heredoc:
```bash
SUBAGENT_ACCENT=$af_default_subagent_accent
```
Add the helper near `af_dispatch_play`:
```bash
# Mix the subagent accent over the current event sound (daemon overlays it).
# No-op unless enabled and the accent file exists.
af_play_subagent_accent() {
    [ "${AF_SUBAGENT_ACCENT:-true}" = "true" ] || return 0
    local accent
    accent="$(_af_sounds_dir)/subagent-accent.wav"
    [ -f "$accent" ] && af_dispatch_play "$accent"
}
```

- [ ] **Step 4: Validate + display in `config.sh`**

Add `SUBAGENT_ACCENT` to `VALID_KEYS`; add a display line after `DAEMON_MAX_VOICES`:
```bash
    echo "  SUBAGENT_ACCENT=$AF_SUBAGENT_ACCENT"
```
Add to the boolean validation arm:
```bash
        ENABLED|DAEMON_ENABLED|SUBAGENT_ACCENT)
```
(extend the existing `ENABLED|DAEMON_ENABLED)` arm to include `SUBAGENT_ACCENT`).

- [ ] **Step 5: Wire `play-sound.sh` to extract agent_id + overlay**

In `plugins/audio-feedback/hooks/play-sound.sh`, after `SUBTYPE` is resolved and `af_load_config` has run, extract `agent_id` and, inside the existing detached background block, call the accent after the event sound:
```bash
AGENT_ID=""
if [ -n "$HOOK_JSON" ] && command -v jq >/dev/null 2>&1; then
    AGENT_ID="$(printf '%s' "$HOOK_JSON" | jq -r '.agent_id // empty' 2>/dev/null)"
fi
```
Change the detached playback block to also overlay the accent when subagent:
```bash
{
    af_play_event_with_subtype "$EVENT" "$SUBTYPE"
    [ -n "$AGENT_ID" ] && af_play_subagent_accent
} </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
```
(If `play-sound.sh` currently backgrounds a single call, wrap it in the `{ ... } &` group as shown.)

- [ ] **Step 6: Run tests + shellcheck — expect PASS**

Run:
```bash
bash plugins/audio-feedback/tests/test_subagent.sh; echo "exit=$?"
shellcheck plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh \
           plugins/audio-feedback/hooks/play-sound.sh plugins/audio-feedback/tests/test_subagent.sh
```
Expected: subagent test all `[OK]` exit 0; shellcheck clean.

- [ ] **Step 7: Commit**

```bash
git add plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/scripts/config.sh \
        plugins/audio-feedback/hooks/play-sound.sh plugins/audio-feedback/tests/test_subagent.sh
git commit -m "feat(audio-feedback): subagent-accent overlay gated on agent_id

play-sound.sh extracts agent_id (present only for subagent tool calls) and,
when SUBAGENT_ACCENT=true, overlays subagent-accent.wav on the event sound
(the daemon mixes it; paplay fallback plays the base only).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Docs + version bump to 1.0.0

**Files:**
- Modify: `plugins/audio-feedback/.claude-plugin/plugin.json` (version), `README.md`, `skills/audio-feedback/SKILL.md`, `CHANGELOG.md`

**Interfaces:** none (docs/version).

- [ ] **Step 1: Bump version**

In `plugins/audio-feedback/.claude-plugin/plugin.json`, change `"version": "0.2.2"` to `"version": "1.0.0"`. In `skills/audio-feedback/SKILL.md` frontmatter, change `version: 0.2.2` to `version: 1.0.0`.

- [ ] **Step 2: Promote CHANGELOG to [1.0.0]**

In `plugins/audio-feedback/CHANGELOG.md`, rename the `## [Unreleased]` heading to `## [1.0.0] - 2026-08-12` and add a fresh empty `## [Unreleased]` above it. Under [1.0.0], add to the existing `### Added`:
```markdown
- Programmatic sound generation: signalflow generator (`sound-theme/default/src/generate.py`,
  run via `uv run --script`) renders the full 27-sound palette from a locked
  note-map with declarative accent-delta variants. Verification via
  `scripts/analyze.py` (per-sound + `--palette` loudness gate).
- Subagent-aware audio: a `subagent-accent.wav` is mixed over tool sounds fired
  on behalf of a subagent (hook `agent_id`), toggled by `SUBAGENT_ACCENT`.
```
Add to `### Removed`:
```markdown
- REAPER generation pipeline (`scaffold_rpp.py`, `render-sounds.py`) — superseded
  by the signalflow generator. The `.rpp` project + Vital patch are archived in
  `sound-theme/default/src/`.
```

- [ ] **Step 3: Update README + SKILL**

- README: add a "## Sound design" section (the mode/contour system + note-map, one paragraph) and a "## Regenerating sounds" section with the `uv venv` / `uv run --script generate.py` + `analyze.py --palette` workflow. Add `SUBAGENT_ACCENT` to the config table.
- SKILL: add `SUBAGENT_ACCENT` to the config reference table; add one line to Important Notes that subagent tool calls get an extra mixed accent when `agent_id` is present.

- [ ] **Step 4: Commit**

```bash
git add plugins/audio-feedback/.claude-plugin/plugin.json plugins/audio-feedback/README.md \
        plugins/audio-feedback/skills/audio-feedback/SKILL.md plugins/audio-feedback/CHANGELOG.md
git commit -m "docs(audio-feedback): document sound system + SUBAGENT_ACCENT; bump 1.0.0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Note-map as data → Task 1. Generator (base) → Task 2. Variants + accent extension → Task 3. Subagent-accent sound → Task 4. analyze.py repoint + REAPER cleanup → Task 5. Runtime subagent wiring + `SUBAGENT_ACCENT` → Task 6. Version 1.0.0 + docs → Task 7. signalflow via `uv run --script` / PEP 723 → Global Constraints + Task 2. Dev venv → Task 2 (.gitignore) + docs (Task 7). Palette gate as definition-of-done → Task 3. Archive `.rpp`+Vital → Task 5 (kept, not deleted). All spec sections covered.

**Placeholder scan:** No TBD/TODO. Every code step has literal content. The 19 accent values and partial ratios are concrete starting defaults (spec explicitly defers *ear-tuning* to a later human pass, gated meanwhile by `analyze.py`).

**Type/name consistency:** `render_bell`/`render_event`/`postprocess`/`write_wav`/`all_targets`/`midi_hz` defined in Task 2, used in Tasks 3-4. `AF_SUBAGENT_ACCENT` + `af_play_subagent_accent` defined and tested in Task 6. `_af_sounds_dir`/`af_dispatch_play` consumed from Spec A. `note_map.json`/`variants.json` produced in Task 1, consumed by `generate.py` (Task 2). The 8 base names + 19 variant names are identical between `variants.json` (Task 1), `test_generate.py` (Tasks 2-3), and the subtype system. `subagent-accent.wav` produced in Task 4, consumed in Task 6.

**Known risk flagged in-plan:** `analyze.py --palette` and `test_generate.py`'s palette assertion need numpy/scipy in the pytest interpreter; Task 3 Step 2 notes the skip-guard. Loudness-gate failures are tuned in `generate.py` (Task 3 Step 3), never by loosening the gate.
