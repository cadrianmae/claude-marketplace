"""The synth voices: bell, pluck, sine, swoosh -- built from dsp.py primitives.

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


def bell(
    freq: float,
    dur: float = tuning.BELL_DUR,
    brightness: float = 1.0,
    decay_scale: float = 1.0,
    detune_cents: float = 0.0,
    punch: float = 1.0,
    layer: str | None = None,
    air_db: float | None = None,
    attack: float = tuning.ATTACK_S,
    curve: float = tuning.CURVE,
) -> Signal:
    """One struck inharmonic bell -> mono float32. Sums tuning.PARTIALS (each an
    attack-release sine), plus optional shimmer/sub layer and air partial. The
    buffer spans attack + dur*max(decay_scale,1) + release pad so the whole decay
    lands on zero (no click)."""
    full = attack + dur * max(decay_scale, 1.0) + tuning.BELL_RELEASE_PAD_S
    n = int(SR * full)
    out = np.zeros(n, dtype="float32")
    for i, (ratio, amp) in enumerate(tuning.PARTIALS):
        a = amp * (brightness**i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        out += (
            dsp.oscillator(freq * ratio * det, n)
            * dsp.ar(n, attack, dur * decay_scale, curve)
            * a
        )
    if layer == "shimmer":
        r, ds, lvl = tuning.SHIMMER
        out += dsp.oscillator(freq * r, n) * dsp.ar(n, attack, dur * ds, curve) * lvl
    elif layer == "sub":
        r, ds, lvl = tuning.SUB
        out += dsp.oscillator(freq * r, n) * dsp.ar(n, attack, dur * ds, curve) * lvl
    if air_db is not None:
        air_amp = 10 ** (air_db / 20)
        out += (
            dsp.oscillator(freq * tuning.AIR_RATIO, n)
            * dsp.ar(n, attack, dur * tuning.AIR_DUR_SCALE, curve)
            * air_amp
        )
    return out


def knob(sound: "type[Sound] | None", key: str, default: float) -> float:
    """A per-sound DSP override: sound.dsp[key] if the variant set it, else the
    tuning default. sound=None (e.g. live-play) always uses the default."""
    return default if sound is None else sound.dsp.get(key, default)


def _reverb(sig: Signal, mult: float, *, extend: bool, predelay_s: float = 0.0) -> Signal:
    """One shared reverb room for every voice: the shared decay/damp/predelay, the
    wet scaled by this voice's `mult` (its *_REVERB_MULT x tuning.REVERB_WET), then
    the shared low-pass (off when tuning.LPF_CUTOFF_HZ <= 0)."""
    sig = dsp.reverb(sig, tuning.REVERB_DECAY_S, tuning.REVERB_WET * mult,
                     tuning.REVERB_DAMP, predelay_s=predelay_s, extend=extend)
    if tuning.LPF_CUTOFF_HZ > 0:
        sig = dsp.lowpass(sig, tuning.LPF_CUTOFF_HZ)
    return sig


def pluck(freq: float, sound: "type[Sound] | None" = None, length: float | None = None) -> Signal:
    """The 'pluck' voice: a pure sine with a double-exponential pluck decay, a
    gentle tremolo, and light reverb (reverse-engineered from the old blips).
    `length` = the note's @n x cycle_sec slot (seconds); a dsp `length_s` overrides
    it, and both fall back to the tuning default (e.g. live-play, no note).
    dsp keys: length_s, attack, tau_fast, tau_slow, sustain, tremolo_hz,
    tremolo_depth, reverb_mult."""
    # like bell: the note is at least its natural length, extended if the @n slot is longer
    default_len = max(tuning.PLUCK_LENGTH_S, length) if length is not None else tuning.PLUCK_LENGTH_S
    n = int(SR * knob(sound, "length_s", default_len))
    sig = dsp.oscillator(freq, n) * dsp.pluck(
        n,
        knob(sound, "attack", tuning.PLUCK_ATTACK_S),
        knob(sound, "tau_fast", tuning.PLUCK_TAU_FAST),
        knob(sound, "tau_slow", tuning.PLUCK_TAU_SLOW),
        knob(sound, "sustain", tuning.PLUCK_SUSTAIN),
    )
    sig = dsp.tremolo(
        sig,
        knob(sound, "tremolo_hz", tuning.PLUCK_TREMOLO_HZ),
        knob(sound, "tremolo_depth", tuning.PLUCK_TREMOLO_DEPTH),
    )
    return _reverb(sig, knob(sound, "reverb_mult", tuning.PLUCK_REVERB_MULT), extend=True)


def sine(freq: float, sound: "type[Sound] | None" = None, length: float | None = None) -> Signal:
    """The 'sine' voice: the same chain as `pluck` (sine + tremolo + reverb) but a
    SUSTAINED envelope -- an attack fade-in ramp, a flat hold at full level, then a
    release fade-out -- so the note holds instead of decaying away like a pluck.
    `length` = the note's @n x cycle_sec slot (seconds); a dsp `length_s` overrides
    it, both falling back to the tuning default (e.g. live-play, no note).
    dsp keys: length_s, attack, release_s, tremolo_hz, tremolo_depth, reverb_mult."""
    # like bell: the note is at least its natural length, extended if the @n slot is longer
    default_len = max(tuning.SINE_LENGTH_S, length) if length is not None else tuning.SINE_LENGTH_S
    n = int(SR * knob(sound, "length_s", default_len))
    a = min(int(SR * knob(sound, "attack", tuning.SINE_ATTACK_S)), n)
    r = min(int(SR * knob(sound, "release_s", tuning.SINE_RELEASE_S)), n - a)
    env = np.ones(n, dtype="float32")
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[n - r :] = np.linspace(1.0, 0.0, r)
    sig = dsp.oscillator(freq, n) * env
    sig = dsp.tremolo(
        sig,
        knob(sound, "tremolo_hz", tuning.SINE_TREMOLO_HZ),
        knob(sound, "tremolo_depth", tuning.SINE_TREMOLO_DEPTH),
    )
    return _reverb(sig, knob(sound, "reverb_mult", tuning.SINE_REVERB_MULT), extend=True)


def _click_train(freq: float, sound: "type[Sound] | None" = None) -> Signal:
    """A decelerating train of short decaying-sine blips at `freq` (raw, no reverb).
    The gap between clicks grows by `decel` each step, so the rate drops off toward
    the end. Reused by the `clicks` voice and the clicks layer."""
    count = max(int(knob(sound, "count", tuning.CLICK_COUNT)), 1)
    click_dur = knob(sound, "click_dur", tuning.CLICK_DUR)
    gap0 = knob(sound, "gap_start", tuning.CLICK_GAP_START)
    decel = knob(sound, "decel", tuning.CLICK_DECEL)
    decay = knob(sound, "decay", tuning.CLICK_DECAY)
    cn = max(int(SR * click_dur), 1)
    # glassy blip: sum bright inharmonic partials, with an attack ramp + exp decay
    # (the attack ramp rounds off the hard onset transient).
    env = np.exp(-np.arange(cn) / (cn * decay + 1e-9))
    a = int(cn * knob(sound, "click_attack", tuning.CLICK_ATTACK))
    if a > 0:
        env[:a] *= np.linspace(0.0, 1.0, a)
    tonal = np.zeros(cn, dtype="float32")
    for ratio, amp in tuning.CLICK_PARTIALS:
        tonal += dsp.oscillator(freq * ratio, cn) * amp
    noise_amt = knob(sound, "click_noise", tuning.CLICK_NOISE)
    if noise_amt > 0:                                    # blend in pitched (resonant) noise
        nz = dsp.svf_bandpass(
            dsp.pink_noise(cn, int(tuning.CLICK_SEED)),
            np.full(cn, freq, dtype="float32"),
            tuning.CLICK_NOISE_Q,
        )
        nz *= (float(np.max(np.abs(tonal))) + 1e-9) / (float(np.max(np.abs(nz))) + 1e-9)
        src = (1.0 - noise_amt) * tonal + noise_amt * nz
    else:
        src = tonal
    blip = (src * env).astype("float32")
    gaps = gap0 * decel ** np.arange(count)                       # gap_k = gap0 * decel^k
    onsets = np.concatenate([[0.0], np.cumsum(gaps)[:-1]]) if count > 1 else np.array([0.0])
    total = int(SR * float(onsets[-1])) + cn
    out = np.zeros(total, dtype="float32")
    for ons in onsets:
        i = int(SR * float(ons))
        out[i : i + cn] += blip[: total - i]
    return out


def clicks(freq: float, sound: "type[Sound] | None" = None, length: float | None = None) -> Signal:
    """The 'clicks' voice: a sci-fi 'agent typing a command' tick -- a decelerating
    train of short blips at `freq`. `length` is ignored (the train sets its own
    span). dsp keys: count, click_dur, gap_start, decel, decay, reverb_mult."""
    return _reverb(
        _click_train(freq, sound),
        knob(sound, "reverb_mult", tuning.CLICK_REVERB_MULT),
        extend=True,
    )


def _mix_at(base: Signal, layer: Signal, delay_s: float) -> Signal:
    """Mix `layer` into `base` starting `delay_s` seconds in (extending base if
    the layer runs past the end). Used to overlay clicks/slide layers."""
    off = int(SR * delay_s)
    if off + len(layer) > len(base):
        base = np.concatenate([base, np.zeros(off + len(layer) - len(base), dtype="float32")])
    base[off : off + len(layer)] += layer
    return base


def _slide(sound: "type[Sound] | None" = None) -> Signal:
    """A soft filtered-noise rustle -- a page-slide/turn (reading = observe). Pink
    noise through a band-pass sweeping HI->LO (settling), with a smooth swell+fade
    so there's no hard edge. dsp keys: slide_dur, slide_freq_lo, slide_freq_hi."""
    dur = knob(sound, "slide_dur", tuning.SLIDE_DUR)
    lo = knob(sound, "slide_freq_lo", tuning.SLIDE_FREQ_LO)
    hi = knob(sound, "slide_freq_hi", tuning.SLIDE_FREQ_HI)
    n = max(int(SR * dur), 1)
    cutoff = np.linspace(hi, lo, n).astype("float32")
    filt = dsp.svf_bandpass(dsp.pink_noise(n, int(tuning.SLIDE_SEED)), cutoff, tuning.SLIDE_Q)
    env = dsp.ar(n, dur * tuning.SLIDE_ATTACK, dur * (1.0 - tuning.SLIDE_ATTACK))
    return (filt * env * tuning.SLIDE_LEVEL).astype("float32")


def postprocess(sig: Signal) -> Signal:
    """Reverb + tail fade for the bell/swoosh voices. Loudness is handled once
    across the palette in loudness.py. Does not extend -- callers pre-pad for the
    reverb tail; the tail fade then guards the final cut."""
    sig = _reverb(sig, tuning.BELL_REVERB_MULT, extend=False, predelay_s=tuning.REVERB_PREDELAY_S)
    f = int(SR * tuning.TAIL_FADE_S)
    if len(sig) > f:
        sig = sig.copy()
        sig[-f:] *= np.linspace(1, 0, f)
    return sig


def swoosh(sound: type[Sound]) -> Signal:
    """Filtered-noise sweep -- a paper plane thrown (send) or arriving (receive).
    Not pitched: reads sound.swoosh_dir. Pink noise through a band-pass whose
    centre sweeps lo->hi (up) or hi->lo (down). dsp keys: dur, freq_lo, freq_hi,
    q, attack, level."""
    dur = knob(sound, "dur", tuning.SWOOSH_DUR)
    lo = knob(sound, "freq_lo", tuning.SWOOSH_FREQ_LO)
    hi = knob(sound, "freq_hi", tuning.SWOOSH_FREQ_HI)
    if sound.swoosh_dir == "down":
        lo, hi = hi, lo
    n = int(SR * dur)
    cutoff = np.linspace(lo, hi, n).astype("float32")
    filt = dsp.svf_bandpass(
        dsp.pink_noise(n, tuning.SWOOSH_SEED), cutoff, knob(sound, "q", tuning.SWOOSH_Q)
    )
    sw_attack = knob(sound, "attack", tuning.SWOOSH_ATTACK)
    release = max(dur - sw_attack, 0.01)
    env = dsp.ar(n, sw_attack, release)
    patch = filt * env * knob(sound, "level", tuning.SWOOSH_LEVEL)
    # pad with silence for the reverb tail, then postprocess (no-extend)
    padded = np.concatenate(
        [patch, np.zeros(int(SR * tuning.REVERB_DECAY_S), dtype="float32")]
    )
    return postprocess(padded)


VOICES = {
    "bell": bell,
    "pluck": pluck,
    "sine": sine,
    "clicks": clicks,
}  # pitched per-note voices (live play)


def render_event(sound: type[Sound]) -> Signal:
    """Render a variants.Sound, dispatching on its voice. 'bell' uses the
    note-map + accents; any other pitched voice (pluck, sine, ...) comes from the
    VOICES registry; 'swoosh' is the unpitched noise sweep."""
    if sound.voice == "swoosh":
        return swoosh(sound)
    attack = sound.attack if sound.attack is not None else tuning.ATTACK_S
    curve = sound.curve if sound.curve is not None else tuning.CURVE
    events = sound.notes  # [(Fraction, midi, Fraction)]
    cyc = sound.cycle_sec
    notes: list[Signal] = []
    for _begin, m, dur_f in events:
        dur_sec = float(dur_f) * cyc
        dscale = max(sound.decay_scale, dur_sec / tuning.BELL_DUR)
        freq = midi_hz(m + sound.transpose)
        if sound.voice == "bell":
            notes.append(
                bell(
                    freq,
                    decay_scale=dscale,
                    attack=attack,
                    curve=curve,
                    brightness=sound.brightness,
                    detune_cents=sound.detune_cents,
                    punch=sound.punch,
                    layer=sound.layer,
                    air_db=sound.air_db,
                )
            )
        else:  # pluck/sine: reads dsp overrides from `sound`; note length = its @n slot (dur_sec)
            notes.append(VOICES[sound.voice](freq, sound, dur_sec))
    onsets = [int(SR * float(begin) * cyc) for begin, _m, _d in events]
    total = max(o + len(x) for o, x in zip(onsets, notes))
    out = np.zeros(total, dtype="float32")
    for x, o in zip(notes, onsets):
        out[o : o + len(x)] += x
    # overlay LAYERS over the base render, each starting after its own delay
    # (delay = offset from the note start, not an echo). A sound can stack both.
    if sound.dsp.get("clicks_layer", 0.0) and events:
        train = _click_train(midi_hz(events[0][1] + sound.transpose), sound) * sound.dsp["clicks_layer"]
        out = _mix_at(out, train, sound.dsp.get("clicks_delay", 0.0))
    if sound.dsp.get("slide_layer", 0.0):
        out = _mix_at(out, _slide(sound) * sound.dsp["slide_layer"], sound.dsp.get("slide_delay", 0.0))
    if (
        sound.voice != "bell"
    ):  # pitched non-bell voices carry their own reverb; just guard the cut
        f = int(SR * tuning.TAIL_FADE_S)
        if len(out) > f:
            out[-f:] *= np.linspace(1, 0, f)
        return out
    return postprocess(out)


def to_background(sig: Signal) -> Signal:
    """Push a finished sound into the background -- a tool run INSIDE a subagent,
    heard from another room: extra reverb wash + a low-pass + a level trim.
    (Replaces the old overlaid subagent-accent note.)"""
    sig = dsp.reverb(
        sig, tuning.REVERB_DECAY_S, tuning.REVERB_WET * tuning.SUBAGENT_REVERB_MULT,
        tuning.REVERB_DAMP, extend=True,
    )
    if tuning.SUBAGENT_LPF_HZ > 0:
        sig = dsp.lowpass(sig, tuning.SUBAGENT_LPF_HZ)
    return (sig * 10 ** (tuning.SUBAGENT_LEVEL_DB / 20)).astype("float32")
