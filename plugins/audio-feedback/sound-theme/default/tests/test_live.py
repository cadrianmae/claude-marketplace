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
