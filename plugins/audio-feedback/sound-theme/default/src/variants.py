"""The sound palette as a class hierarchy: note-map + accent per event/variant.

`Sound` is the abstract base: it declares the note-map fields (mode, notes) and
every accent knob with neutral defaults. Each base EVENT is a subclass carrying
its own notes. Each VARIANT extends its base event class -- so it inherits the
notes and overrides only the accent knobs that differ. Data lives with the
class it belongs to; there is no separate note_map.json / variants.json.

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
from typing import ClassVar, Optional


class Sound(ABC):
    # ---- note-map (a base EVENT sets these; a variant inherits them) ----
    mode: ClassVar[str] = "seq"                       # "seq" | "chord"
    notes: ClassVar[list[tuple[int, str]]] = []       # (midi, "quaver"|"crotchet"|"minim")

    # ---- accent knobs (neutral defaults; a variant overrides) ----
    transpose: ClassVar[int] = 0
    brightness: ClassVar[float] = 1.0
    decay_scale: ClassVar[float] = 1.0
    detune_cents: ClassVar[float] = 0.0
    punch: ClassVar[float] = 1.0
    layer: ClassVar[Optional[str]] = None
    air_db: ClassVar[Optional[float]] = None


# ---- base events (carry the locked note-map) ----------------------------

class SessionStart(Sound):     # Mixolydian rise, full bar
    notes = [(48, "quaver"), (52, "quaver"), (55, "quaver"), (58, "quaver"), (60, "minim")]

class UserPromptSubmit(Sound):
    notes = [(67, "quaver")]

class PreToolUse(Sound):       # open flat-7
    notes = [(70, "quaver")]

class Notification(Sound):     # rise, open
    notes = [(60, "quaver"), (67, "quaver"), (70, "crotchet")]

class PreCompact(Sound):       # low warn dyad
    mode = "chord"
    notes = [(43, "minim"), (46, "minim")]

class PostToolUse(Sound):      # tonic, resolved
    notes = [(72, "quaver")]

class SubagentStop(Sound):     # fall (short)
    notes = [(64, "quaver"), (60, "crotchet")]

class Stop(Sound):             # Ionian fall, settle, full bar
    notes = [(72, "quaver"), (71, "quaver"), (67, "quaver"), (64, "quaver"), (60, "minim")]


# ---- variants (extend a base event -> inherit its notes, add accent) ----

class PreToolUseExecute(PreToolUse):    transpose = -2; punch = 1.2
class PreToolUseObserve(PreToolUse):    brightness = 0.9
class PreToolUseModify(PreToolUse):     layer = "shimmer"
class PreToolUseNetwork(PreToolUse):    brightness = 1.3; air_db = -12
class PreToolUseDispatch(PreToolUse):   transpose = 3
class PreToolUseInteract(PreToolUse):   detune_cents = 6

class PostToolUseExecute(PostToolUse):  transpose = -2; punch = 1.2
class PostToolUseObserve(PostToolUse):  brightness = 0.9
class PostToolUseModify(PostToolUse):   layer = "shimmer"
class PostToolUseNetwork(PostToolUse):  brightness = 1.3; air_db = -12
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
