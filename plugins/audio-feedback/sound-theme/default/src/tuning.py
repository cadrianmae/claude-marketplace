"""Tuning surface for the audio-feedback default theme.

THIS IS THE FILE TO EDIT WHEN SHAPING SOUNDS BY EAR.

Everything here is a knob. Nothing here does I/O, manages the audio graph, or
loops over the palette -- that lives in synth.py / loudness.py / theme.py /
generate.py. Change a number, then re-render and listen:

    just preview stop            # render one + play
    just live stop notification  # auto re-render + play on save

Per-variant accents (transpose, brightness, layers, ...) live in variants.py.
The note pitches + rhythm live in variants.py (each Sound class). This file is the *voice*: how
a single struck bell sounds, how phrases are spaced, the reverb, and the
palette loudness policy.
"""

# ---- the bell voice -----------------------------------------------------

# Inharmonic partials as (frequency_ratio, amplitude). Ratio 1.0 is the
# fundamental. Slightly-off integers (2.01, 2.99, 4.07) make it read as a
# glassy bell rather than a pure/organ tone. More partials + higher ratios =
# brighter/tinklier; fewer = purer/rounder. Amplitudes taper the highs down.
# PARTIALS = [(1.0, 1.0), (2.01, 0.5), (2.99, 0.28), (4.07, 0.15)]
PARTIALS = [(1.0, 1.0), (2.01, 0.5), (2.99, 0.28)]

# --- alternative voicings: uncomment ONE (and comment the line above) ---
# Church bell (5 named partials, ratios to the prime = the played note): hum
# 0.5 (octave below), prime 1.0, tierce 1.2 (MINOR THIRD -- the plaintive bell
# colour; adds a minor 3rd shadow over EVERY note), quint 1.5 (fifth), nominal
# 2.0 (octave), + superquint 3.0 / upper octave 4.0. On a real bell the low
# partials are quiet+long and the high ones loud+short (our envelope is uniform,
# so this is an approximation). Research: hibberts.co.uk / keltektrust.org.uk.
# PARTIALS = [(0.5, 0.25), (1.0, 1.0), (1.2, 0.30), (1.5, 0.25), (2.0, 0.40), (3.0, 0.15), (4.0, 0.10)]
# Tubular bell / orchestral chime (stretched + inharmonic, "twangy"; the ear
# infers a virtual strike tone an octave below the 4th partial):
# PARTIALS = [(1.0, 1.0), (2.76, 0.5), (5.40, 0.28), (8.93, 0.15)]

# Per-bell ring-out length in seconds (how long one struck note sounds).
# Longer = more sustain/tail; shorter = plinkier. `decay_scale` in a variant
# multiplies this per-sound.
BELL_DUR = 0.5

# Envelope attack in seconds. Struck, not blown: keep this small. Too small
# clicks; ~2-5 ms keeps the transient without a click.
ATTACK_S = BELL_DUR / 2

# Silence padded after a bell's envelope so the render buffer contains the FULL
# decay (attack + release) and lands on zero. Without it the buffer was cut at
# BELL_DUR mid-release, dropping the tail to a non-zero step -> a click at every
# note boundary (one per note in a phrase). synth.py sizes each bell buffer to
# ATTACK_S + BELL_DUR*max(decay_scale, 1) + this pad.
BELL_RELEASE_PAD_S = 0.01

# Envelope segment curve (attack + release shape). 1.0 = linear; >1 = exponential
# (fast initial drop then a long quiet tail -- how a real struck bell decays);
# <1 = logarithmic (slow then fast). ~3-5 reads as a natural bell. Per-variant
# override: `curve` on a Sound class.
CURVE = 1.0

# ---- phrase timing ------------------------------------------------------

# Onset spacing per note value (seconds). This is the tempo of a phrase: how
# far apart successive notes start. Bells ring past their slot (overlap), so
# these are spacings, not durations. Smaller = faster/tighter phrases.
VALUE_SEC = {"quaver": 0.12, "crotchet": 0.24, "minim": 0.48}

# ---- optional accent layers (added by a variant's "layer"/"air_db") -----

# Each layer is (frequency_ratio, duration_scale, level). duration_scale
# multiplies BELL_DUR for that layer's envelope; level is its linear amplitude.
SHIMMER = (6.01, 0.5, 0.06)  # variant: "layer": "shimmer" -> airy high tinkle
SUB = (0.5, 1.0, 0.2)  # variant: "layer": "sub"     -> octave-down body

# "air_db" accent: a short bright high partial. ratio + duration_scale here;
# the level comes from the variant's air_db value (dB).
AIR_RATIO = 8.0
AIR_DUR_SCALE = 0.35

# ---- reverb (applied per sound in postprocess) --------------------------

REVERB_DECAY_S = 0.35  # length of the impulse response tail
REVERB_DAMP = 6.0  # exponential damping of the IR (higher = shorter/darker)
REVERB_PREDELAY_S = 0.008  # gap before the reverb starts (keeps the transient crisp)
REVERB_WET = 0.15  # wet mix (0..1); more = more spacious/washy
REVERB_DRY = 0.85  # dry mix

TAIL_FADE_S = 0.2  # fade the final N seconds to silence (no abrupt cut)

# ---- palette loudness policy (loudness.py) ------------------------------

PEAK_CEILING_DB = -1.0  # final per-file peak ceiling (dBFS); gate wants <= -0.7
CREST_TOLERANCE_DB = 1.0  # only adjust files whose crest deviates from the
# palette mean by more than this (outliers only)
PEAK_GUARD_S = 0.015  # protect the transient: adjust only after peak + this
CROSSFADE_S = 0.015  # splice smoothing into the adjusted tail (avoid a click)
# The loudness pass reduces crest-factor outliers by applying a LINEAR gain to
# the decay tail (raising its RMS), not a power-law waveshaper -- linear gain
# adds no harmonics, so it evens loudness without the distortion artifacts a
# waveshaper produced. Bounds on that tail gain:
CREST_GAIN_RANGE = (0.4, 4.0)
CREST_SHAPE_ITERS = 30

# ---- swoosh voice (network variants: WebFetch/WebSearch) ----------------

# A filtered-noise sweep -- a paper plane thrown to send / arriving to receive.
# Bandpass center sweeps SWOOSH_FREQ_LO -> HI (dir "up" = send) or HI -> LO
# (dir "down" = receive). Not pitched, so note-map/accent knobs don't apply.
SWOOSH_DUR = 0.2  # length of the whoosh (seconds)
SWOOSH_FREQ_LO = 400.0  # sweep low end (Hz)
SWOOSH_FREQ_HI = 5000.0  # sweep high end (Hz)
SWOOSH_Q = 0.7  # bandpass resonance (0..1); higher = more "whistly"
SWOOSH_ATTACK = 0.04  # fade-in (soft, so it reads as a whoosh not a burst)
SWOOSH_LEVEL = 0.5  # pre-normalize level
SWOOSH_SEED = 18  # seed the noise so swoosh renders are deterministic

# ---- subagent-accent overlay (generate.py) ------------------------------

# A bare quiet shimmer mixed over tool sounds fired on behalf of a subagent.
# Two high partials of a high note, low level, a few dB under the palette.
SUBAGENT_NOTE = 84  # MIDI (C6)
SUBAGENT_PARTIALS = [
    (6.01, 0.30, 0.05),  # (ratio, env_release_s, level)
    (4.02, 0.25, 0.04),
]
SUBAGENT_RENDER_S = 0.35
SUBAGENT_OFFSET_DB = -6.0  # sit under the palette so it stays subtle
