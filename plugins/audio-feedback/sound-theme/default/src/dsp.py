"""DSP primitive library: oscillators, envelopes, effects, helpers.

Pure numpy/scipy functions on float32 arrays at theme.SR -- the building blocks
for voices.py. Replaces the signalflow node graph (SineOscillator, ASREnvelope,
SVFilter, PinkNoise) with direct math: exact, unit-testable, and cheap enough to
call inside a real-time audio callback.
"""

import numpy as np
from numba import njit
from numpy.typing import NDArray
from scipy.signal import (  # add to the existing scipy import
    butter,
    fftconvolve,
    sosfilt,
)

from theme import SR

Signal = NDArray[np.float32]


def midi_hz(m: float) -> float:
    """MIDI note number -> frequency in Hz (A4 = 69 = 440)."""
    return 440.0 * 2 ** ((m - 69) / 12)


def oscillator(
    freq: float, n: int, waveform: str = "sine", width: float = 0.5
) -> Signal:
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


def pluck(
    n: int, attack: float, tau_fast: float, tau_slow: float, sustain: float
) -> Signal:
    """A struck/plucked amplitude curve: a linear attack, then a DOUBLE
    exponential decay -- a fast component (`tau_fast`) into a slow tail of
    weight `sustain` (`tau_slow`). One-shot: no gate/hold. (was
    synthmod.pluck_envelope)."""
    t = np.arange(n) / SR
    # raised-cosine attack (zero slope at both ends) -- a linear ramp has a corner
    # that reads as a faint onset click, amplified by loudness on quiet low sounds.
    atk = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-6), 0.0, 1.0))
    decay = (1.0 - sustain) * np.exp(-t / tau_fast) + sustain * np.exp(-t / tau_slow)
    env = atk * decay
    # release fade: taper the last few ms to EXACTLY 0. The exp decay never reaches
    # zero, so without this each note's buffer ends on a non-zero step -> a click at
    # the note's end when it drops out of the phrase sum.
    rel = min(int(SR * 0.008), n)
    if rel > 1:
        env[-rel:] *= 0.5 + 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, rel))
    return env.astype("float32")


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
        env[a : a + ir] = (1.0 - np.arange(ir) / r) ** curve
    return env.astype("float32")


def tremolo(sig: Signal, rate: float, depth: float) -> Signal:
    """Amplitude LFO (sine). `depth` 0..1 = fraction modulated; no-op when depth
    or rate <= 0. (was synthmod.tremolo)."""
    if depth <= 0 or rate <= 0:
        return sig
    t = np.arange(len(sig)) / SR
    lfo = 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))
    return (sig * lfo).astype("float32")


def reverb(
    sig: Signal,
    decay_s: float,
    wet: float,
    damp: float = 4.0,
    predelay_s: float = 0.0,
    extend: bool = True,
) -> Signal:
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
    out = (
        np.concatenate([sig, np.zeros(n, dtype=sig.dtype)])
        if extend
        else sig.astype("float32")
    )
    wet_sig = fftconvolve(out, ir)[: len(out)]
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
    pink /= np.max(np.abs(pink)) + 1e-9
    return pink.astype("float32")


@njit(cache=True)
def _svf_core(
    x: NDArray[np.float64], cutoff: NDArray[np.float64], q: float
) -> NDArray[np.float64]:
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


def lowpass(sig: Signal, cutoff_hz: float, order: int = 4) -> Signal:
    """Butterworth low-pass -- rolls off everything above cutoff_hz to tame
    piercing highs. order = steepness (4 = ~24 dB/oct)."""
    sos = butter(order, cutoff_hz, btype="low", fs=SR, output="sos")
    return sosfilt(sos, sig).astype("float32")
