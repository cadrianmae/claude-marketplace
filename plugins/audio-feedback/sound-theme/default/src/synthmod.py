"""Modular synth: small, composable numpy DSP blocks.

A voice is a chain: oscillator -> amplitude envelope -> (tremolo) -> (filter...).
Pure numpy so envelopes are exact and unit-testable. Used by the "sine" voice
(synth.render_event) and reusable for future voices. The bell/swoosh voices in
synth.py still use signalflow; this module is the lightweight alternative for
voices that are easier to express as direct math.
"""
import numpy as np
from numpy.typing import NDArray
from scipy.signal import fftconvolve

from theme import SR

Signal = NDArray[np.float32]


def oscillator(freq: float, n: int, waveform: str = "sine", width: float = 0.5) -> Signal:
    """`n` samples at `freq`. waveform: sine | saw | square | pulse
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


def pluck_envelope(n: int, attack: float, tau_fast: float, tau_slow: float,
                   sustain: float) -> Signal:
    """A struck/plucked amplitude curve: a linear attack, then a DOUBLE
    exponential decay -- a fast component (`tau_fast`) into a slow tail of
    weight `sustain` (`tau_slow`). One-shot: no gate/hold."""
    t = np.arange(n) / SR
    atk = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    decay = (1.0 - sustain) * np.exp(-t / tau_fast) + sustain * np.exp(-t / tau_slow)
    return (atk * decay).astype("float32")


def tremolo(sig: Signal, rate: float, depth: float) -> Signal:
    """Amplitude LFO (sine). `depth` 0..1 = fraction of amplitude modulated;
    a no-op when depth or rate is <= 0."""
    if depth <= 0 or rate <= 0:
        return sig
    t = np.arange(len(sig)) / SR
    lfo = 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))
    return (sig * lfo).astype("float32")


def reverb(sig: Signal, decay_s: float, wet: float, damp: float = 4.0) -> Signal:
    """Diffuse exponential-noise reverb. No predelay (a predelay makes the loud
    first IR sample land as a discrete delayed copy -> a slapback double), so
    the tail blooms smoothly. Extends the signal by the IR length so the tail
    rings out instead of being cut. `wet` 0..1 (0 or decay<=0 = no-op)."""
    if wet <= 0 or decay_s <= 0:
        return sig
    n = int(SR * decay_s)
    ir = np.random.RandomState(0).randn(n) * np.exp(-np.linspace(0, damp, n))
    out = np.concatenate([sig, np.zeros(n, dtype=sig.dtype)])
    wet_sig = fftconvolve(out, ir)[:len(out)]
    mixed = out * (1.0 - wet) + wet_sig / (np.max(np.abs(wet_sig)) + 1e-9) * wet
    return mixed.astype("float32")


def render_voice(freq: float, length: float, *, waveform: str = "sine",
                 width: float = 0.5, attack: float = 0.008,
                 tau_fast: float = 0.026, tau_slow: float = 0.15,
                 sustain: float = 0.1, tremolo_hz: float = 0.0,
                 tremolo_depth: float = 0.0, reverb_wet: float = 0.0,
                 reverb_decay: float = 0.4, reverb_damp: float = 4.0) -> Signal:
    """One modular-synth note: oscillator -> pluck envelope -> tremolo -> reverb.
    `length` is the note's span in seconds; reverb extends it by its tail."""
    n = int(SR * length)
    sig = oscillator(freq, n, waveform, width) * pluck_envelope(n, attack, tau_fast, tau_slow, sustain)
    sig = tremolo(sig, tremolo_hz, tremolo_depth)
    return reverb(sig, reverb_decay, reverb_wet, reverb_damp)
