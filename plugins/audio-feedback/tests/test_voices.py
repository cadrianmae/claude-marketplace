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


def test_pluck_voice_nonempty_and_finite():
    sig = voices.pluck(660.0)
    assert sig.dtype == np.float32
    assert len(sig) > 0
    assert np.all(np.isfinite(sig))


def test_sine_voice_sustains():
    sig = voices.sine(660.0)
    assert sig.dtype == np.float32
    assert len(sig) > 0
    assert np.all(np.isfinite(sig))
    # sustained, not plucked: the mid-note level holds near the early level
    # (a pluck decay would have fallen away by here).
    early = float(np.abs(sig[int(SR * 0.05):int(SR * 0.10)]).mean())
    mid = float(np.abs(sig[int(SR * 0.30):int(SR * 0.35)]).mean())
    assert mid > 0.6 * early


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


def test_to_background_is_darker():
    from variants import SOUNDS

    dry = voices.render_event(SOUNDS["pre-tool-use"])
    bg = voices.to_background(dry)
    assert bg.dtype == np.float32 and len(bg) > 0 and np.all(np.isfinite(bg))

    def hf_frac(x):
        m = np.abs(np.fft.rfft(x.astype(np.float64)))
        f = np.fft.rfftfreq(len(x), 1 / SR)
        return m[f > 3000].sum() / (m.sum() + 1e-9)

    assert hf_frac(bg) < hf_frac(dry)                # low-passed -> less high-frequency energy


def test_clicks_train_decelerates():
    from variants import Sound

    class C(Sound):
        notes = []
        dsp = {"count": 5, "gap_start": 0.02, "decel": 1.5, "click_dur": 0.005}

    train = voices._click_train(880.0, C)
    assert train.dtype == np.float32 and len(train) > 0 and np.all(np.isfinite(train))
    gaps = 0.02 * 1.5 ** np.arange(5)                 # gap_k = gap0 * decel^k
    assert gaps[-1] > gaps[0]                          # gaps GROW -> rate drops off
    assert len(train) >= int(SR * float(np.cumsum(gaps)[:-1][-1]))  # spans all onsets


def test_clicks_layer_adds_over_base():
    from variants import Sound
    from mininotation import phrase

    class Plain(Sound):
        notes = phrase("c4")
        voice = "sine"

    class Layered(Sound):
        notes = phrase("c4")
        voice = "sine"
        dsp = {"clicks_layer": 0.5, "clicks_delay": 0.1}

    a = voices.render_event(Plain)
    b = voices.render_event(Layered)
    assert not np.array_equal(a, b[: len(a)])          # the clicks layer changed the render


def test_slide_layer_adds_over_base():
    from variants import Sound
    from mininotation import phrase

    class Plain(Sound):
        notes = phrase("c4")
        voice = "pluck"

    class Slid(Sound):
        notes = phrase("c4")
        voice = "pluck"
        dsp = {"slide_layer": 0.5}

    a = voices.render_event(Plain)
    b = voices.render_event(Slid)
    assert not np.array_equal(a, b[: len(a)])          # the slide layer changed the render


def test_dsp_override_applies():
    from variants import Sound

    class Tweaked(Sound):
        notes = []
        voice = "pluck"
        dsp = {"length_s": 1.2}          # override the pluck note length

    default = voices.pluck(440.0)          # no sound -> tuning default
    over = voices.pluck(440.0, Tweaked)    # dsp override
    assert len(over) != len(default)       # the length_s override took effect


def test_voices_registry():
    assert set(voices.VOICES) == {"bell", "pluck", "sine", "clicks"}
    assert callable(voices.VOICES["bell"])
