# Audio-Feedback numpy Real-Time Synth Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the signalflow synth with a pure-numpy/scipy DSP engine that renders the 27-sound palette offline and can be shaped by ear in real time (MIDI + hot-reload) and in Jupyter.

**Architecture:** `dsp.py` holds pure numpy primitives (oscillators, envelopes, reverb, an `@njit` state-variable filter, pink noise). `voices.py` builds the three voices (bell/sine/swoosh) from those primitives and assembles a Sound's note-map into a mono signal — replacing `synth.py` + `synthmod.py` with byte-for-byte-equivalent logic. `generate.py` (offline batch), `live.py` (real-time sounddevice callback + polyphonic mixer + python-rtmidi + importlib hot-reload), and `design.ipynb` (Jupyter audition) are the three by-ear surfaces. signalflow is dropped.

**Tech Stack:** Python 3.12 (uv-managed venv), numpy, scipy, numba (`@njit`), sounddevice (PortAudio), python-rtmidi, jupyter/ipython, matplotlib. Kept: parsimonious (mini-notation grammar).

## Global Constraints

- **Work on branch `feat/audio-feedback-sound-redesign`** (currently at `32865f3`). Do NOT touch `feat/audio-feedback-dawdreamer` (preserves the DawDreamer engine) or `main`.
- **Working directory for all commands:** `plugins/audio-feedback` (the justfile lives here). The venv python is `sound-theme/default/.venv/bin/python`; source is `sound-theme/default/src/`.
- **Sample rate `SR = 44100`** comes from `theme.SR` — never hard-code 44100 in a voice; import it.
- **`Signal = NDArray[np.float32]`** — every voice/primitive returns float32.
- **tuning.py is the by-ear knob surface** — voices read every magic number from `tuning.py`, never inline literals. Do not change any value in `tuning.py`; only read from it.
- **Logic parity with the current synth.** The offline palette must stay equivalent to the signalflow output: reproduce `synth.py`'s bell partial loop, envelope math, note-map assembly, reverb/tail-fade, and subagent accent exactly, swapping only signalflow nodes for numpy. The reference math is in `src/synth.py` and `src/synthmod.py` at this commit.
- **The shipped plugin is unaffected** — it plays committed WAVs via bash. All of this is the dev-time generator.
- **British/Irish English; no emoji or non-ASCII in code/comments; ASCII tags** ([OK]/[WARN]) if needed.

---

## File Structure

- `src/dsp.py` (**create**) — DSP primitives. Replaces `synthmod.py`'s primitive layer.
- `src/voices.py` (**create**) — bell/sine/swoosh voices + `render_event` + `render_subagent_accent` + `VOICES` registry. Replaces `synth.py`.
- `src/live.py` (**create**) — real-time engine (Mixer, callback, MIDI, hot-reload).
- `src/build_notebook.py` (**create**) — builds `design.ipynb` via nbformat (regenerable).
- `src/design.ipynb` (**create**, generated) — Jupyter by-ear audition.
- `src/generate.py` (**modify**) — swap `synth` -> `voices`; update WATCH_FILES + PEP723 header.
- `src/synth.py`, `src/synthmod.py` (**delete** in Task 4).
- `pyproject.toml` (**modify**) — deps: +numba/sounddevice/python-rtmidi/jupyter/ipython/matplotlib; -signalflow (Task 4).
- `justfile` (**modify**) — `live`/`notebook` recipes; fix `test` recipe; update `venv` comment.
- `tests/conftest.py`, `tests/test_dsp.py`, `tests/test_voices.py`, `tests/test_generate.py`, `tests/test_live.py` (**create**).
- `DESIGN-NOTES.md` / `README` prereqs (**modify** in Task 7).

---

## Task 1: Dependency bootstrap

Add the new runtime deps alongside signalflow (kept until Task 4 deletes `synth.py`), sync the venv, and prove every new library imports. `numba` must land before Task 2 (dsp uses `@njit`).

**Files:**
- Modify: `sound-theme/default/pyproject.toml`

**Interfaces:**
- Produces: a synced venv where `numpy, scipy, numba, sounddevice, rtmidi, IPython` all import.

- [ ] **Step 1: Add dependencies to pyproject.toml**

Replace the `dependencies` line and the `[dependency-groups]` block:

```toml
dependencies = ["signalflow==0.5.3", "numpy", "scipy", "parsimonious", "numba", "sounddevice", "python-rtmidi"]

[dependency-groups]
dev = ["pytest", "flask", "jupyter", "ipython", "matplotlib", "nbconvert", "nbformat"]
```

(signalflow stays for now so `synth.py` still imports; Task 4 removes it.)

- [ ] **Step 2: Sync the venv**

Run (from `plugins/audio-feedback`):
```bash
cd sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uv sync
```
Expected: resolves and installs numba, sounddevice, python-rtmidi, jupyter, ipython, matplotlib, nbconvert, nbformat. If `python-rtmidi` fails to build, it needs ALSA/JACK headers — note the error and report; do not silently drop it.

- [ ] **Step 3: Import smoke check**

Run:
```bash
sound-theme/default/.venv/bin/python -c "import numpy, scipy, numba, sounddevice, rtmidi, IPython; print('[OK] imports')"
```
Expected: `[OK] imports`. A `sounddevice`/PortAudio warning about no audio device is fine (import still succeeds); an ImportError is not.

- [ ] **Step 4: Commit**

```bash
git add sound-theme/default/pyproject.toml sound-theme/default/uv.lock
git commit -m "build(audio-feedback): add numpy-realtime deps (numba/sounddevice/rtmidi/jupyter)"
```

---

## Task 2: `dsp.py` — DSP primitive library

Pure numpy/scipy primitives, unit-tested. Every function returns `float32`. This is the lean set the three voices actually use — no speculative primitives.

**Files:**
- Create: `sound-theme/default/src/dsp.py`
- Create: `sound-theme/default/tests/conftest.py`
- Create: `sound-theme/default/tests/test_dsp.py`

**Interfaces:**
- Produces:
  - `Signal = NDArray[np.float32]`
  - `midi_hz(m: float) -> float`
  - `oscillator(freq: float, n: int, waveform: str = "sine", width: float = 0.5) -> Signal`
  - `pluck(n: int, attack: float, tau_fast: float, tau_slow: float, sustain: float) -> Signal`
  - `ar(n: int, attack: float, release: float, curve: float = 1.0) -> Signal`
  - `tremolo(sig: Signal, rate: float, depth: float) -> Signal`
  - `reverb(sig: Signal, decay_s: float, wet: float, damp: float = 4.0, predelay_s: float = 0.0, extend: bool = True) -> Signal`
  - `pink_noise(n: int, seed: int) -> Signal`
  - `svf_bandpass(sig: Signal, cutoff: Signal, q: float) -> Signal`

- [ ] **Step 1: Write the failing tests**

Create `tests/conftest.py` (puts `src/` on the import path for all tests):
```python
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
```

Create `tests/test_dsp.py`:
```python
import numpy as np

import dsp
from theme import SR


def test_midi_hz_a4():
    assert abs(dsp.midi_hz(69) - 440.0) < 1e-6
    assert abs(dsp.midi_hz(81) - 880.0) < 1e-6


def test_oscillator_frequency_via_fft():
    n = SR
    sig = dsp.oscillator(440.0, n, "sine")
    assert sig.dtype == np.float32
    mag = np.abs(np.fft.rfft(sig.astype(np.float64)))
    peak_hz = np.fft.rfftfreq(n, 1 / SR)[np.argmax(mag)]
    assert abs(peak_hz - 440.0) < 2.0


def test_oscillator_unknown_waveform():
    try:
        dsp.oscillator(440.0, 10, "triangle")
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_pluck_shape():
    env = dsp.pluck(SR, attack=0.01, tau_fast=0.02, tau_slow=0.2, sustain=0.1)
    assert env.dtype == np.float32
    assert env[0] < env[int(SR * 0.01)]           # rises through the attack
    assert env[int(SR * 0.01)] > env[int(SR * 0.5)]  # then decays
    assert np.all(env >= 0)


def test_ar_envelope():
    n = int(SR * 0.5)
    env = dsp.ar(n, attack=0.1, release=0.2, curve=1.0)
    peak_i = int(SR * 0.1)
    assert abs(env[peak_i] - 1.0) < 0.05           # peaks at end of attack
    assert env[0] < 0.1                            # starts near zero
    assert env[int(SR * 0.31)] < 0.02              # silent after attack+release
    assert env.dtype == np.float32


def test_pink_noise_deterministic():
    a = dsp.pink_noise(1000, seed=7)
    b = dsp.pink_noise(1000, seed=7)
    c = dsp.pink_noise(1000, seed=8)
    assert np.array_equal(a, b)
    assert not np.array_equal(a, c)
    assert a.dtype == np.float32


def test_svf_bandpass_passes_its_band():
    n = SR
    white = np.random.RandomState(0).randn(n).astype(np.float32)
    cutoff = np.full(n, 1000.0, dtype=np.float32)
    out = dsp.svf_bandpass(white, cutoff, q=0.7)
    assert out.dtype == np.float32
    mag = np.abs(np.fft.rfft(out.astype(np.float64)))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    in_band = mag[(freqs > 700) & (freqs < 1400)].mean()
    out_band = mag[(freqs > 5000) & (freqs < 8000)].mean()
    assert in_band > out_band * 3


def test_reverb_extend_lengthens():
    sig = dsp.oscillator(440.0, int(SR * 0.1), "sine")
    wet = dsp.reverb(sig, decay_s=0.3, wet=0.2, extend=True)
    assert len(wet) > len(sig)
    dry = dsp.reverb(sig, decay_s=0.3, wet=0.0, extend=True)  # wet=0 -> no-op
    assert np.array_equal(dry, sig)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_dsp.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'dsp'`.

- [ ] **Step 3: Write `dsp.py`**

Create `sound-theme/default/src/dsp.py`:
```python
"""DSP primitive library: oscillators, envelopes, effects, helpers.

Pure numpy/scipy functions on float32 arrays at theme.SR -- the building blocks
for voices.py. Replaces the signalflow node graph (SineOscillator, ASREnvelope,
SVFilter, PinkNoise) with direct math: exact, unit-testable, and cheap enough to
call inside a real-time audio callback.
"""
import numpy as np
from numba import njit
from numpy.typing import NDArray
from scipy.signal import fftconvolve

from theme import SR

Signal = NDArray[np.float32]


def midi_hz(m: float) -> float:
    """MIDI note number -> frequency in Hz (A4 = 69 = 440)."""
    return 440.0 * 2 ** ((m - 69) / 12)


def oscillator(freq: float, n: int, waveform: str = "sine", width: float = 0.5) -> Signal:
    """`n` samples of `waveform` at `freq`. sine | saw | square | pulse
    (pulse uses `width` as duty cycle 0..1). Naive (not band-limited)."""
    ph = freq * np.arange(n) / SR
    if waveform == "sine":
        w = np.sin(2 * np.pi * ph)
    elif waveform == "saw":
        w = 2 * (ph % 1) - 1
    elif waveform == "square":
        w = np.sign(np.sin(2 * np.pi * ph))
    elif waveform == "pulse":
        w = np.where((ph % 1) < width, 1.0, -1.0)
    else:
        raise ValueError(f"unknown waveform: {waveform!r}")
    return w.astype("float32")


def pluck(n: int, attack: float, tau_fast: float, tau_slow: float, sustain: float) -> Signal:
    """A struck/plucked amplitude curve: a linear attack, then a DOUBLE
    exponential decay -- a fast component (`tau_fast`) into a slow tail of
    weight `sustain` (`tau_slow`). One-shot: no gate/hold. (was
    synthmod.pluck_envelope)."""
    t = np.arange(n) / SR
    atk = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    decay = (1.0 - sustain) * np.exp(-t / tau_fast) + sustain * np.exp(-t / tau_slow)
    return (atk * decay).astype("float32")


def ar(n: int, attack: float, release: float, curve: float = 1.0) -> Signal:
    """Attack-release envelope over `n` samples: rise 0..1 over `attack` s, then
    fall 1..0 over `release` s, each shaped by `curve` (1 = linear; >1 = a fast
    initial drop into a long quiet tail, like a struck bell); zero afterward.
    Replaces signalflow ASREnvelope(attack, sustain=0, release, curve)."""
    a = max(int(SR * attack), 1)
    r = max(int(SR * release), 1)
    env = np.zeros(n, dtype="float64")
    ia = min(a, n)
    env[:ia] = (np.arange(ia) / a) ** curve
    if a < n:
        ir = min(r, n - a)
        env[a:a + ir] = (1.0 - np.arange(ir) / r) ** curve
    return env.astype("float32")


def tremolo(sig: Signal, rate: float, depth: float) -> Signal:
    """Amplitude LFO (sine). `depth` 0..1 = fraction modulated; no-op when depth
    or rate <= 0. (was synthmod.tremolo)."""
    if depth <= 0 or rate <= 0:
        return sig
    t = np.arange(len(sig)) / SR
    lfo = 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))
    return (sig * lfo).astype("float32")


def reverb(sig: Signal, decay_s: float, wet: float, damp: float = 4.0,
           predelay_s: float = 0.0, extend: bool = True) -> Signal:
    """Diffuse exponential-noise reverb. `predelay_s` gaps the IR (0 = smooth
    bloom, no slapback double). `extend` appends the IR length so the tail rings
    out (sine voice) rather than being cut (bell/swoosh postprocess set
    extend=False -- their buffers are pre-padded). `wet` 0..1; 0 or decay<=0 =
    no-op. (unifies synthmod.reverb + synth.postprocess reverb)."""
    if wet <= 0 or decay_s <= 0:
        return sig.astype("float32")
    n = int(SR * decay_s)
    ir = np.random.RandomState(0).randn(n) * np.exp(-np.linspace(0, damp, n))
    if predelay_s > 0:
        ir = np.concatenate([np.zeros(int(SR * predelay_s)), ir])
    out = np.concatenate([sig, np.zeros(n, dtype=sig.dtype)]) if extend else sig.astype("float32")
    wet_sig = fftconvolve(out, ir)[:len(out)]
    mixed = out * (1.0 - wet) + wet_sig / (np.max(np.abs(wet_sig)) + 1e-9) * wet
    return mixed.astype("float32")


def pink_noise(n: int, seed: int) -> Signal:
    """1/f (pink) noise, deterministic per `seed`, via FFT spectral shaping.
    Replaces signalflow PinkNoise + its per-node set_seed."""
    rng = np.random.RandomState(seed)
    spectrum = np.fft.rfft(rng.randn(n))
    freqs = np.fft.rfftfreq(n)
    scale = np.ones_like(freqs)
    scale[1:] = 1.0 / np.sqrt(freqs[1:])
    pink = np.fft.irfft(spectrum * scale, n=n)
    pink /= (np.max(np.abs(pink)) + 1e-9)
    return pink.astype("float32")


@njit(cache=True)
def _svf_core(x: NDArray[np.float64], cutoff: NDArray[np.float64], q: float) -> NDArray[np.float64]:
    n = len(x)
    out = np.zeros(n)
    low = 0.0
    band = 0.0
    for i in range(n):
        f = 2.0 * np.sin(np.pi * cutoff[i] / SR)
        high = x[i] - low - q * band
        band = f * high + band
        low = f * band + low
        out[i] = band
    return out


def svf_bandpass(sig: Signal, cutoff: Signal, q: float) -> Signal:
    """Chamberlin state-variable band-pass with a per-sample `cutoff` (Hz) sweep.
    `q` is the damping coefficient (higher = wider/less resonant). Replaces
    signalflow SVFilter(..., BAND_PASS, cutoff, q). The per-sample recurrence is
    JIT-compiled (numba) -- a plain Python loop is ~20x slower."""
    out = _svf_core(sig.astype(np.float64), cutoff.astype(np.float64), float(q))
    return out.astype("float32")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_dsp.py -q`
Expected: PASS (first run compiles the numba kernel — a one-off delay).

- [ ] **Step 5: Commit**

```bash
git add sound-theme/default/src/dsp.py sound-theme/default/tests/conftest.py sound-theme/default/tests/test_dsp.py
git commit -m "feat(audio-feedback): dsp.py numpy primitives (osc/env/reverb/svf/pink)"
```

---

## Task 3: `voices.py` — the three voices

Reproduce `synth.py`'s bell/sine/swoosh logic in numpy, reading knobs from `tuning.py`. `render_event` and `render_subagent_accent` keep their exact assembly logic. `synth.py`/`synthmod.py` still exist and are untouched here (Task 4 deletes them).

**Files:**
- Create: `sound-theme/default/src/voices.py`
- Create: `sound-theme/default/tests/test_voices.py`

**Interfaces:**
- Consumes: `dsp.*`, `tuning.*`, `theme.SR`, `variants.Sound`.
- Produces:
  - `bell(freq, dur=tuning.BELL_DUR, brightness=1.0, decay_scale=1.0, detune_cents=0.0, punch=1.0, layer=None, air_db=None, attack=tuning.ATTACK_S, curve=tuning.CURVE) -> Signal`
  - `sine(freq, attack=tuning.SINE_ATTACK_S) -> Signal`
  - `swoosh(sound: type[Sound]) -> Signal`
  - `postprocess(sig: Signal) -> Signal`
  - `render_event(sound: type[Sound]) -> Signal`
  - `render_subagent_accent() -> Signal`
  - `VOICES: dict[str, callable]` = `{"bell": bell, "sine": sine}` (pitched per-note voices for live play)
  - `Signal` (re-exported from dsp)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_voices.py`:
```python
import numpy as np

import voices
from theme import SR
from variants import SOUNDS


def test_bell_has_fundamental():
    freq = 440.0
    sig = voices.bell(freq)
    assert sig.dtype == np.float32
    assert len(sig) > 0
    mag = np.abs(np.fft.rfft(sig.astype(np.float64)))
    freqs = np.fft.rfftfreq(len(sig), 1 / SR)
    peak_hz = freqs[np.argmax(mag)]
    assert abs(peak_hz - freq) < 5.0                 # fundamental dominates


def test_sine_voice_nonempty_and_finite():
    sig = voices.sine(660.0)
    assert sig.dtype == np.float32
    assert len(sig) > 0
    assert np.all(np.isfinite(sig))


def test_swoosh_up_down_differ():
    up = voices.swoosh(SOUNDS["pre-tool-use-network"])    # dir "up"
    down = voices.swoosh(SOUNDS["post-tool-use-network"])  # dir "down"
    assert up.dtype == np.float32
    assert len(up) > 0 and len(down) > 0
    assert not np.array_equal(up, down)


def test_render_event_bell_phrase_assembles():
    sig = voices.render_event(SOUNDS["session-start"])
    assert sig.dtype == np.float32
    assert len(sig) > int(SR * 0.5)                  # a full-bar phrase
    assert np.all(np.isfinite(sig))
    assert float(np.max(np.abs(sig))) > 0


def test_render_event_dispatches_each_voice():
    for name in ("stop", "user-prompt-submit", "pre-tool-use-network"):
        sig = voices.render_event(SOUNDS[name])
        assert len(sig) > 0 and np.all(np.isfinite(sig))


def test_subagent_accent_is_quiet():
    sig = voices.render_subagent_accent()
    assert sig.dtype == np.float32
    assert len(sig) > 0
    assert float(np.max(np.abs(sig))) < 1.0          # sits under the palette


def test_voices_registry():
    assert set(voices.VOICES) == {"bell", "sine"}
    assert callable(voices.VOICES["bell"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_voices.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'voices'`.

- [ ] **Step 3: Write `voices.py`**

Create `sound-theme/default/src/voices.py`:
```python
"""The synth voices: bell, sine, swoosh -- built from dsp.py primitives.

Each voice renders one note (or, for swoosh, one unpitched gesture) to a mono
float32 signal. `render_event` assembles a variants.Sound's note-map into the
finished signal; `VOICES` maps a Sound.voice string to a pitched per-note
callable for real-time play (live.py). This replaces the signalflow synth.py
with equivalent numpy math -- edit numbers in tuning.py for by-ear shaping,
edit here to change synthesis structure.
"""
import numpy as np

import dsp
import tuning
from dsp import Signal, midi_hz
from theme import SR
from variants import Sound


def bell(freq: float, dur: float = tuning.BELL_DUR, brightness: float = 1.0,
         decay_scale: float = 1.0, detune_cents: float = 0.0, punch: float = 1.0,
         layer: str | None = None, air_db: float | None = None,
         attack: float = tuning.ATTACK_S, curve: float = tuning.CURVE) -> Signal:
    """One struck inharmonic bell -> mono float32. Sums tuning.PARTIALS (each an
    attack-release sine), plus optional shimmer/sub layer and air partial. The
    buffer spans attack + dur*max(decay_scale,1) + release pad so the whole decay
    lands on zero (no click)."""
    full = attack + dur * max(decay_scale, 1.0) + tuning.BELL_RELEASE_PAD_S
    n = int(SR * full)
    out = np.zeros(n, dtype="float32")
    for i, (ratio, amp) in enumerate(tuning.PARTIALS):
        a = amp * (brightness ** i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        out += dsp.oscillator(freq * ratio * det, n) * dsp.ar(n, attack, dur * decay_scale, curve) * a
    if layer == "shimmer":
        r, ds, lvl = tuning.SHIMMER
        out += dsp.oscillator(freq * r, n) * dsp.ar(n, attack, dur * ds, curve) * lvl
    elif layer == "sub":
        r, ds, lvl = tuning.SUB
        out += dsp.oscillator(freq * r, n) * dsp.ar(n, attack, dur * ds, curve) * lvl
    if air_db is not None:
        air_amp = 10 ** (air_db / 20)
        out += dsp.oscillator(freq * tuning.AIR_RATIO, n) * dsp.ar(n, attack, dur * tuning.AIR_DUR_SCALE, curve) * air_amp
    return out


def sine(freq: float, attack: float = tuning.SINE_ATTACK_S) -> Signal:
    """The 'sine' voice: a pure sine with a double-exponential pluck decay, a
    gentle tremolo, and light reverb (reverse-engineered from the old blips)."""
    n = int(SR * tuning.SINE_LENGTH_S)
    sig = dsp.oscillator(freq, n) * dsp.pluck(
        n, attack, tuning.SINE_TAU_FAST, tuning.SINE_TAU_SLOW, tuning.SINE_SUSTAIN)
    sig = dsp.tremolo(sig, tuning.SINE_TREMOLO_HZ, tuning.SINE_TREMOLO_DEPTH)
    return dsp.reverb(sig, tuning.SINE_REVERB_DECAY_S, tuning.SINE_REVERB_WET,
                      tuning.SINE_REVERB_DAMP, extend=True)


def postprocess(sig: Signal) -> Signal:
    """Reverb + tail fade for the bell/swoosh voices. Loudness is handled once
    across the palette in loudness.py. Does not extend -- callers pre-pad for the
    reverb tail; the tail fade then guards the final cut."""
    sig = dsp.reverb(sig, tuning.REVERB_DECAY_S, tuning.REVERB_WET, tuning.REVERB_DAMP,
                     predelay_s=tuning.REVERB_PREDELAY_S, extend=False)
    f = int(SR * tuning.TAIL_FADE_S)
    if len(sig) > f:
        sig = sig.copy()
        sig[-f:] *= np.linspace(1, 0, f)
    return sig


def swoosh(sound: type[Sound]) -> Signal:
    """Filtered-noise sweep -- a paper plane thrown (send) or arriving (receive).
    Not pitched: ignores the note-map/accent knobs, reads sound.swoosh_dir. Pink
    noise through a band-pass whose centre sweeps lo->hi (up) or hi->lo (down)."""
    dur = tuning.SWOOSH_DUR
    lo, hi = tuning.SWOOSH_FREQ_LO, tuning.SWOOSH_FREQ_HI
    if sound.swoosh_dir == "down":
        lo, hi = hi, lo
    n = int(SR * dur)
    cutoff = np.linspace(lo, hi, n).astype("float32")
    filt = dsp.svf_bandpass(dsp.pink_noise(n, tuning.SWOOSH_SEED), cutoff, tuning.SWOOSH_Q)
    release = max(dur - tuning.SWOOSH_ATTACK, 0.01)
    env = dsp.ar(n, tuning.SWOOSH_ATTACK, release)
    patch = filt * env * tuning.SWOOSH_LEVEL
    # pad with silence for the reverb tail, then postprocess (no-extend)
    padded = np.concatenate([patch, np.zeros(int(SR * tuning.REVERB_DECAY_S), dtype="float32")])
    return postprocess(padded)


VOICES = {"bell": bell, "sine": sine}   # pitched per-note voices (live play)


def render_event(sound: type[Sound]) -> Signal:
    """Render a variants.Sound, dispatching on its voice. 'bell' uses the
    note-map + accents; 'sine' is the pluck voice; 'swoosh' is the noise sweep."""
    if sound.voice == "swoosh":
        return swoosh(sound)
    attack = sound.attack if sound.attack is not None else tuning.ATTACK_S
    curve = sound.curve if sound.curve is not None else tuning.CURVE
    events = sound.notes                       # [(Fraction, midi, Fraction)]
    cyc = sound.cycle_sec
    notes: list[Signal] = []
    for _begin, m, dur_f in events:
        dur_sec = float(dur_f) * cyc
        dscale = max(sound.decay_scale, dur_sec / tuning.BELL_DUR)
        freq = midi_hz(m + sound.transpose)
        if sound.voice == "sine":
            sine_attack = sound.attack if sound.attack is not None else tuning.SINE_ATTACK_S
            notes.append(sine(freq, attack=sine_attack))
        else:
            notes.append(bell(freq, decay_scale=dscale, attack=attack, curve=curve,
                              brightness=sound.brightness, detune_cents=sound.detune_cents,
                              punch=sound.punch, layer=sound.layer, air_db=sound.air_db))
    onsets = [int(SR * float(begin) * cyc) for begin, _m, _d in events]
    total = max(o + len(x) for o, x in zip(onsets, notes))
    out = np.zeros(total, dtype="float32")
    for x, o in zip(notes, onsets):
        out[o:o + len(x)] += x
    if sound.voice == "sine":
        f = int(SR * tuning.TAIL_FADE_S)
        if len(out) > f:
            out[-f:] *= np.linspace(1, 0, f)
        return out
    return postprocess(out)


def render_subagent_accent() -> Signal:
    """The bare quiet shimmer mixed over subagent tool sounds at runtime."""
    freq = midi_hz(tuning.SUBAGENT_NOTE)
    n = int(SR * tuning.SUBAGENT_RENDER_S)
    out = np.zeros(n, dtype="float32")
    for ratio, release, level in tuning.SUBAGENT_PARTIALS:
        out += dsp.oscillator(freq * ratio, n) * dsp.ar(n, tuning.ATTACK_S, release) * level
    out = postprocess(out)
    return out * 10 ** (tuning.SUBAGENT_OFFSET_DB / 20)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_voices.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sound-theme/default/src/voices.py sound-theme/default/tests/test_voices.py
git commit -m "feat(audio-feedback): voices.py numpy bell/sine/swoosh (parity with synth.py)"
```

---

## Task 4: Rewire `generate.py` to voices; delete signalflow

Point the offline generator at `voices`, delete `synth.py`/`synthmod.py`, and remove signalflow from the deps and the PEP723 header. After this task the palette renders with zero signalflow.

**Files:**
- Modify: `sound-theme/default/src/generate.py`
- Delete: `sound-theme/default/src/synth.py`, `sound-theme/default/src/synthmod.py`
- Modify: `sound-theme/default/pyproject.toml`
- Create: `sound-theme/default/tests/test_generate.py`

**Interfaces:**
- Consumes: `voices.render_event`, `voices.render_subagent_accent`, `dsp.Signal`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_generate.py`:
```python
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
import generate  # noqa: E402
import theme      # noqa: E402


def test_serve_dir_writes_full_palette(tmp_path):
    out = str(tmp_path / "snd")
    generate.cmd_serve_dir(out)
    wavs = [f for f in os.listdir(out) if f.endswith(".wav")]
    assert len(wavs) == 28                          # 27 palette + subagent-accent
    assert "subagent-accent.wav" in wavs
    assert os.path.exists(os.path.join(out, "palette.json"))
    for name in theme.all_targets():
        assert os.path.exists(os.path.join(out, name + ".wav"))


def test_generate_module_has_no_signalflow():
    import importlib
    src = importlib.util.find_spec("generate").origin
    with open(src) as f:
        assert "signalflow" not in f.read().lower()
    with open(importlib.util.find_spec("voices").origin) as f:
        assert "signalflow" not in f.read().lower()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_generate.py -q`
Expected: FAIL — `generate` still imports `synth` (which imports signalflow), and the palette-render path uses `synth.*`. (`test_generate_module_has_no_signalflow` also fails until Step 4.)

- [ ] **Step 3: Rewire `generate.py`**

In `sound-theme/default/src/generate.py`:

Replace the PEP723 header dependencies line (lines 2-3) with:
```python
# dependencies = ["numpy", "scipy", "parsimonious", "numba"]
```

Replace the import (line 24) `import synth` with:
```python
import voices
import dsp
```

Replace every `synth.` reference:
- `def _render_events(names: list[str] | None = None) -> dict[str, synth.Signal]:` -> `-> dict[str, dsp.Signal]:`
- `sigs: dict[str, synth.Signal] = {}` -> `sigs: dict[str, dsp.Signal] = {}`
- `sigs[name] = synth.render_event(sound)` -> `sigs[name] = voices.render_event(sound)`
- in `cmd_serve_dir`: `synth.render_subagent_accent()` -> `voices.render_subagent_accent()`
- in `cmd_generate`: `synth.render_subagent_accent()` -> `voices.render_subagent_accent()`
- in `cmd_preview`: `synth.render_event(sound)` -> `voices.render_event(sound)` and `synth.render_subagent_accent()` -> `voices.render_subagent_accent()`

Update `WATCH_FILES` (line 29):
```python
WATCH_FILES = ["tuning.py", "voices.py", "dsp.py", "loudness.py", "theme.py", "variants.py"]
```

- [ ] **Step 4: Delete signalflow files + dep**

```bash
git rm sound-theme/default/src/synth.py sound-theme/default/src/synthmod.py
```

In `sound-theme/default/pyproject.toml`:
- `dependencies` line -> remove `"signalflow==0.5.3"` and the `requires-python` upper pin comment about signalflow:
```toml
dependencies = ["numpy", "scipy", "parsimonious", "numba", "sounddevice", "python-rtmidi"]
```
- Change `requires-python = ">=3.12,<3.13"   # signalflow ships a cp312 wheel; no 3.13/3.14 yet` to:
```toml
requires-python = ">=3.12"
```
- Update the `description`: `"numpy real-time synth generator for the audio-feedback default sound theme (dev-time only)"`.
- In the `[tool.basedpyright]` comment block, drop the signalflow sentence; leave the numpy/scipy note.

Then re-sync:
```bash
cd sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uv sync && cd -
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_generate.py -q`
Expected: PASS (28 wavs, no signalflow strings). First run recompiles the numba kernel.

- [ ] **Step 6: Full render smoke check**

Run: `sound-theme/default/.venv/bin/python src/generate.py --only stop && echo "[OK] rendered stop.wav"`
Expected: `wrote stop.wav` ... `[OK] rendered stop.wav`, and `sound-theme/default/sounds/stop.wav` exists.

- [ ] **Step 7: Commit**

```bash
git add -A sound-theme/default/src/generate.py sound-theme/default/pyproject.toml sound-theme/default/uv.lock sound-theme/default/tests/test_generate.py sound-theme/default/sounds
git commit -m "refactor(audio-feedback): generate.py -> voices; drop signalflow"
```

---

## Task 5: `live.py` — real-time engine

A polyphonic mixer that pre-renders each note on note-on (sample-bank), a sounddevice callback that only sums pre-rendered buffers, a python-rtmidi input thread, and an importlib hot-reload watcher. Percussive/decaying voices self-terminate, so note-off is a no-op (buffers drop when consumed). Audio-device + real MIDI playback is a manual smoke check; the mixer/reload logic is unit-tested headless.

**Files:**
- Create: `sound-theme/default/src/live.py`
- Create: `sound-theme/default/tests/test_live.py`

**Interfaces:**
- Consumes: `voices.VOICES`, `dsp.midi_hz`, `theme.SR`.
- Produces:
  - `class Mixer` with `note_on(midi: int, voice: str = "bell") -> None`, `swap_voices(voices: dict) -> None`, `render_block(frames: int) -> NDArray[np.float32]` (shape `(frames, 2)`).
  - `make_callback(mixer: Mixer) -> callable`
  - `main(argv: list[str] | None = None) -> int`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_live.py`:
```python
import numpy as np

import live


def _const_voices(value=1.0, n=100):
    return {"bell": lambda freq, value=value, n=n: np.full(n, value, dtype=np.float32)}


def test_mixer_render_block_shape_and_sum():
    m = live.Mixer(_const_voices(1.0, 100))
    m.note_on(60)
    block = m.render_block(64)
    assert block.shape == (64, 2)
    assert block.dtype == np.float32
    assert np.allclose(block, 1.0)                  # both channels get the buffer


def test_mixer_polyphony_sums_voices():
    m = live.Mixer(_const_voices(1.0, 100))
    m.note_on(60)
    m.note_on(64)
    block = m.render_block(10)
    assert np.allclose(block, 2.0)                  # two notes stack


def test_mixer_drops_finished_buffers():
    m = live.Mixer(_const_voices(1.0, 100))
    m.note_on(60)
    m.render_block(100)                             # consume the whole buffer
    block = m.render_block(10)
    assert np.allclose(block, 0.0)                  # nothing left


def test_mixer_unknown_voice_is_ignored():
    m = live.Mixer(_const_voices())
    m.note_on(60, voice="nope")                     # no such voice -> no error, no note
    assert np.allclose(m.render_block(10), 0.0)


def test_callback_clips_and_fills():
    m = live.Mixer(_const_voices(5.0, 100))         # hot buffer -> must clip
    m.note_on(60)
    cb = live.make_callback(m)
    out = np.zeros((32, 2), dtype=np.float32)
    cb(out, 32, None, None)
    assert out.max() <= 1.0 and out.min() >= -1.0


def test_swap_voices_replaces_registry():
    m = live.Mixer(_const_voices(1.0, 10))
    m.swap_voices(_const_voices(3.0, 10))
    m.note_on(60)
    assert np.allclose(m.render_block(5), 3.0)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_live.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'live'`.

- [ ] **Step 3: Write `live.py`**

Create `sound-theme/default/src/live.py`:
```python
"""Real-time synth: play a MIDI keyboard, hear the voices live, and hot-reload
the DSP code as you edit it. A sounddevice OutputStream callback sums PRE-RENDERED
note buffers (a sample-bank -- Isaac Roberts, 'Drop the DAW'); note-on renders a
note into numpy (~ms) and hands the buffer to the mixer, so the audio thread only
copies and adds. Percussive/decaying voices self-terminate, so note-off is a
no-op. Edit voices.py / dsp.py / tuning.py and the watcher reloads them.

    just live            # play a connected MIDI input (falls back to a demo loop)
"""
import importlib
import os
import sys
import threading
import time

import numpy as np

import dsp
import tuning
import voices
from dsp import midi_hz
from theme import SR

BLOCKSIZE = 256
WATCH = ["dsp.py", "voices.py", "tuning.py"]
DEMO_NOTES = [60, 64, 67, 72]   # a C-major arpeggio for the no-MIDI demo loop


class Mixer:
    """Polyphonic sample-bank mixer. note_on pre-renders a note buffer; each
    render_block sums the active buffers and drops any that have been consumed.
    Thread-safe: the audio callback and the MIDI/reload threads share `active`."""

    def __init__(self, voice_registry: dict) -> None:
        self._voices = dict(voice_registry)
        self._active: list[list] = []               # [buffer, pos] pairs
        self._lock = threading.Lock()

    def swap_voices(self, voice_registry: dict) -> None:
        with self._lock:
            self._voices = dict(voice_registry)

    def note_on(self, midi: int, voice: str = "bell") -> None:
        with self._lock:
            fn = self._voices.get(voice)
        if fn is None:
            return
        buf = np.ascontiguousarray(fn(midi_hz(midi)), dtype=np.float32)
        with self._lock:
            self._active.append([buf, 0])

    def render_block(self, frames: int) -> np.ndarray:
        out = np.zeros((frames, 2), dtype=np.float32)
        with self._lock:
            still = []
            for item in self._active:
                buf, pos = item
                take = min(frames, len(buf) - pos)
                if take > 0:
                    out[:take, 0] += buf[pos:pos + take]
                    out[:take, 1] += buf[pos:pos + take]
                    item[1] = pos + take
                if item[1] < len(buf):
                    still.append(item)
            self._active = still
        return out


def make_callback(mixer: Mixer):
    """PortAudio callback: fill `outdata` (frames x 2) from the mixer, clipped to
    [-1, 1] so a hot buffer can't wrap. Allocation-free copy into the device buffer."""
    def callback(outdata, frames, time_info, status):
        block = mixer.render_block(frames)
        np.clip(block, -1.0, 1.0, out=block)
        outdata[:] = block
    return callback


def _mtimes() -> dict:
    here = os.path.dirname(os.path.abspath(__file__))
    out = {}
    for f in WATCH:
        try:
            out[f] = os.path.getmtime(os.path.join(here, f))
        except OSError:
            out[f] = 0
    return out


def _reload_loop(mixer: Mixer, stop: threading.Event) -> None:
    last = _mtimes()
    while not stop.is_set():
        time.sleep(0.4)
        now = _mtimes()
        if now != last:
            last = now
            try:
                importlib.reload(dsp)
                importlib.reload(tuning)
                importlib.reload(voices)
                mixer.swap_voices(voices.VOICES)
                print("[OK] reloaded voices")
            except Exception as exc:                # a syntax error must not kill audio
                print(f"[WARN] reload failed (keeping current): {exc}")


def _midi_loop(mixer: Mixer, stop: threading.Event) -> bool:
    """Open the first MIDI input and feed note-on to the mixer. Returns True if a
    port was opened, False if none is available (caller starts the demo loop)."""
    try:
        import rtmidi
    except ImportError:
        return False
    midi_in = rtmidi.MidiIn()
    ports = midi_in.get_ports()
    if not ports:
        return False
    midi_in.open_port(0)
    print(f"[OK] MIDI: {ports[0]}")
    while not stop.is_set():
        msg = midi_in.get_message()
        if msg:
            data = msg[0]
            if len(data) >= 3 and (data[0] & 0xF0) == 0x90 and data[2] > 0:
                mixer.note_on(data[1])
        else:
            time.sleep(0.001)
    return True


def _demo_loop(mixer: Mixer, stop: threading.Event) -> None:
    print("[INFO] no MIDI input -- playing a demo arpeggio (edit voices.py to hear reloads)")
    i = 0
    while not stop.is_set():
        mixer.note_on(DEMO_NOTES[i % len(DEMO_NOTES)])
        i += 1
        time.sleep(0.5)


def main(argv: list[str] | None = None) -> int:
    import sounddevice as sd
    mixer = Mixer(voices.VOICES)
    stop = threading.Event()
    threading.Thread(target=_reload_loop, args=(mixer, stop), daemon=True).start()

    def midi_or_demo():
        if not _midi_loop(mixer, stop):
            _demo_loop(mixer, stop)
    threading.Thread(target=midi_or_demo, daemon=True).start()

    with sd.OutputStream(samplerate=SR, channels=2, blocksize=BLOCKSIZE,
                         dtype="float32", callback=make_callback(mixer)):
        print("live: play MIDI (or hear the demo). Ctrl-C to stop.")
        try:
            while True:
                time.sleep(0.1)
        except KeyboardInterrupt:
            stop.set()
            print("\nlive: stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_live.py -q`
Expected: PASS.

- [ ] **Step 5: Manual smoke note (no automated audio)**

Document in the commit body that live audio + MIDI is verified by hand (`just live`), not in CI — the test suite covers the mixer, callback clipping, hot-reload swap, and unknown-voice guard headlessly.

- [ ] **Step 6: Commit**

```bash
git add sound-theme/default/src/live.py sound-theme/default/tests/test_live.py
git commit -m "feat(audio-feedback): live.py real-time mixer + MIDI + hot-reload

Audio-device + MIDI playback verified by hand (just live); the mixer,
callback clipping, hot-reload swap and unknown-voice guard are covered
headlessly in tests/test_live.py."
```

---

## Task 6: `design.ipynb` — Jupyter by-ear audition

A notebook that auditions each palette sound (`Audio(autoplay=True)`), plots waveform + FFT, and renders the whole palette so `nbconvert --execute` validates it end to end. Built by a small regenerable script (hand-editing .ipynb JSON is error-prone).

**Files:**
- Create: `sound-theme/default/src/build_notebook.py`
- Create (generated): `sound-theme/default/src/design.ipynb`

**Interfaces:**
- Consumes: `voices`, `dsp`, `variants.SOUNDS`, `theme.SR`.

- [ ] **Step 1: Write `build_notebook.py`**

Create `sound-theme/default/src/build_notebook.py`:
```python
"""Build design.ipynb -- the by-ear Jupyter audition notebook. Regenerable:
edit the cell sources here and re-run `python build_notebook.py`."""
import os

import nbformat as nbf

CELLS = [
    ("markdown", "# audio-feedback: design by ear\n\n"
                 "Render voices, listen (`Audio` autoplays), and inspect waveform + FFT.\n"
                 "Edit `voices.py` / `tuning.py`, then re-run the imports cell to reload."),
    ("code", "import matplotlib\n"
             "matplotlib.use('Agg')\n"
             "import importlib\n"
             "import numpy as np\n"
             "import matplotlib.pyplot as plt\n"
             "import dsp, voices, tuning\n"
             "importlib.reload(dsp); importlib.reload(tuning); importlib.reload(voices)\n"
             "from theme import SR\n"
             "from variants import SOUNDS\n"
             "from IPython.display import Audio\n"
             "print('sounds:', ', '.join(SOUNDS))"),
    ("markdown", "## Audition one sound"),
    ("code", "sig = voices.render_event(SOUNDS['session-start'])\n"
             "Audio(sig, rate=SR, autoplay=True)"),
    ("markdown", "## Waveform + spectrum"),
    ("code", "def show(name):\n"
             "    sig = voices.render_event(SOUNDS[name]).astype(np.float64)\n"
             "    fig, ax = plt.subplots(1, 2, figsize=(11, 3))\n"
             "    ax[0].plot(np.arange(len(sig)) / SR, sig); ax[0].set_title(name + ' waveform')\n"
             "    mag = np.abs(np.fft.rfft(sig)); freqs = np.fft.rfftfreq(len(sig), 1 / SR)\n"
             "    ax[1].semilogx(freqs[1:], 20 * np.log10(mag[1:] + 1e-9)); ax[1].set_title('spectrum (dB)')\n"
             "    ax[1].set_xlim(20, SR / 2)\n"
             "    plt.tight_layout(); plt.show()\n"
             "show('stop')"),
    ("markdown", "## Render the whole palette (validates every voice)"),
    ("code", "for name in SOUNDS:\n"
             "    s = voices.render_event(SOUNDS[name])\n"
             "    assert s.size and np.all(np.isfinite(s)), name\n"
             "print('[OK]', len(SOUNDS), 'sounds render finite')"),
]


def build() -> str:
    nb = nbf.v4.new_notebook()
    nb.cells = [nbf.v4.new_markdown_cell(src) if kind == "markdown"
                else nbf.v4.new_code_cell(src) for kind, src in CELLS]
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "design.ipynb")
    with open(path, "w") as f:
        nbf.write(nb, f)
    return path


if __name__ == "__main__":
    print("wrote", build())
```

- [ ] **Step 2: Generate the notebook**

Run: `cd sound-theme/default/src && ../.venv/bin/python build_notebook.py && cd -`
Expected: `wrote .../design.ipynb`.

- [ ] **Step 3: Execute the notebook headless (this is the test)**

Run:
```bash
cd sound-theme/default/src && ../.venv/bin/jupyter nbconvert --to notebook --execute --stdout design.ipynb > /dev/null && echo "[OK] notebook executes" && cd -
```
Expected: `[OK] notebook executes` (Agg backend + Audio embed need no audio device; the palette-render cell asserts every sound is finite).

- [ ] **Step 4: Commit**

```bash
git add sound-theme/default/src/build_notebook.py sound-theme/default/src/design.ipynb
git commit -m "feat(audio-feedback): design.ipynb Jupyter by-ear audition (+ builder)"
```

---

## Task 7: justfile recipes + docs

Wire the new surfaces into the justfile, fix the `test` recipe to run the real test files, and update the dev docs to describe the numpy engine and prerequisites.

**Files:**
- Modify: `plugins/audio-feedback/justfile`
- Modify: `sound-theme/default/src/DESIGN-NOTES.md`

**Interfaces:** none (tooling + docs).

- [ ] **Step 1: Update the justfile**

In `plugins/audio-feedback/justfile`:

Change the `venv` recipe comment:
```
# sync the dev env from pyproject.toml (uv-managed Python 3.12 + numpy/scipy/numba/sounddevice/rtmidi + pytest/jupyter)
```

Replace the `test` recipe body with the real test files:
```
# run the sound tests (dsp + voices + generator + live mixer)
test:
    {{py}} -m pytest tests/ -q
```

Add two recipes after `serve`:
```
# real-time: play a MIDI keyboard (or a demo arpeggio); hot-reloads voices.py/tuning.py on save
live-play:
    {{py}} {{src}}/live.py

# open the by-ear design notebook
notebook:
    cd {{src}} && ../.venv/bin/jupyter notebook design.ipynb
```
(Name it `live-play` so it does not collide with the existing `live NAME` re-render-on-save recipe.)

- [ ] **Step 2: Verify the recipes parse and tests run**

Run:
```bash
cd plugins/audio-feedback && just --list && just test && cd -
```
Expected: `just --list` shows `live-play` and `notebook`; `just test` runs all of `tests/` green.

- [ ] **Step 3: Update DESIGN-NOTES.md**

In `sound-theme/default/src/DESIGN-NOTES.md`, replace any signalflow-engine description with the numpy engine: `dsp.py` (primitives) -> `voices.py` (bell/sine/swoosh + `render_event`) -> `generate.py` (offline WAVs). Note the three by-ear surfaces (`just generate`/`preview`/`live`, `just live-play` for MIDI + hot-reload, `just notebook` for Jupyter). List dev prerequisites: uv-managed Python 3.12 venv; `python-rtmidi` needs ALSA/JACK dev headers to build; real-time audio needs a working PortAudio output device (the offline render and tests do not). State that the shipped plugin is unaffected (plays committed WAVs).

- [ ] **Step 4: Commit**

```bash
git add plugins/audio-feedback/justfile sound-theme/default/src/DESIGN-NOTES.md
git commit -m "docs(audio-feedback): justfile live-play/notebook recipes + numpy-engine notes"
```

---

## Self-Review

**Spec coverage:**
- Pure-numpy DSP engine -> Tasks 2-3 (`dsp.py`, `voices.py`), signalflow dropped in Task 4. [OK]
- `dsp.py` primitives (oscillators, envelopes, reverb, `@njit` SVF, pink noise, midi_hz) -> Task 2. (Spec-listed `sweep`/`saturate` dropped: no voice uses them — YAGNI.) [OK]
- `voices.py` bell/sine/swoosh + `VOICES` registry -> Task 3. [OK]
- `live.py` sounddevice callback + polyphonic pre-render mixer + rtmidi + importlib hot-reload + block-safety -> Task 5. (Note-off is a no-op: percussive one-shots self-terminate — release-fade dropped as YAGNI; noted.) [OK]
- `design.ipynb` (Audio autoplay + FFT/waveform) -> Task 6. [OK]
- Offline batch render kept, rewired -> Task 4. [OK]
- Deps +sounddevice/rtmidi/numba/jupyter/matplotlib, -signalflow -> Tasks 1 + 4. [OK]
- Testing: dsp/voices unit tests, offline 28-wav render, headless mixer/reload tests, notebook execute; live audio/MIDI is a manual smoke check -> Tasks 2/3/4/5/6. [OK]
- Keep mininotation/notation/variants/loudness/theme untouched -> honoured (only generate.py modified). [OK]

**Placeholder scan:** no TBD/TODO; every code step has full source. [OK]

**Type consistency:** `Signal` defined in `dsp.py`, re-exported by `voices.py`, referenced as `dsp.Signal` in `generate.py`. `VOICES` is `{"bell","sine"}` in both Task 3 and its test. `render_block` returns `(frames, 2)` in the module and all `test_live` assertions. `midi_hz` lives in `dsp` and is imported by `voices`/`live`. [OK]

**Deviations from spec (intentional, YAGNI):** dropped `sweep`/`saturate` primitives and the note-off release-fade — unused by any voice; recorded here so the reviewer does not flag them as gaps.
