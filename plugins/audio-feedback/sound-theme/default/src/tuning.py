"""Tuning surface for the audio-feedback default theme.

THIS IS THE FILE TO EDIT WHEN SHAPING SOUNDS BY EAR.

Everything here is a knob. Nothing here does I/O, manages the audio graph, or
loops over the palette -- that lives in voices.py / loudness.py / theme.py /
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
# note boundary (one per note in a phrase). voices.bell sizes each bell buffer to
# ATTACK_S + BELL_DUR*max(decay_scale, 1) + this pad.
BELL_RELEASE_PAD_S = 0.01

# Envelope segment curve (attack + release shape). 1.0 = linear; >1 = exponential
# (fast initial drop then a long quiet tail -- how a real struck bell decays);
# <1 = logarithmic (slow then fast). ~3-5 reads as a natural bell. Per-variant
# override: `curve` on a Sound class.
CURVE = 1.0

# "pluck" voice (voices.pluck) -- a pure sine with a DOUBLE-exponential pluck
# decay (fast tau into a slow sustain tail), a gentle tremolo, and light reverb,
# reverse-engineered from the original sine blips. (Renamed from the old "sine"
# voice; a new sustained "sine" voice takes its own fresh SINE_* consts.)
PLUCK_LENGTH_S = 0.5  # played length of a pluck note (seconds)
PLUCK_ATTACK_S = 0.15  # pluck attack (fast; NOT the slow bell ATTACK_S)
PLUCK_TAU_FAST = 0.052  # fast pluck decay time constant (s)
PLUCK_TAU_SLOW = 0.15  # slow tail decay time constant (s)
PLUCK_SUSTAIN = 0.1  # weight of the slow tail (0..1)
PLUCK_TREMOLO_HZ = 1.0  # amplitude-wobble rate (unused while depth = 0)
PLUCK_TREMOLO_DEPTH = 0.2  # wobble depth (0..1; 0 = off -- the warble was too much)
PLUCK_REVERB_MULT = 1.0  # reverb wet as a multiple of the shared REVERB_WET

# "sine" voice (voices.sine) -- the SAME chain as pluck (sine + tremolo + reverb)
# but a SUSTAINED envelope instead of a pluck decay: an attack ramp, a flat hold
# at full level, then a release ramp. A held tone rather than a blip.
SINE_LENGTH_S = 0.55  # played length of a sine note (seconds)
SINE_ATTACK_S = 0.02  # fade-in ramp to full level (s)
SINE_RELEASE_S = 0.12  # fade-out ramp at the end (s)
SINE_TREMOLO_HZ = 27.6  # amplitude-wobble rate (unused while depth = 0)
SINE_TREMOLO_DEPTH = 0.0  # wobble depth (0..1; 0 = off)
SINE_REVERB_MULT = 1.0  # reverb wet as a multiple of the shared REVERB_WET

# "clicks" voice/layer (voices.clicks / _click_train) -- a train of short
# decaying-sine blips at the note pitch: a sci-fi "agent typing a command" tick.
# The gap between clicks GROWS each step (decel > 1) so the click rate drops off
# toward the end (keystrokes settling). dsp keys: count, click_dur, gap_start,
# decel, decay, reverb_mult (+ clicks_layer level when used as a layer).
# glassy blip timbre: bright inharmonic partials (ratio, amp) -- stretched like a
# glass chime/tubular bell, so each click rings glassy rather than a dull sine.
CLICK_PARTIALS = [(1.0, 1.0), (2.76, 0.6), (5.40, 0.3), (8.93, 0.12)]
CLICK_COUNT = 5  # number of clicks
CLICK_DUR = 0.05  # length of each blip (seconds)
CLICK_GAP_START = 0.03  # initial gap between clicks (seconds)
CLICK_DECEL = 1.55  # gap growth ratio per click (>1 = rate drops off toward the end)
CLICK_DECAY = 0.02  # blip decay time as a fraction of click_dur (small = tickier)
CLICK_ATTACK = (
    0.15  # blip attack ramp as a fraction of click_dur (>0 softens the onset)
)
CLICK_NOISE = 0.0  # blend to pitched NOISE (0 = glassy tonal, 1 = resonant noise burst)
CLICK_NOISE_Q = 0.15  # noise resonance (lower = narrower band -> more pitched)
CLICK_SEED = 7  # seed the click noise so renders stay deterministic
CLICK_REVERB_MULT = 2.0  # reverb wet as a multiple of the shared REVERB_WET

# "slide" layer (voices._slide) -- a soft filtered-noise rustle, a page-slide/turn
# (reading = observe). Pink noise through a band-pass sweeping HI->LO (settling),
# with a smooth swell+fade so there's no hard edge. Mixed over a base via the
# `slide_layer` dsp key. dsp keys: slide_layer (level), slide_delay, slide_dur,
# slide_freq_lo, slide_freq_hi.
SLIDE_DUR = 0.18  # length of the rustle (seconds)
SLIDE_FREQ_LO = 800.0  # sweep low end (Hz)
SLIDE_FREQ_HI = 2000.0  # sweep high end (Hz); paper is bright/rustly
SLIDE_Q = 1.0  # band-pass width (higher = broader/airier)
SLIDE_ATTACK = 0.4  # swell as a fraction of dur (soft, no hard onset)
SLIDE_LEVEL = 0.07  # pre-mix level
SLIDE_SEED = 11  # seed the noise (deterministic renders)

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

# ---- reverb: ONE shared room for every voice ----------------------------
# Every voice runs through voices._reverb -- same decay/damp/predelay/low-pass,
# with the wet scaled per voice by *_REVERB_MULT (PLUCK_/SINE_ per-voice, and
# BELL_REVERB_MULT for the bell/swoosh/subagent postprocess path).
REVERB_DECAY_S = 0.35  # impulse-response tail length (shared)
REVERB_DAMP = 6.0  # IR damping (higher = shorter/darker) (shared)
REVERB_PREDELAY_S = 0.008  # gap before reverb (postprocess path only; crisp transient)
REVERB_WET = 0.25  # BASE wet mix (0..1); each voice = this * its *_REVERB_MULT
BELL_REVERB_MULT = 1.0  # bell/swoosh/subagent wet, as a multiple of REVERB_WET
LPF_CUTOFF_HZ = (
    8000  # shared post low-pass cutoff (Hz); <= 0 = off (tame piercing highs)
)

TAIL_FADE_S = 0.2  # fade the final N seconds to silence (no abrupt cut)

# ---- palette loudness policy (loudness.py) ------------------------------

PEAK_CEILING_DB = -7.0  # final per-file peak ceiling (dBFS); gate wants <= -0.7
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
SWOOSH_DUR = 0.1  # length of the whoosh (seconds)
SWOOSH_FREQ_LO = 20.0  # sweep low end (Hz)
SWOOSH_FREQ_HI = 700.0  # sweep high end (Hz)
SWOOSH_Q = 1  # bandpass resonance (0..1); higher = more "whistly"
SWOOSH_ATTACK = 0.1  # fade-in (soft, so it reads as a whoosh not a burst)
SWOOSH_LEVEL = 0.2  # pre-normalize level
SWOOSH_SEED = 18  # seed the noise so swoosh renders are deterministic

# ---- subagent background treatment (generate.py: <name>-subagent.wav) ----

# A tool run INSIDE a subagent plays its NORMAL sound pushed into the background,
# as if heard from another room: extra reverb wash + a low-pass + a level trim.
# (Replaces the old overlaid high-shimmer accent note.)
SUBAGENT_REVERB_MULT = 3.0  # extra reverb wet (x REVERB_WET) on the bg version
SUBAGENT_LPF_HZ = 1500.0  # low-pass the bg version (darker/distant); <= 0 = off
SUBAGENT_LEVEL_DB = -3.0  # pull the bg version down a touch
