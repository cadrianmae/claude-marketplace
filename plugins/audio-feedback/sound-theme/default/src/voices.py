"""The synth voices: bell, sine, swoosh -- built from dsp.py primitives.

Each voice renders one note (or, for swoosh, one unpitched gesture) to a mono
float32 signal. `render_event` assembles a variants.Sound's note-map into the
finished signal; `VOICES` maps a Sound.voice string to a pitched per-note
callable for real-time play (live.py). This replaces the old node-graph
synth.py with equivalent numpy math -- edit numbers in tuning.py for by-ear shaping,
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
