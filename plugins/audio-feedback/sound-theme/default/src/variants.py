"""The sound palette as a class hierarchy: note-map + accent per event/variant.

`Sound` is the abstract base: it declares the note-map fields (notes,
cycle_sec) and every accent knob with neutral defaults. Each base EVENT is a
subclass carrying its own notes. Each VARIANT extends its base event class --
so it inherits the notes and overrides only the accent knobs that differ.
Data lives with the class it belongs to; there is no separate
note_map.json / variants.json.

`notes` is a mini-notation string parsed via `phrase(...)` (see
mininotation.py) into a sorted list of `(onset_fraction, midi)` events for one
cycle, where onset is a Fraction in [0, 1). `,` inside the spec stacks
sequences to play simultaneously (replaces the old mode="chord"). `cycle_sec`
is the per-sound cycle length in seconds -- it scales the fractional onsets
into real time (see synth.render_event).

This is a tuning surface. Edit a class's notes or knobs, then re-render:
    just live stop
    just preview pre-tool-use-network

Accent knobs (see synth.render_bell):
  transpose     semitones to shift the phrase (keeps mode/contour)
  brightness    partial tilt toward the highs (>1 brighter, <1 rounder)
  decay_scale   multiply BELL_DUR for this sound (longer/shorter ring)
  detune_cents  micro-detune between partials (richness/shimmer)
  punch         fundamental emphasis on the attack (>1 punchier)
  layer         add a named layer: "shimmer" (airy high) or "sub" (octave down)
  air_db        add a short high "air" partial at this level in dB (e.g. -12)
"""

from abc import ABC
from fractions import Fraction
from typing import ClassVar

from mininotation import phrase

# ---- cycle_sec grid: bar-fraction durations (seconds) --------------------
# cycle_sec scales a sound's mini-notation onsets (fractions of one cycle) into
# real time, so it sets that sound's tempo. One "bar" = FULL_BAR seconds; the
# rest are its halvings. Odd values combine them (SubagentStop = 3 * EIGHTH_BAR,
# a three-eighths bar). Use these instead of raw seconds for cycle_sec.
FULL_BAR = 0.96
HALF_BAR = 0.48
QUARTER_BAR = 0.24
EIGHTH_BAR = 0.12
SIXTEENTH_BAR = 0.06


class Sound(ABC):
    # ---- note-map (a base EVENT sets these; a variant inherits them) ----
    notes: ClassVar[
        list[tuple[Fraction, int, Fraction]]
    ] = []  # (onset, midi, duration) fractions
    cycle_sec: ClassVar[float] = EIGHTH_BAR  # per-sound cycle length

    # ---- voice: which synth renders this sound ----
    voice: ClassVar[str] = (
        "pluck"  # "bell" (note-map) | "pluck" (decaying beep) | "sine" (sustained) | "swoosh" (sweep)
    )
    swoosh_dir: ClassVar[str] = "up"  # swoosh only: "up" = send, "down" = receive

    # ---- accent knobs (bell voice only; neutral defaults; a variant overrides) ----
    transpose: ClassVar[int] = 0
    brightness: ClassVar[float] = 1.0
    decay_scale: ClassVar[float] = 1.0
    detune_cents: ClassVar[float] = 0.0
    punch: ClassVar[float] = 1.0
    layer: ClassVar[str | None] = None
    air_db: ClassVar[float | None] = None
    # per-sound output level trim in dB (0 = at the palette peak ceiling; negative
    # pulls this sound down). Sets real playback loudness, by ear.
    level_db: ClassVar[float] = 0.0

    # ---- per-sound DSP overrides (pluck / sine / swoosh voices) ----------
    # `dsp` overrides any of the current voice's tuning knobs for JUST this sound:
    # the voice reads knob(sound, "key", tuning.DEFAULT). Keys per voice (voices.py):
    #   pluck:  length_s attack tau_fast tau_slow sustain tremolo_hz tremolo_depth reverb_mult
    #   sine:   length_s attack release_s tremolo_hz tremolo_depth reverb_mult
    #   swoosh: dur freq_lo freq_hi q attack level
    # e.g. dsp = {"reverb_mult": 2.0, "tremolo_depth": 0.3, "length_s": 0.8}
    dsp: ClassVar[dict[str, float]] = {}

    # ---- bell-voice envelope overrides (None = use the tuning.py global) --
    attack: ClassVar[float | None] = None  # override ATTACK_S (bell attack, seconds)
    curve: ClassVar[float | None] = None  # override CURVE (1=linear, >1=exp decay)


# ---- base events (carry the locked note-map) ----------------------------


class SessionStart(
    Sound
):  # Mixolydian rise, full bar -- accelerates (durations 3,3,1,1/2,1/2)
    notes = phrase("c3@3 e3@2 g3 [a#3 c4]")
    cycle_sec = FULL_BAR * 1.5


class UserPromptSubmit(Sound):
    notes = phrase("g4")
    cycle_sec = EIGHTH_BAR


class PreToolUse(Sound):  # open flat-7
    notes = phrase("a#4")
    cycle_sec = SIXTEENTH_BAR


class Notification(Sound):  # rise, open -- kept subtle (quieter + sits back)
    notes = phrase("g4 a#4@2")
    cycle_sec = HALF_BAR
    level_db = -8  # pull it down so it's not in your face
    dsp = {"reverb_mult": 1.5}  # a touch more wash -> recedes into the background


class PreCompact(Sound):  # low warn dyad
    voice = "sine"
    notes = phrase("[c3,e3,g3]")
    dsp = {
        "attack": 0.4,
        "release_s": 0.4,
        "reverb_mult": 2.0,
    }
    cycle_sec = FULL_BAR


class PostToolUse(Sound):  # tonic, resolved
    notes = phrase("c5")
    cycle_sec = SIXTEENTH_BAR


class SubagentStop(Sound):  # fall (short)
    notes = phrase("e4 c4@2")
    cycle_sec = 3 * EIGHTH_BAR


class Stop(Sound):  # Ionian fall, settle, full bar
    notes = phrase("[c5 b4@2] g4 e4@2 c4@3")
    cycle_sec = FULL_BAR


# ---- variants (extend a base event -> inherit its notes, add accent) ----


class PreToolUseExecute(PreToolUse):
    voice = "pluck"  # plucked tone + glassy clicks layered over it (sci-fi typing)
    transpose = -2
    dsp = {"clicks_layer": 0.4, "clicks_delay": 0.2}


class PreToolUseObserve(PreToolUse):
    dsp = {"slide_layer": 0.6, "slide_delay": 0.05}  # page-slide rustle (reading)


class PreToolUseModify(PreToolUse):
    # modify = read + write: a page-slide rustle AND pitched-noise clicks over the pluck
    dsp = {
        "clicks_layer": 0.4,
        "clicks_delay": 0.2,
        "click_noise": 1.0,
    }


class PreToolUseNetwork(PreToolUse):
    voice = "swoosh"
    swoosh_dir = "up"  # WebFetch/WebSearch send


class PreToolUseDispatch(PreToolUse):
    notes = phrase("e4")  # tonic, resolved


class PreToolUseInteract(PreToolUse):
    notes = phrase("g4 c5")  # rising motif = a spoken question's upward "?" inflection
    cycle_sec = QUARTER_BAR


class PostToolUseExecute(PostToolUse):
    transpose = -2
    dsp = {"clicks_layer": 0.4, "clicks_delay": 0.2}


class PostToolUseObserve(PostToolUse):
    dsp = {"slide_layer": 0.6, "slide_delay": 0.05}  # page-slide rustle (reading)


class PostToolUseModify(PostToolUse):
    # modify = read + write: a page-slide rustle AND pitched-noise clicks over the pluck
    dsp = {
        "clicks_layer": 0.4,
        "clicks_delay": 0.2,
        "click_noise": 1.0,
    }


class PostToolUseNetwork(PostToolUse):
    voice = "swoosh"
    swoosh_dir = "down"  # WebFetch/WebSearch receive


class PostToolUseDispatch(PostToolUse):
    notes = phrase("g4")  # tonic, resolved


class PostToolUseInteract(PostToolUse):
    notes = phrase(
        "g4 c4"
    )  # falling to the tonic = a resolved "answer" (mirrors the pre question)
    cycle_sec = QUARTER_BAR


class NotificationPermission(Notification):
    brightness = 1.15


class NotificationIdle(Notification):
    voice = "sine"
    notes = phrase("c4")
    transpose = -2
    level_db = -12
    dsp = {"attack": 0.4, "release_s": 0.4, "reverb_mult": 2.0, "reverb_wet": 0.7}
    cycle_sec = FULL_BAR


class NotificationAuth(Notification):
    layer = "shimmer"


class NotificationElicitation(Notification):
    transpose = 2


class SessionStartResume(SessionStart):
    brightness = 1.05


class SessionStartCompact(SessionStart):
    # notes = phrase("c3 e3 g3 a#3 c4")
    voice = "sine"
    dsp = {
        "attack": 0.2,
        "release_s": 0.4,
        "reverb_mult": 2.0,
    }
    transpose = -2


class SessionStartClear(SessionStart):
    brightness = 1.1
    air_db = -14


# ---- registry: sound name -> class (8 base + 19 variants) ----------------

SOUNDS: dict[str, type[Sound]] = {
    "session-start": SessionStart,
    "user-prompt-submit": UserPromptSubmit,
    "pre-tool-use": PreToolUse,
    "notification": Notification,
    "pre-compact": PreCompact,
    "post-tool-use": PostToolUse,
    "subagent-stop": SubagentStop,
    "stop": Stop,
    "pre-tool-use-execute": PreToolUseExecute,
    "pre-tool-use-observe": PreToolUseObserve,
    "pre-tool-use-modify": PreToolUseModify,
    "pre-tool-use-network": PreToolUseNetwork,
    "pre-tool-use-dispatch": PreToolUseDispatch,
    "pre-tool-use-interact": PreToolUseInteract,
    "post-tool-use-execute": PostToolUseExecute,
    "post-tool-use-observe": PostToolUseObserve,
    "post-tool-use-modify": PostToolUseModify,
    "post-tool-use-network": PostToolUseNetwork,
    "post-tool-use-dispatch": PostToolUseDispatch,
    "post-tool-use-interact": PostToolUseInteract,
    "notification-permission": NotificationPermission,
    "notification-idle": NotificationIdle,
    "notification-auth": NotificationAuth,
    "notification-elicitation": NotificationElicitation,
    "session-start-resume": SessionStartResume,
    "session-start-compact": SessionStartCompact,
    "session-start-clear": SessionStartClear,
}
