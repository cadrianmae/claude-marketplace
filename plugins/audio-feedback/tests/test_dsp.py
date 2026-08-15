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
