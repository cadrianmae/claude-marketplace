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


class Sound(ABC):
    # ---- note-map (a base EVENT sets these; a variant inherits them) ----
    notes: ClassVar[list[tuple[Fraction, int]]] = []  # (onset_fraction, midi)
    cycle_sec: ClassVar[float] = 0.12                  # per-sound cycle length

    # ---- voice: which synth renders this sound ----
    voice: ClassVar[str] = "bell"          # "bell" (note-map) | "swoosh" (noise sweep)
    swoosh_dir: ClassVar[str] = "up"       # swoosh only: "up" = send, "down" = receive

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


# ---- base events (carry the locked note-map) ----------------------------

class SessionStart(Sound):     # Mixolydian rise, full bar
    notes = phrase("c3 e3 g3 a#3 c4@4"); cycle_sec = 0.96

class UserPromptSubmit(Sound):
    notes = phrase("g4"); cycle_sec = 0.12

class PreToolUse(Sound):       # open flat-7
    notes = phrase("a#4"); cycle_sec = 0.12

class Notification(Sound):     # rise, open
    notes = phrase("c4 g4 a#4@2"); cycle_sec = 0.48

class PreCompact(Sound):       # low warn dyad
    notes = phrase("[g2,a#2]"); cycle_sec = 0.48

class PostToolUse(Sound):      # tonic, resolved
    notes = phrase("c5"); cycle_sec = 0.12

class SubagentStop(Sound):     # fall (short)
    notes = phrase("e4 c4@2"); cycle_sec = 0.36

class Stop(Sound):             # Ionian fall, settle, full bar
    notes = phrase("c5 b4 g4 e4 c4@4"); cycle_sec = 0.96


# ---- variants (extend a base event -> inherit its notes, add accent) ----

class PreToolUseExecute(PreToolUse):    transpose = -2; punch = 1.2
class PreToolUseObserve(PreToolUse):    brightness = 0.9
class PreToolUseModify(PreToolUse):     layer = "shimmer"
class PreToolUseNetwork(PreToolUse):    voice = "swoosh"; swoosh_dir = "up"    # WebFetch/WebSearch send
class PreToolUseDispatch(PreToolUse):   transpose = 3
class PreToolUseInteract(PreToolUse):   detune_cents = 6

class PostToolUseExecute(PostToolUse):  transpose = -2; punch = 1.2
class PostToolUseObserve(PostToolUse):  brightness = 0.9
class PostToolUseModify(PostToolUse):   layer = "shimmer"
class PostToolUseNetwork(PostToolUse):  voice = "swoosh"; swoosh_dir = "down"  # WebFetch/WebSearch receive
class PostToolUseDispatch(PostToolUse): transpose = 3
class PostToolUseInteract(PostToolUse): detune_cents = 6

class NotificationPermission(Notification):   brightness = 1.15
class NotificationIdle(Notification):         transpose = -2; brightness = 0.9
class NotificationAuth(Notification):         layer = "shimmer"
class NotificationElicitation(Notification):  transpose = 2

class SessionStartResume(SessionStart):   brightness = 1.05
class SessionStartCompact(SessionStart):  transpose = -2
class SessionStartClear(SessionStart):    brightness = 1.1; air_db = -14


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
