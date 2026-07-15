# Audio-Feedback Sound Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the audio-feedback default theme with a premium, coherently-mapped sound family authored in REAPER, backed by a committed re-renderable generator and an objective audio-verification tool; retune the sox click engine.

**Architecture:** Event tones are designed in REAPER (`.rpp` committed as source-of-truth) and batch-rendered to `sounds/default/*.wav` by a ReaScript. A Python tool (`analyze.py`) measures each render (FFT partials, envelope, loudness) and checks it against a machine-readable target table, so quality is verified objectively rather than by ear. The runtime click engine stays sox (it must synthesize live inside the hook) and is retuned per premium-audio principles. The existing hook wiring already resolves category-variant filenames, so no wiring changes are needed.

**Tech Stack:** REAPER + ReaScript (Python API), Python 3.8+ with numpy/scipy (dev-time analysis only), sox (runtime click engine + test-fixture synthesis), bash.

## Global Constraints

- All rendered sounds: **mono, 44.1 kHz, WAV**. (Copied from spec.)
- Palette loudness **consistent**, peak ceiling **−1 dBTP** (~`norm -1`), ~1 dB headroom. No sound startlingly louder than another.
- Rendered filenames MUST match existing resolution: base `<event>.wav`; category variant `<event>-<group>.wav`; notification subtype `notification-<subtype>.wav`; session-start subtype `session-start-<subtype>.wav`. Groups: `execute, modify, network, observe, dispatch, interact`. (Wiring in `scripts/lib.sh` already resolves these — do not change it.)
- Runtime click engine stays **sox** in `scripts/lib.sh` — no DAW at runtime.
- `analyze.py` is a **dev-time tool**, never invoked by hooks. Its numpy/scipy deps live in `scripts/requirements-dev.txt`, run inside a venv.
- Language en-GB. No emoji / non-ASCII in code or committed docs; use `[OK]`/`[WARN]` tags.
- Python: activate venv before running.
- Work on branch `feat/audio-feedback-sound-redesign` (already created). Commit frequently.

All paths below are relative to repo root `plugins/audio-feedback/` unless stated. The scratchpad prototype `analyze.py` (session scratchpad) is the reference implementation to adapt.

---

### Task 1: Audio measurement core (`analyze.py` — load + measure)

The objective backbone. Pure functions that measure a WAV: normalized load, spectral partials, envelope (attack/decay), and integrated loudness proxy. TDD with sox-synthesized fixtures of known properties.

**Files:**
- Create: `plugins/audio-feedback/scripts/analyze.py`
- Create: `plugins/audio-feedback/scripts/requirements-dev.txt`
- Create: `plugins/audio-feedback/tests/test_analyze.py`
- Create: `plugins/audio-feedback/tests/conftest.py`

**Interfaces:**
- Produces: `load(path) -> (sr:int, x:np.ndarray)` (mono float, peak-normalized to 1.0); `peaks(sr, x, n=5) -> list[tuple[float,float]]` (freq Hz, level dB rel. loudest, sorted by freq); `envelope(sr, x) -> (attack_s:float, decay_s:float, dur_s:float)` (attack = time to RMS peak; decay = peak → −20 dB); `peak_dbfs(x) -> float`.

- [ ] **Step 1: Write requirements + conftest fixture helper**

Create `plugins/audio-feedback/scripts/requirements-dev.txt`:

```
numpy
scipy
pytest
```

Create `plugins/audio-feedback/tests/conftest.py`:

```python
import subprocess, os, pytest

@pytest.fixture
def sox_wav(tmp_path):
    """Synthesize a known WAV with sox for measurement tests."""
    def _make(name, *sox_args):
        out = str(tmp_path / name)
        subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", out, *sox_args],
                       check=True, capture_output=True)
        return out
    return _make
```

- [ ] **Step 2: Write the failing test**

Create `plugins/audio-feedback/tests/test_analyze.py`:

```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import analyze

def test_peaks_finds_fundamental(sox_wav):
    # pure 440 Hz sine, 0.5s
    w = sox_wav("a440.wav", "synth", "0.5", "sine", "440", "fade", "h", "0.01", "0.5", "0.1")
    sr, x = analyze.load(w)
    pk = analyze.peaks(sr, x, n=3)
    freqs = [f for f, _ in pk]
    assert any(abs(f - 440) < 5 for f in freqs)

def test_dominant_is_0db(sox_wav):
    w = sox_wav("a440.wav", "synth", "0.5", "sine", "440", "fade", "h", "0.01", "0.5", "0.1")
    sr, x = analyze.load(w)
    pk = analyze.peaks(sr, x, n=3)
    top = max(pk, key=lambda t: t[1])
    assert abs(top[1]) < 0.5  # loudest partial ~0 dB reference

def test_envelope_attack_and_decay(sox_wav):
    # slow 0.2s fade-in, so attack ~200ms
    w = sox_wav("swell.wav", "synth", "1.0", "sine", "440", "fade", "h", "0.2", "1.0", "0.3")
    sr, x = analyze.load(w)
    atk, dec, dur = analyze.envelope(sr, x)
    assert 0.15 < atk < 0.25
    assert dur > 0.9

def test_peak_dbfs_headroom(sox_wav):
    # file peaks at -6 dBFS; peak_dbfs on the raw samples should report ~-6
    w = sox_wav("q.wav", "synth", "0.3", "sine", "440", "gain", "-6")
    import scipy.io.wavfile as wf
    _, raw = wf.read(w)
    assert analyze.peak_dbfs(raw.astype(float) / 32768.0) < -3
```

- [ ] **Step 3: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && python3 -m venv .venv && . .venv/bin/activate && pip install -q -r scripts/requirements-dev.txt && python -m pytest tests/test_analyze.py -q
```
Expected: FAIL — `AttributeError: module 'analyze' has no attribute 'load'`.

- [ ] **Step 4: Write minimal implementation**

Create `plugins/audio-feedback/scripts/analyze.py`:

```python
#!/usr/bin/env python3
"""Objective audio measurement + target verification for the audio-feedback
default theme. Dev-time tool only (numpy/scipy); never invoked by hooks."""
import numpy as np
from scipy.io import wavfile


def load(path):
    sr, x = wavfile.read(path)
    if x.ndim > 1:
        x = x.mean(1)
    x = x.astype(float)
    x = x / (np.abs(x).max() + 1e-9)           # peak-normalize; relative measures
    return sr, x


def peaks(sr, x, n=5):
    seg = x[int(0.06 * sr):]                       # skip attack transient
    if len(seg) < 16:
        seg = x
    w = np.hanning(len(seg))
    X = np.abs(np.fft.rfft(seg * w))
    f = np.fft.rfftfreq(len(seg), 1 / sr)
    X = X / (X.max() + 1e-9)
    idx = []
    for i in np.argsort(X)[::-1]:
        if f[i] < 40:
            continue
        if all(abs(f[i] - f[j]) > 25 for j in idx):
            idx.append(i)
        if len(idx) >= n:
            break
    idx.sort(key=lambda i: f[i])
    return [(round(float(f[i]), 1), round(float(20 * np.log10(X[i] + 1e-9)), 1))
            for i in idx]


def envelope(sr, x):
    hop = max(1, int(0.01 * sr))
    e = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2))
                  for i in range(0, len(x) - hop, hop)])
    e = e / (e.max() + 1e-9)
    t = np.arange(len(e)) * (hop / sr)
    pk = int(np.argmax(e))
    attack = float(t[pk]) if len(t) else 0.0
    below = np.where(e[pk:] < 0.1)[0]
    decay = float(below[0] * hop / sr) if len(below) else float((len(e) - pk) * hop / sr)
    return attack, decay, len(x) / sr


def peak_dbfs(x):
    p = float(np.abs(x).max())
    return 20 * np.log10(p + 1e-9)
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_analyze.py -q
```
Expected: PASS (4 passed).

- [ ] **Step 6: Add venv + generated artifacts to gitignore**

Append to `plugins/audio-feedback/.gitignore` (create if absent):

```
.venv/
tests/__pycache__/
scripts/__pycache__/
```

- [ ] **Step 7: Commit**

```bash
git add plugins/audio-feedback/scripts/analyze.py plugins/audio-feedback/scripts/requirements-dev.txt plugins/audio-feedback/tests/ plugins/audio-feedback/.gitignore
git commit -m "feat(audio-feedback): add audio measurement core (analyze.py)"
```

---

### Task 2: Target table + verification (`analyze.py` — verify)

Machine-readable per-sound targets and a `verify()` that scores a WAV against its target: dominant note, secondary-note level, attack/decay windows, peak ceiling.

**Files:**
- Create: `plugins/audio-feedback/scripts/sound_targets.json`
- Modify: `plugins/audio-feedback/scripts/analyze.py` (add `load_targets`, `verify`)
- Modify: `plugins/audio-feedback/tests/test_analyze.py` (add verify tests)

**Interfaces:**
- Consumes: `load`, `peaks`, `envelope`, `peak_dbfs` from Task 1.
- Produces: `load_targets(path=None) -> dict` (event name → target dict); `verify(path, target) -> dict` with keys `ok:bool`, `checks:list[dict]` (each `{name, ok, measured, expected}`).

- [ ] **Step 1: Create the target table**

Create `plugins/audio-feedback/scripts/sound_targets.json` (values from the design spec's per-sound table; ranges give REAPER design latitude):

```json
{
  "stop":               {"partials_hz": [262, 392], "dominant_hz": 262, "second_max_db": -4.0, "attack_ms": [120, 260], "decay_ms": [500, 900], "peak_dbfs_max": -1.0},
  "notification":       {"partials_hz": [440, 523], "dominant_hz": 523, "second_max_db": -10.0, "attack_ms": [200, 360], "decay_ms": [150, 450], "peak_dbfs_max": -1.0},
  "session-start":      {"partials_hz": [262, 330, 392], "dominant_hz": 392, "second_max_db": -1.0, "attack_ms": [0, 200], "decay_ms": [300, 900], "peak_dbfs_max": -1.0},
  "subagent-stop":      {"partials_hz": [659], "dominant_hz": 659, "second_max_db": -1.0, "attack_ms": [0, 150], "decay_ms": [150, 600], "peak_dbfs_max": -1.0},
  "pre-compact":        {"partials_hz": [196], "dominant_hz": 196, "second_max_db": -1.0, "attack_ms": [0, 250], "decay_ms": [400, 1200], "peak_dbfs_max": -1.0},
  "user-prompt-submit": {"partials_hz": [880], "dominant_hz": 880, "second_max_db": -1.0, "attack_ms": [0, 100], "decay_ms": [100, 500], "peak_dbfs_max": -1.0},
  "pre-tool-use":       {"partials_hz": [500], "dominant_hz": 500, "second_max_db": -1.0, "attack_ms": [0, 120], "decay_ms": [80, 500], "peak_dbfs_max": -1.0},
  "post-tool-use":      {"partials_hz": [700], "dominant_hz": 700, "second_max_db": -1.0, "attack_ms": [0, 120], "decay_ms": [80, 500], "peak_dbfs_max": -1.0}
}
```

- [ ] **Step 2: Write the failing test**

Append to `plugins/audio-feedback/tests/test_analyze.py`:

```python
def test_load_targets_has_base_events():
    t = analyze.load_targets()
    for ev in ["stop", "notification", "session-start", "subagent-stop",
               "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]:
        assert ev in t

def test_verify_passes_matching_sound(sox_wav):
    # build a 262+392 dyad, C4 dominant, slow attack -> matches "stop" target
    c4 = sox_wav("c4.wav", "synth", "0.9", "sine", "262", "fade", "h", "0.18", "0.9", "0.7")
    g4 = sox_wav("g4.wav", "synth", "0.9", "sine", "392", "fade", "h", "0.18", "0.9", "0.7")
    import subprocess
    mix = c4.replace("c4.wav", "stop.wav")
    subprocess.run(["sox", "-m", "-v", "0.6", c4, "-v", "0.33", g4, mix,
                    "gain", "-8", "reverb", "40", "60", "90", "100", "10", "0",
                    "lowpass", "2000", "norm", "-1"], check=True, capture_output=True)
    t = analyze.load_targets()["stop"]
    r = analyze.verify(mix, t)
    assert r["ok"], r["checks"]

def test_verify_fails_wrong_note(sox_wav):
    w = sox_wav("wrong.wav", "synth", "0.9", "sine", "880", "fade", "h", "0.18", "0.9", "0.7", "norm", "-1")
    t = analyze.load_targets()["stop"]
    r = analyze.verify(w, t)
    assert not r["ok"]
```

- [ ] **Step 3: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_analyze.py -k "targets or verify" -q
```
Expected: FAIL — `module 'analyze' has no attribute 'load_targets'`.

- [ ] **Step 4: Write minimal implementation**

Append to `plugins/audio-feedback/scripts/analyze.py`:

```python
import json, os


def load_targets(path=None):
    if path is None:
        path = os.path.join(os.path.dirname(__file__), "sound_targets.json")
    with open(path) as f:
        return json.load(f)


def _nearest_level(pk, hz):
    """dB level of the partial nearest hz (or -120 if none within 30 Hz)."""
    cand = [(abs(f - hz), lv) for f, lv in pk]
    cand.sort()
    return cand[0][1] if cand and cand[0][0] < 30 else -120.0


def verify(path, target):
    sr, x = load(path)
    pk = peaks(sr, x, n=6)
    atk, dec, dur = envelope(sr, x)
    peak = peak_dbfs(x)                 # normalized load => ~0; check raw below
    _, raw = wavfile.read(path)
    raw = (raw.mean(1) if raw.ndim > 1 else raw).astype(float)
    raw = raw / 32768.0 if raw.max() > 1.5 else raw
    raw_peak = peak_dbfs(raw)

    checks = []

    dom = target["dominant_hz"]
    dom_lv = _nearest_level(pk, dom)
    top = max(pk, key=lambda t: t[1]) if pk else (0, -120)
    checks.append({"name": "dominant_note", "ok": abs(top[0] - dom) < 15,
                   "measured": top[0], "expected": dom})

    if len(target["partials_hz"]) > 1:
        others = [h for h in target["partials_hz"] if h != dom]
        sec_lv = max(_nearest_level(pk, h) for h in others)
        checks.append({"name": "second_level_db", "ok": sec_lv <= target["second_max_db"] + 3,
                       "measured": sec_lv, "expected": f"<= {target['second_max_db']}"})

    lo, hi = target["attack_ms"]
    checks.append({"name": "attack_ms", "ok": lo - 40 <= atk * 1000 <= hi + 40,
                   "measured": round(atk * 1000), "expected": f"{lo}-{hi}"})

    lo, hi = target["decay_ms"]
    checks.append({"name": "decay_ms", "ok": lo - 80 <= dec * 1000 <= hi + 80,
                   "measured": round(dec * 1000), "expected": f"{lo}-{hi}"})

    checks.append({"name": "peak_dbfs", "ok": raw_peak <= target["peak_dbfs_max"] + 0.3,
                   "measured": round(raw_peak, 1), "expected": f"<= {target['peak_dbfs_max']}"})

    return {"ok": all(c["ok"] for c in checks), "checks": checks}
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_analyze.py -q
```
Expected: PASS (all).

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/scripts/sound_targets.json plugins/audio-feedback/scripts/analyze.py plugins/audio-feedback/tests/test_analyze.py
git commit -m "feat(audio-feedback): add sound targets + verify()"
```

---

### Task 3: `analyze.py` CLI + palette loudness check

A CLI so Mae can verify a render against its target and check whole-palette loudness consistency from one command.

**Files:**
- Modify: `plugins/audio-feedback/scripts/analyze.py` (add `main`/argparse + `palette_loudness`)
- Modify: `plugins/audio-feedback/tests/test_analyze.py`

**Interfaces:**
- Consumes: `load`, `peak_dbfs`, `verify`, `load_targets`.
- Produces: `palette_loudness(dir) -> dict` (`{files:int, rms_spread_db:float, peak_max_dbfs:float}`); CLI `python analyze.py <wav> [event]` and `python analyze.py --palette <dir>`.

- [ ] **Step 1: Write the failing test**

Append to `plugins/audio-feedback/tests/test_analyze.py`:

```python
def test_palette_loudness_reports_spread(sox_wav, tmp_path):
    import subprocess
    d = tmp_path / "pal"; d.mkdir()
    for f, g in [("a.wav", "-3"), ("b.wav", "-3.5")]:
        subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", str(d / f),
                        "synth", "0.4", "sine", "440", "gain", g, "norm", "-1"],
                       check=True, capture_output=True)
    r = analyze.palette_loudness(str(d))
    assert r["files"] == 2
    assert r["rms_spread_db"] < 3
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_analyze.py -k palette -q
```
Expected: FAIL — `no attribute 'palette_loudness'`.

- [ ] **Step 3: Write minimal implementation**

Append to `plugins/audio-feedback/scripts/analyze.py`:

```python
import glob, sys


def palette_loudness(directory):
    rms = []
    peak_max = -120.0
    files = sorted(glob.glob(os.path.join(directory, "*.wav")))
    for p in files:
        sr, x = load(p)
        rms.append(20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9))
        _, raw = wavfile.read(p)
        raw = (raw.mean(1) if raw.ndim > 1 else raw).astype(float)
        raw = raw / 32768.0 if raw.max() > 1.5 else raw
        peak_max = max(peak_max, peak_dbfs(raw))
    spread = (max(rms) - min(rms)) if rms else 0.0
    return {"files": len(files), "rms_spread_db": round(spread, 2),
            "peak_max_dbfs": round(peak_max, 2)}


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if argv and argv[0] == "--palette":
        r = palette_loudness(argv[1])
        print(f"palette: {r['files']} files, RMS spread {r['rms_spread_db']} dB, "
              f"peak max {r['peak_max_dbfs']} dBFS")
        return 0 if r["rms_spread_db"] <= 3.0 and r["peak_max_dbfs"] <= -0.7 else 1
    if not argv:
        print("usage: analyze.py <wav> [event] | analyze.py --palette <dir>")
        return 2
    path = argv[0]
    event = argv[1] if len(argv) > 1 else os.path.splitext(os.path.basename(path))[0]
    targets = load_targets()
    if event not in targets:
        sr, x = load(path)
        print(f"{event}: partials {peaks(sr, x)}, envelope {envelope(sr, x)}")
        return 0
    r = verify(path, targets[event])
    for c in r["checks"]:
        tag = "[OK]  " if c["ok"] else "[WARN]"
        print(f"{tag} {c['name']}: measured {c['measured']} expected {c['expected']}")
    print("[OK] PASS" if r["ok"] else "[WARN] FAIL")
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_analyze.py -q
```
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/scripts/analyze.py plugins/audio-feedback/tests/test_analyze.py
git commit -m "feat(audio-feedback): add analyze CLI + palette loudness check"
```

---

### Task 4: REAPER starter project scaffold

A committed `.rpp` with one named track + render region per sound filename, so Mae opens it and drops synths onto pre-labelled tracks. REAPER project format is line-based text; a small generator writes it deterministically from the filename list.

**Files:**
- Create: `plugins/audio-feedback/scripts/scaffold_rpp.py`
- Create: `plugins/audio-feedback/sounds/src/audio-feedback.rpp` (generated output, committed)
- Create: `plugins/audio-feedback/tests/test_scaffold.py`

**Interfaces:**
- Produces: `sound_names() -> list[str]` (all 28 filenames without `.wav`, base + variants); `build_rpp(names) -> str` (valid minimal REAPER project text with one track + one region marker per name).

- [ ] **Step 1: Write the failing test**

Create `plugins/audio-feedback/tests/test_scaffold.py`:

```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import scaffold_rpp as s

def test_sound_names_cover_base_and_variants():
    names = s.sound_names()
    assert "stop" in names
    assert "pre-tool-use-execute" in names
    assert "post-tool-use-network" in names
    assert "notification-permission" in names
    assert "session-start-resume" in names
    # 8 base + 6 pre + 6 post + 4 notification + 3 session-start = 27..28
    assert len(names) >= 27

def test_build_rpp_is_reaper_project_with_regions():
    names = ["stop", "notification"]
    txt = s.build_rpp(names)
    assert txt.startswith("<REAPER_PROJECT")
    assert txt.strip().endswith(">")
    # one named track + region marker per name
    for n in names:
        assert f'NAME "{n}"' in txt or f'NAME {n}' in txt
    assert txt.count("<TRACK") == len(names)
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_scaffold.py -q
```
Expected: FAIL — `No module named 'scaffold_rpp'`.

- [ ] **Step 3: Write minimal implementation**

Create `plugins/audio-feedback/scripts/scaffold_rpp.py`:

```python
#!/usr/bin/env python3
"""Generate a starter REAPER project: one named track + region marker per
audio-feedback sound filename. Mae opens it and adds synths per track.
Dev-time tool. Run: python scaffold_rpp.py > ../sounds/src/audio-feedback.rpp"""

BASE = ["stop", "notification", "session-start", "subagent-stop",
        "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
GROUPS = ["execute", "modify", "network", "observe", "dispatch", "interact"]
NOTIF = ["auth", "elicitation", "idle", "permission"]
SESSION = ["clear", "compact", "resume"]


def sound_names():
    names = list(BASE)
    names += [f"pre-tool-use-{g}" for g in GROUPS]
    names += [f"post-tool-use-{g}" for g in GROUPS]
    names += [f"notification-{s}" for s in NOTIF]
    names += [f"session-start-{s}" for s in SESSION]
    return names


def build_rpp(names):
    lines = ['<REAPER_PROJECT 0.1 "7.0" 0', "  SAMPLERATE 44100 0 0"]
    slot = 0.0
    for n in names:
        # region marker pair around a 2s slot per sound (MARKER start / end)
        lines.append(f'  MARKER {2 * slot + 1} {slot * 2.0} "{n}" 1 0 1 R {{{n}}}')
        lines.append(f'  MARKER {2 * slot + 2} {slot * 2.0 + 1.5} "" 1')
        slot += 1
    for n in names:
        lines.append("  <TRACK")
        lines.append(f'    NAME "{n}"')
        lines.append("  >")
    lines.append(">")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    import sys
    sys.stdout.write(build_rpp(sound_names()))
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_scaffold.py -q
```
Expected: PASS.

- [ ] **Step 5: Generate and commit the scaffold**

Run:
```bash
cd plugins/audio-feedback && mkdir -p sounds/src && . .venv/bin/activate && python scripts/scaffold_rpp.py > sounds/src/audio-feedback.rpp && head -3 sounds/src/audio-feedback.rpp
```
Expected: first line `<REAPER_PROJECT 0.1 "7.0" 0`.

```bash
git add plugins/audio-feedback/scripts/scaffold_rpp.py plugins/audio-feedback/sounds/src/audio-feedback.rpp plugins/audio-feedback/tests/test_scaffold.py
git commit -m "feat(audio-feedback): REAPER starter project scaffold"
```

> **Note:** the scaffold is a *starting skeleton*. Mae will re-save the `.rpp` from REAPER after adding synths/FX; that re-saved project becomes the real source-of-truth. Region names must stay equal to the filenames so Task 5 renders correctly.

---

### Task 5: ReaScript batch renderer

A ReaScript (Python) that renders each region to `sounds/default/<region>.wav` at mono/44.1 kHz, normalized to −1 dB. Cannot be unit-tested (needs REAPER's API); ships with a documented invocation and a static lint check.

**Files:**
- Create: `plugins/audio-feedback/scripts/render-sounds.py`
- Create: `plugins/audio-feedback/tests/test_render_lint.py`

**Interfaces:**
- Consumes: region names on the open REAPER project (equal to filenames).
- Produces: `sounds/default/*.wav` when run inside REAPER.

- [ ] **Step 1: Write the failing lint test**

Create `plugins/audio-feedback/tests/test_render_lint.py`:

```python
import os, py_compile, pytest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "render-sounds.py")

def test_render_script_compiles():
    py_compile.compile(SCRIPT, doraise=True)

def test_render_targets_default_dir_and_settings():
    src = open(SCRIPT).read()
    assert "sounds/default" in src
    assert "44100" in src
    # renders per-region and normalizes
    assert "RegionRenderMatrix" in src or "GetSetProjectInfo_String" in src
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_render_lint.py -q
```
Expected: FAIL — file not found / does not compile.

- [ ] **Step 3: Write the ReaScript**

Create `plugins/audio-feedback/scripts/render-sounds.py`:

```python
"""ReaScript: batch-render every project region to sounds/default/<region>.wav
(mono, 44.1 kHz, normalized to -1 dB). Run from REAPER:
  Actions > Show action list > ReaScript: Load > this file > Run
Requires the reapy-free native ReaScript Python API (RPR_* functions).
Invoke headless (optional):
  ~/.local/opt/REAPER/reaper -new -nosplash \\
    -renderproject plugins/audio-feedback/sounds/src/audio-feedback.rpp
(after configuring render settings once in-project).
"""
import os
try:
    from reaper_python import (RPR_GetProjectPath, RPR_EnumProjectMarkers,
                               RPR_GetSetProjectInfo_String, RPR_Main_OnCommand,
                               RPR_ShowConsoleMsg)
except ImportError:  # allows py_compile lint outside REAPER
    RPR_GetProjectPath = RPR_EnumProjectMarkers = None

OUT_SUBDIR = os.path.join("sounds", "default")
SR = 44100


def _regions():
    names, i = [], 0
    while True:
        ok, _, _, isrgn, pos, rgnend, name, idx = RPR_EnumProjectMarkers(i, 0, 0, 0, "", 0)
        if ok == 0:
            break
        if isrgn:
            names.append((name, pos, rgnend))
        i += 1
    return names


def render_all():
    # Configure render: mono, 44.1k, normalize -1 dB, per-region, WAV.
    RPR_GetSetProjectInfo_String(0, "RENDER_FILE", OUT_SUBDIR, True)
    RPR_GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", True)
    # SRATE / channels / normalize configured in the saved project's render dialog.
    # 42230 = File: Render project, using the most recent render settings.
    RPR_Main_OnCommand(41824, 0)  # render using last settings (all regions matrix)
    RPR_ShowConsoleMsg("[OK] rendered regions to %s\n" % OUT_SUBDIR)


if __name__ == "__main__" and RPR_EnumProjectMarkers is not None:
    render_all()
```

- [ ] **Step 4: Run lint test to verify pass**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python -m pytest tests/test_render_lint.py -q
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/scripts/render-sounds.py plugins/audio-feedback/tests/test_render_lint.py
git commit -m "feat(audio-feedback): ReaScript batch renderer"
```

> **Note:** REAPER render settings (mono, 44.1 kHz, normalize −1 dB, per-region matrix) are set once in the render dialog and saved into the `.rpp`. The ReaScript triggers a render using those saved settings. Document the exact dialog settings in Task 8.

---

### Task 6: [MANUAL — Mae] Design + render the sounds in REAPER

Creative sound design in REAPER. Not code; acceptance is objective via `analyze.py`. This is the task only Mae can do.

**Files:**
- Modify: `plugins/audio-feedback/sounds/src/audio-feedback.rpp` (re-saved from REAPER with synths + FX)
- Create/replace: `plugins/audio-feedback/sounds/default/*.wav` (28 rendered files)

**Design brief (from spec):**
- **Contour = lifecycle:** rising = start/attention (`session-start`, `notification`, `pre-tool-use`); falling to resolved root = finished (`stop`, `post-tool-use`, `subagent-stop`).
- **Category = accent overlay** on the `pre-tool-use`/`post-tool-use` base: execute→bright click, network→soft whoosh, modify→pluck, observe→soft tick, dispatch→double tick, interact→mid tick.
- **Premium:** soft attack; struck/percussive body with smooth decay; consonant intervals within ~one octave; EQ mud-cut ~300–500 Hz + gentle air ~6–10 kHz; reverb with 5–15 ms pre-delay, low reverberance; per-track limiter to −1 dBTP; consistent loudness.
- Match the intent of `sound_targets.json` (notes + envelope windows) — ranges give latitude; contour must hold.

- [ ] **Step 1:** Open `sounds/src/audio-feedback.rpp` in REAPER. On each pre-labelled track, add a synth (ReaSynth or preferred VST) and an FX chain: ReaEQ (mud-cut + air) → ReaVerbate/reverb (pre-delay) → ReaLimit (−1 dB).
- [ ] **Step 2:** Design each base sound to its contour/notes; keep the region name = filename.
- [ ] **Step 3:** Design the `pre-tool-use-*` / `post-tool-use-*` variants as base + category accent; design `notification-*` and `session-start-*` subtypes.
- [ ] **Step 4:** Set render settings once: Mono, 44100 Hz, Normalize to −1 dB, Render matrix = regions → `sounds/default/$region.wav`. Save the project.
- [ ] **Step 5:** Run the renderer (`render-sounds.py` from the REAPER action list, or the render dialog) to produce all 28 WAVs.
- [ ] **Step 6: Verify each render against its target**

Run (base events; variants inherit their base target):
```bash
cd plugins/audio-feedback && . .venv/bin/activate
for e in stop notification session-start subagent-stop pre-compact user-prompt-submit pre-tool-use post-tool-use; do
  echo "== $e =="; python scripts/analyze.py sounds/default/$e.wav $e
done
```
Expected: each prints `[OK] PASS` (or close, with any `[WARN]` understood and accepted).

- [ ] **Step 7: Verify palette loudness consistency**

Run:
```bash
cd plugins/audio-feedback && . .venv/bin/activate && python scripts/analyze.py --palette sounds/default
```
Expected: `RMS spread <= 3 dB`, `peak max <= -0.7 dBFS`; command exits 0.

- [ ] **Step 8: Commit the sources + renders**

```bash
git add plugins/audio-feedback/sounds/src/audio-feedback.rpp plugins/audio-feedback/sounds/default/
git commit -m "feat(audio-feedback): premium REAPER-authored default theme"
```

---

### Task 7: Retune the sox click engine

Apply premium principles to the runtime click generator in `lib.sh` while keeping it pure sox and preserving the token-driven rate curve and config keys.

**Files:**
- Modify: `plugins/audio-feedback/scripts/lib.sh` (the click synth block, ~lines 345–405)
- Create: `plugins/audio-feedback/tests/test_clicks.sh`

**Interfaces:**
- Consumes: `CLICKS_RATE*` config, token count (unchanged signatures).
- Produces: a click-sequence WAV with no clipping, matching the configured rate.

- [ ] **Step 1: Write the failing test**

Create `plugins/audio-feedback/tests/test_clicks.sh`:

```bash
#!/usr/bin/env bash
# Verifies the click engine emits a non-clipping WAV of sane duration.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DIR/scripts/lib.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Render ~200 tokens of clicks to a file (function writes a sequence WAV).
out="$tmp/clicks.wav"
af_render_clicks 200 "$out"   # NEW: file-output entry point (see Step 3)

[ -s "$out" ] || { echo "[FAIL] no click file"; exit 1; }
# peak must be below 0 dBFS (no clipping): sox stat max amplitude < 1.0
peak="$(sox "$out" -n stat 2>&1 | awk '/Maximum amplitude/ {print $3}')"
awk -v p="$peak" 'BEGIN { exit !(p < 1.0 && p > 0.05) }' \
  || { echo "[FAIL] peak $peak out of range"; exit 1; }
echo "[OK] clicks render, peak $peak"
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd plugins/audio-feedback && bash tests/test_clicks.sh
```
Expected: FAIL — `af_render_clicks: command not found` (function does not exist yet).

- [ ] **Step 3: Refactor click synth into a testable file-output function + premium tuning**

In `plugins/audio-feedback/scripts/lib.sh`, extract the click-sequence synthesis (currently inline in the play path, ~lines 345–405) into `af_render_clicks <tokens> <outfile>` that writes the sequence WAV, and have the existing play path call it then pipe to `paplay`. Apply premium tuning to the per-click mix and the final bus:

```bash
# af_render_clicks TOKENS OUTFILE
# Synthesize the token-scaled glassy click sequence to OUTFILE (mono 44.1k).
# Premium tuning vs the old inline version:
#   - softer per-click fades (fade q) to remove ticks/clicks-on-clicks
#   - gentle high-shelf roll-off (lowpass) to tame fizz
#   - reverb with short pre-delay + lower wet, then normalise with headroom
af_render_clicks() {
    local tokens="$1" outfile="$2"
    local tmpdir; tmpdir="$(mktemp -d)"
    local max_dur; max_dur="$(af_clicks_duration "$tokens")"   # existing rate curve
    local base_gap; base_gap="$(af_clicks_base_gap "$tokens")" # existing
    local click_dur=0.03 t=0 i=0 lo hi sh gap d
    while (( $(awk -v t="$t" -v m="$max_dur" 'BEGIN{print (t<m)?1:0}') )); do
        lo=$(( 5050 + RANDOM % 301 - 150 ))
        hi=$(( 10000 + RANDOM % 501 - 250 ))
        sh=$(( 3500 + RANDOM % 401 - 200 ))
        gap="$(awk -v bg="$base_gap" -v t="$t" -v m="$max_dur" 'BEGIN{r=t/m;printf "%.4f", bg*(1+r*r*4)}')"
        d="$tmpdir/c$(printf '%03d' "$i")"
        sox -n -r 44100 -c 1 "${d}_lo.wav" synth "$click_dur" sine "$lo" fade q 0.0004 "$click_dur" 0.015 vol 0.018 2>/dev/null
        sox -n -r 44100 -c 1 "${d}_hi.wav" synth "$click_dur" sine "$hi" fade q 0.0004 "$click_dur" 0.008 vol 0.012 2>/dev/null
        sox -n -r 44100 -c 1 "${d}_sh.wav" synth "$click_dur" sine "$sh" fade q 0.0004 "$click_dur" 0.006 vol 0.010 2>/dev/null
        sox -n -r 44100 -c 1 "${d}_n.wav"  synth "$click_dur" pinknoise fade q 0.0004 "$click_dur" 0.010 lowpass 6000 vol 0.020 2>/dev/null
        sox -m "${d}_lo.wav" "${d}_hi.wav" "${d}_sh.wav" "${d}_n.wav" "${d}.wav" pad 0 "$gap" 2>/dev/null
        t="$(awk -v t="$t" -v g="$gap" -v c="$click_dur" 'BEGIN{printf "%.4f", t+g+c}')"
        i=$((i + 1))
    done
    sox "$tmpdir"/c???.wav "$tmpdir/full.wav" 2>/dev/null
    # premium bus: tame fizz, short-predelay reverb, headroom
    sox "$tmpdir/full.wav" "$outfile" lowpass 12000 reverb 28 50 70 100 8 0 gain -n -1 2>/dev/null
    rm -rf "$tmpdir"
}
```

Then update the existing play path to use it:

```bash
# (in the former inline location) replace inline synth+play with:
_af_click_tmp="$(mktemp --suffix=.wav)"
af_render_clicks "$token_count" "$_af_click_tmp"
paplay "$_af_click_tmp" 2>/dev/null || true
rm -f "$_af_click_tmp"
```

> If helper names `af_clicks_duration` / `af_clicks_base_gap` do not already exist, extract the current inline `max_dur` / `base_gap` computations into them (same formulae) as part of this step, so both the play path and `af_render_clicks` share them (DRY).

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd plugins/audio-feedback && bash tests/test_clicks.sh
```
Expected: `[OK] clicks render, peak <value>` and exit 0.

- [ ] **Step 5: Manual audition (optional but recommended)**

Run:
```bash
cd plugins/audio-feedback && source scripts/lib.sh && t="$(mktemp --suffix=.wav)" && af_render_clicks 400 "$t" && play "$t"; rm -f "$t"
```
Expected: a smooth glassy click run, no harsh ticks, tail rings out.

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/scripts/lib.sh plugins/audio-feedback/tests/test_clicks.sh
git commit -m "feat(audio-feedback): premium retune of sox click engine"
```

---

### Task 8: Docs, changelog, version bump

Document the new sound family, the category-accent mapping, and the REAPER regeneration workflow; record the change; bump the version.

**Files:**
- Modify: `plugins/audio-feedback/README.md`
- Modify: `plugins/audio-feedback/CHANGELOG.md`
- Modify: `plugins/audio-feedback/.claude-plugin/plugin.json`

- [ ] **Step 1: Update the README sound table + add a Regenerating Sounds section**

In `plugins/audio-feedback/README.md`: replace the "Default Theme Sounds" table with the new palette (base tones + note description), add a short "Category accents" subsection (the group→accent table from the spec), and add a "Regenerating sounds (maintainers)" section:

```markdown
## Regenerating sounds (maintainers)

Event tones are authored in REAPER and rendered to `sounds/default/`.

1. Open `sounds/src/audio-feedback.rpp` in REAPER.
2. Render settings: Mono, 44100 Hz, Normalize to -1 dB, Render matrix =
   regions to `sounds/default/$region.wav`.
3. Run `scripts/render-sounds.py` from the REAPER action list (or the
   render dialog) to render all regions.
4. Verify: `python scripts/analyze.py sounds/default/<name>.wav <event>`
   and `python scripts/analyze.py --palette sounds/default`
   (needs `pip install -r scripts/requirements-dev.txt` in a venv).

The click sounds are synthesized live by sox at runtime (`scripts/lib.sh`);
they are not rendered files.
```

- [ ] **Step 2: Add a CHANGELOG entry**

Under `## [Unreleased]` in `plugins/audio-feedback/CHANGELOG.md`:

```markdown
## [Unreleased]

### Changed
- Redesigned the default theme: premium, coherently-mapped sound family
  authored in REAPER (contour = lifecycle, accent overlay = tool category).
- Retuned the sox click engine (softer per-click fades, fizz roll-off,
  short-predelay reverb, -1 dB headroom).

### Added
- `sounds/src/audio-feedback.rpp` — committed REAPER source project.
- `scripts/render-sounds.py` — ReaScript batch renderer.
- `scripts/analyze.py` + `scripts/sound_targets.json` — objective audio
  verification (FFT/envelope/loudness vs per-sound targets).
- `scripts/scaffold_rpp.py` — regenerates the REAPER project skeleton.
```

- [ ] **Step 3: Bump the version**

In `plugins/audio-feedback/.claude-plugin/plugin.json`, change `"version": "0.2.2"` to `"version": "0.3.0"` (new feature, backward-compatible config).

- [ ] **Step 4: Verify docs reference real paths**

Run:
```bash
cd plugins/audio-feedback && for f in scripts/render-sounds.py scripts/analyze.py scripts/sound_targets.json sounds/src/audio-feedback.rpp; do test -e "$f" && echo "[OK] $f" || echo "[WARN] MISSING $f"; done
grep -q '0.3.0' .claude-plugin/plugin.json && echo "[OK] version bumped"
```
Expected: all `[OK]`.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/README.md plugins/audio-feedback/CHANGELOG.md plugins/audio-feedback/.claude-plugin/plugin.json
git commit -m "docs(audio-feedback): document redesign; bump to 0.3.0"
```

---

## Notes on ordering

Tasks 1–5, 7, 8 are Claude's (code/docs) and can proceed immediately and in order. **Task 6 (REAPER design) is Mae's and gates final acceptance** — Tasks 1–5 produce the tools and scaffold she needs; Task 6 uses them; Task 8's palette verification depends on Task 6's renders existing. Task 7 (click engine) is independent and can be done any time. Recommended order: 1 → 2 → 3 → 4 → 5 → 7 → (Mae: 6) → 8.
