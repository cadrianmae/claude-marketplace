# Audio-Feedback numpy Real-Time Synth Engine — Design Spec

**Date:** 2026-08-14
**Component:** `plugins/audio-feedback/sound-theme/default`
**Status:** Approved direction (pure-numpy DSP + real-time live app + Jupyter design + offline render). Ready for implementation plan.

## Goal

Replace the signalflow synth engine with a **pure-numpy/scipy DSP engine** that a
sound designer can shape **by ear in real time** — play a MIDI keyboard and hear
voices live, edit the DSP code and hear it hot-reload — and that **batch-renders**
the 27-sound notification palette offline from the mini-notation note-maps. Basis:
Isaac Roberts, *"Drop the DAW: Sound Design in Python"* (ADC 2020).

## Why (context)

The signalflow → DawDreamer/Vital exploration is preserved on branch
`feat/audio-feedback-dawdreamer` (tag-quality reference; the PyQt-Vital idea is a
future project). It was abandoned because DawDreamer is **offline-only** (no
real-time audio, no live keyboard) and Vital's capture workflow is high-friction.
The working branch was reset to the pre-DawDreamer numpy state (`442b6d4`). This
spec builds forward from there: numpy for everything, with a real-time layer.

## Architecture

```
Sound (variants.py: note-map + voice)  -- phrase() -> (onset, midi, duration) --.
                                                                                |
  dsp.py    primitives: oscillators, envelopes, MIDI<->freq, saturation, ...    |
     ^                                                                          v
  voices.py bell / sine / swoosh voices (numpy; @njit for the swoosh filter) ---+
     |                     |                              |
     v                     v                              v
  design.ipynb        live.py (real-time)            generate.py (offline)
  Jupyter audition    sounddevice callback +          note-maps -> voices ->
  (Audio autoplay,    polyphonic mixer +              mix -> loudness -> 27 WAVs
   FFT/waveform)      RTMidi + importlib reload
```

**Kept unchanged:** `mininotation.py` (`phrase()`), `notation.py`, `variants.py`
(note-maps + `voice` field), `loudness.py`, `theme.py`.
**Removed:** signalflow (deps + all uses); `synth.py`'s signalflow bell/swoosh are
reimplemented in numpy (proven-equivalent: bell 1.000, swoosh 0.978 band-similarity).

### `dsp.py` — the shared primitive library (the "jt util")

Pure functions on numpy arrays at `theme.SR`:
- **Oscillators**: `sine/saw/square/pulse(freq, n)`; `sweep(freqs)` via `cumsum` phase.
- **Envelopes**: `pluck(n, attack, tau_fast, tau_slow, sustain)` (linear attack +
  double-exp decay), `exp_decay`, `logistic`, `ar`/`adsr` (length-aware — takes the
  note duration).
- **Effects**: `reverb(sig, decay, wet, damp)` (scipy `fftconvolve`, no predelay —
  avoids slapback), `saturate(sig, order)`, an `@njit` state-variable band-pass
  `svf_bandpass(sig, cutoff_curve, q)` for the swoosh.
- **Helpers**: `midi_hz(m)`, `note_to_seconds(fraction, cycle_sec)`.

### `voices.py` — the voices

Each voice renders one note to a numpy signal, given `(freq, dur, **params)`. Reuse
the existing `synthmod.py` shapes; drop signalflow. A `VOICES` registry maps the
`Sound.voice` string → voice callable.
- **bell** — additive inharmonic partials (`1.0, 2.01, 2.99, 4.07`) × pluck env +
  light reverb.
- **sine** — pure sine + double-exp pluck + reverb (the reverse-engineered old blip).
- **swoosh** — pink noise → `@njit` SVF band-pass sweep (up=send/down=receive).
- Accent knobs (`transpose/brightness/decay_scale/...`) and per-voice params live on
  the voice classes (tunings-in-classes, as before).

### `live.py` — the real-time app (headless)

- `sounddevice.OutputStream(samplerate=SR, channels=2, blocksize=256, callback)` —
  ~12 ms latency (verified).
- **Polyphonic mixer**: on note-on, **pre-render** the note buffer (numpy, ~ms) and
  add it to the active list (Roberts' "render to a sample bank, play samples" — cheap
  and glitch-free vs per-block synthesis). The callback sums active buffers into the
  output block; note-off starts a short release fade; finished buffers are dropped.
- **MIDI**: a `python-rtmidi` input thread → note-on/off → mixer. Enumerate ports;
  if none, the mixer still plays programmatic notes (for testing / note-map audition).
- **Hot-reload**: watch `voices.py`/`dsp.py` mtimes → `importlib.reload` → swap the
  `VOICES` registry ref **only after a clean reload** (try/except; a syntax error is
  caught + printed, audio keeps running; in-flight pre-rendered buffers are unaffected).
- **Block-safety** in the callback: coerce every buffer to the expected dtype
  (`float32`), channel count, and contiguity before summing (numpy has no static
  typing; a bad buffer must not crash the audio thread).

### `design.ipynb` — Jupyter by-ear design

Imports `voices`, `dsp`, `phrase`. Cells: render a sound → `IPython.display.Audio(
sig, rate=SR, autoplay=True)` (instant listen), `matplotlib` waveform + FFT, param
dicts for quick tuning, A/B against the old `.wav`s. `importlib.reload(voices)` cell
to pick up edits. This is the primary "tune a sound" surface.

### `generate.py` — offline batch render (kept, rewired)

Per sound: `VOICES[sound.voice](...)` over the note-map events (length-based
envelopes from each note's duration) → mix → `loudness.normalize_palette` →
`theme.write_wav`. Produces the 27 palette WAVs + `subagent-accent`.

## Dependencies

- **Add**: `sounddevice` (PortAudio), `python-rtmidi`, `numba`, `jupyter`/`ipython`
  (+ `matplotlib` for the notebook), `soundfile` optional (or keep `wave`).
- **Remove**: `signalflow` (deps + imports + the pyright suppression + the
  offline-graph boilerplate).
- All dev-time (the shipped plugin plays WAVs via paplay/daemon — unchanged).

## Testing

- **`dsp.py` / `voices.py` unit tests**: deterministic (seed all noise with
  `RandomState`); assert envelope shapes, oscillator frequencies, the swoosh SVF
  matches the reference spectrum, bell partial ratios.
- **Offline render**: all 27 (+accent) WAVs generate; loudness gate passes.
- **`live.py`**: a headless test of the mixer's `render_block(frames)` (sum of two
  pre-rendered notes = expected), hot-reload swaps the registry, block-safety coerces
  a bad buffer. The actual audio-device playback + MIDI is a manual smoke check
  (skip in CI).
- **Jupyter**: `design.ipynb` executes top-to-bottom without error (nbconvert).

## Risks

- **Audio glitches**: mitigated by pre-rendering notes (sample-bank) — the callback
  only sums/copies, never synthesizes; cheap and constant-time.
- **Hot-reload races**: safe because in-flight notes are already-rendered buffers;
  only *new* note-ons use reloaded code; the registry swap is a single atomic
  reference assignment guarded by try/except.
- **numba first-call compile lag** (~one-time per function) — warm it at startup.
- **numpy in a real-time callback** — keep the callback allocation-free (pre-size the
  mix buffer; slice into pre-rendered arrays). No Python object churn per block.

## Out of scope

- **PyQt GUI** (on-screen keyboard/knobs) — a future project (documented interest).
- **VST/Vital/DawDreamer** — shelved on `feat/audio-feedback-dawdreamer`.
- Shipping any of this in the runtime plugin (it plays the rendered WAVs, unchanged).

## Branch state

- Working branch `feat/audio-feedback-sound-redesign` @ `442b6d4` (pre-DawDreamer).
- `feat/audio-feedback-dawdreamer` @ `9584df4` preserves the DawDreamer/Vital engine.
