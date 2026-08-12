"""Synthesis engine: struck bells, accent layers, reverb, phrase assembly.

Reads its knobs from tuning.py. Edit numbers in tuning.py, not here, for
by-ear shaping; edit here to change the synthesis *structure* (add a layer
type, change the reverb algorithm, etc.).
"""
import numpy as np
from scipy.signal import fftconvolve
import signalflow as sf

import tuning
from theme import SR

_graph = None


def _graph_get():
    """One shared offline AudioGraph, reused across all bell renders."""
    global _graph
    if _graph is None:
        cfg = sf.AudioGraphConfig()
        cfg.sample_rate = SR
        _graph = sf.AudioGraph(config=cfg, output_device="dummy")
    return _graph


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def _render_patch(patch, dur):
    """Play one patch on the shared graph, return its mono float32, reset."""
    g = _graph_get()
    patch.play()
    buf = g.render_to_new_buffer(int(SR * dur))
    mono = np.asarray(buf.data).mean(axis=0).astype("float32")
    g.clear()
    return mono


def render_bell(freq, dur=tuning.BELL_DUR, brightness=1.0, decay_scale=1.0,
                detune_cents=0.0, punch=1.0, layer=None, air_db=None):
    """One struck inharmonic bell -> mono float32."""
    _graph_get()   # signalflow requires the graph to exist before building nodes
    patch = None
    for i, (ratio, amp) in enumerate(tuning.PARTIALS):
        a = amp * (brightness ** i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        env = sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * decay_scale)
        v = sf.SineOscillator(freq * ratio * det) * env * a
        patch = v if patch is None else patch + v
    if layer == "shimmer":
        r, ds, lvl = tuning.SHIMMER
        patch = patch + sf.SineOscillator(freq * r) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * ds) * lvl
    elif layer == "sub":
        r, ds, lvl = tuning.SUB
        patch = patch + sf.SineOscillator(freq * r) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * ds) * lvl
    if air_db is not None:
        air_amp = 10 ** (air_db / 20)
        patch = patch + sf.SineOscillator(freq * tuning.AIR_RATIO) \
            * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * tuning.AIR_DUR_SCALE) * air_amp
    return _render_patch(patch, dur)


def postprocess(sig):
    """Reverb + tail fade. Loudness is handled once across the palette in
    loudness.py so per-file RMS stays consistent for the analyze.py gate."""
    n = int(SR * tuning.REVERB_DECAY_S)
    ir = np.random.RandomState(0).randn(n) * np.exp(-np.linspace(0, tuning.REVERB_DAMP, n))
    ir = np.concatenate([np.zeros(int(SR * tuning.REVERB_PREDELAY_S)), ir])
    wet = fftconvolve(sig, ir)[:len(sig)]
    sig = sig * tuning.REVERB_DRY + wet / (np.max(np.abs(wet)) + 1e-9) * tuning.REVERB_WET
    f = int(SR * tuning.TAIL_FADE_S)
    if len(sig) > f:
        sig[-f:] *= np.linspace(1, 0, f)
    return sig


def render_event(sound):
    """Render a full event phrase from a variants.Sound class.

    Reads the note-map (sound.mode, sound.notes) and accent knobs
    (sound.transpose/brightness/... class attributes) off the class."""
    kw = {
        "brightness": sound.brightness,
        "decay_scale": sound.decay_scale,
        "detune_cents": sound.detune_cents,
        "punch": sound.punch,
        "layer": sound.layer,
        "air_db": sound.air_db,
    }
    notes = sound.notes
    onsets = []
    t = 0.0
    for _, value in notes:
        onsets.append(t)
        t += 0.0 if sound.mode == "chord" else tuning.VALUE_SEC[value]
    total = int(SR * (max(onsets) + tuning.BELL_DUR))
    out = np.zeros(total, dtype="float32")
    for (midi, _), onset in zip(notes, onsets):
        bell = render_bell(midi_hz(midi + sound.transpose), **kw)
        i = int(SR * onset)
        out[i:i + len(bell)] += bell[:total - i]
    return postprocess(out)


def render_subagent_accent():
    """The bare quiet shimmer mixed over subagent tool sounds at runtime."""
    _graph_get()   # graph must exist before building nodes
    freq = midi_hz(tuning.SUBAGENT_NOTE)
    patch = None
    for ratio, release, level in tuning.SUBAGENT_PARTIALS:
        v = sf.SineOscillator(freq * ratio) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, release) * level
        patch = v if patch is None else patch + v
    sig = _render_patch(patch, tuning.SUBAGENT_RENDER_S)
    sig = postprocess(sig)
    return sig * 10 ** (tuning.SUBAGENT_OFFSET_DB / 20)
