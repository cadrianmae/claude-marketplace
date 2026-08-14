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
