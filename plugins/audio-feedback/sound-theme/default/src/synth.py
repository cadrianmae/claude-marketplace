"""Synthesis engine: struck bells, accent layers, reverb, phrase assembly.

Reads its knobs from tuning.py. Edit numbers in tuning.py, not here, for
by-ear shaping; edit here to change the synthesis *structure* (add a layer
type, change the reverb algorithm, etc.).
"""
# signalflow's pybind11-generated stubs mistype every scalar-accepting node
# parameter as `Node` (e.g. `frequency: Node = 440`), so passing the floats it
# accepts at runtime trips reportArgumentType/reportCallIssue. Scope the
# suppression to this file (the only one that constructs signalflow nodes).
# pyright: reportArgumentType=false, reportCallIssue=false
import numpy as np
from numpy.typing import NDArray
from scipy.signal import fftconvolve
import signalflow as sf

import tuning
from theme import SR
from variants import Sound

Signal = NDArray[np.float32]

_graph: sf.AudioGraph | None = None


def _graph_get() -> sf.AudioGraph:
    """One shared offline AudioGraph, reused across all bell renders."""
    global _graph
    if _graph is None:
        cfg = sf.AudioGraphConfig()
        cfg.sample_rate = SR
        _graph = sf.AudioGraph(config=cfg, output_device="dummy")
    return _graph


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def _render_patch(patch: sf.Node, dur: float) -> Signal:
    """Play one patch on the shared graph, return its mono float32, then reset."""
    g = _graph_get()
    patch.play()
    buf = g.render_to_new_buffer(int(SR * dur))
    mono = np.asarray(buf.data).mean(axis=0).astype("float32")
    g.clear()
    return mono


def _mix(voices: list[sf.Node]) -> sf.Node:
    """Sum a non-empty list of signalflow nodes into one patch."""
    patch = voices[0]
    for v in voices[1:]:
        patch = patch + v
    return patch


def render_bell(freq: float, dur: float = tuning.BELL_DUR, brightness: float = 1.0,
                decay_scale: float = 1.0, detune_cents: float = 0.0, punch: float = 1.0,
                layer: str | None = None, air_db: float | None = None) -> Signal:
    """One struck inharmonic bell -> mono float32."""
    _graph_get()   # signalflow requires the graph to exist before building nodes
    voices: list[sf.Node] = []
    for i, (ratio, amp) in enumerate(tuning.PARTIALS):
        a = amp * (brightness ** i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        env = sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * decay_scale)
        voices.append(sf.SineOscillator(freq * ratio * det) * env * a)
    if layer == "shimmer":
        r, ds, lvl = tuning.SHIMMER
        voices.append(sf.SineOscillator(freq * r) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * ds) * lvl)
    elif layer == "sub":
        r, ds, lvl = tuning.SUB
        voices.append(sf.SineOscillator(freq * r) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * ds) * lvl)
    if air_db is not None:
        air_amp = 10 ** (air_db / 20)
        voices.append(sf.SineOscillator(freq * tuning.AIR_RATIO)
                      * sf.ASREnvelope(tuning.ATTACK_S, 0.0, dur * tuning.AIR_DUR_SCALE) * air_amp)
    return _render_patch(_mix(voices), dur)


def postprocess(sig: Signal) -> Signal:
    """Reverb + tail fade. Loudness is handled once across the palette in
    loudness.py so per-file RMS stays consistent."""
    n = int(SR * tuning.REVERB_DECAY_S)
    ir = np.random.RandomState(0).randn(n) * np.exp(-np.linspace(0, tuning.REVERB_DAMP, n))
    ir = np.concatenate([np.zeros(int(SR * tuning.REVERB_PREDELAY_S)), ir])
    wet = fftconvolve(sig, ir)[:len(sig)]
    sig = sig * tuning.REVERB_DRY + wet / (np.max(np.abs(wet)) + 1e-9) * tuning.REVERB_WET
    f = int(SR * tuning.TAIL_FADE_S)
    if len(sig) > f:
        sig[-f:] *= np.linspace(1, 0, f)
    return sig


def render_swoosh(sound: type[Sound]) -> Signal:
    """Filtered-noise sweep -- a paper plane thrown (send) or arriving (receive).
    Not pitched: ignores the note-map/accent knobs, reads sound.swoosh_dir."""
    _graph_get()   # graph must exist before building nodes
    dur = tuning.SWOOSH_DUR
    lo, hi = tuning.SWOOSH_FREQ_LO, tuning.SWOOSH_FREQ_HI
    if sound.swoosh_dir == "down":
        lo, hi = hi, lo
    cutoff = sf.Line(lo, hi, dur)
    # sf.random_seed() (the global RNG seed) does NOT make PinkNoise
    # deterministic in practice -- confirmed empirically: two renders with
    # the same sf.random_seed() call still differ. StochasticNode.set_seed()
    # on the node instance itself does reproduce byte-identically, so seed
    # the noise node directly rather than the global RNG.
    noise = sf.PinkNoise()
    noise.set_seed(tuning.SWOOSH_SEED)
    filt = sf.SVFilter(noise, sf.SIGNALFLOW_FILTER_TYPE_BAND_PASS, cutoff, tuning.SWOOSH_Q)
    env = sf.ASREnvelope(tuning.SWOOSH_ATTACK, 0.0, dur)
    patch = filt * env * tuning.SWOOSH_LEVEL
    return postprocess(_render_patch(patch, dur))


def render_event(sound: type[Sound]) -> Signal:
    """Render a sound from a variants.Sound class, dispatching on its voice.

    "bell" (default) uses the note-map (sound.mode, sound.notes) + accent knobs
    (sound.transpose/brightness/...); "swoosh" uses render_swoosh."""
    if sound.voice == "swoosh":
        return render_swoosh(sound)
    kw = {
        "brightness": sound.brightness,
        "decay_scale": sound.decay_scale,
        "detune_cents": sound.detune_cents,
        "punch": sound.punch,
        "layer": sound.layer,
        "air_db": sound.air_db,
    }
    notes = sound.notes
    onsets: list[float] = []
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


def render_subagent_accent() -> Signal:
    """The bare quiet shimmer mixed over subagent tool sounds at runtime."""
    _graph_get()   # graph must exist before building nodes
    freq = midi_hz(tuning.SUBAGENT_NOTE)
    voices = [sf.SineOscillator(freq * ratio) * sf.ASREnvelope(tuning.ATTACK_S, 0.0, release) * level
              for ratio, release, level in tuning.SUBAGENT_PARTIALS]
    sig = _render_patch(_mix(voices), tuning.SUBAGENT_RENDER_S)
    sig = postprocess(sig)
    return sig * 10 ** (tuning.SUBAGENT_OFFSET_DB / 20)
