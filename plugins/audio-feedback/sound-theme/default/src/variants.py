"""Category-variant accents as typed data, next to the synthesis.

`Accent` is the single schema for every accent knob, with neutral defaults; a
variant sets only what differs from its base event. This is a tuning surface:
edit the values here (with `just live <name>`), same as tuning.py.

What each knob does (see synth.render_bell / render_event):
  transpose     semitones to shift the phrase (keeps mode/contour)
  brightness    partial tilt toward the highs (>1 brighter, <1 rounder)
  decay_scale   multiply BELL_DUR for this variant (longer/shorter ring)
  detune_cents  micro-detune between partials (richness/shimmer)
  punch         fundamental emphasis on the attack (>1 punchier)
  layer         add a named layer: "shimmer" (airy high) or "sub" (octave down)
  air_db        add a short high "air" partial at this level in dB (e.g. -12)
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Accent:
    base: str                          # which base event this varies
    transpose: int = 0
    brightness: float = 1.0
    decay_scale: float = 1.0
    detune_cents: float = 0.0
    punch: float = 1.0
    layer: str | None = None
    air_db: float | None = None


# tool groups (pre_tool_use / post_tool_use), notification types, session sources.
VARIANTS: dict[str, Accent] = {
    "pre-tool-use-execute":     Accent("pre-tool-use",  transpose=-2, punch=1.2),
    "pre-tool-use-observe":     Accent("pre-tool-use",  brightness=0.9),
    "pre-tool-use-modify":      Accent("pre-tool-use",  layer="shimmer"),
    "pre-tool-use-network":     Accent("pre-tool-use",  brightness=1.3, air_db=-12),
    "pre-tool-use-dispatch":    Accent("pre-tool-use",  transpose=3),
    "pre-tool-use-interact":    Accent("pre-tool-use",  detune_cents=6),
    "post-tool-use-execute":    Accent("post-tool-use", transpose=-2, punch=1.2),
    "post-tool-use-observe":    Accent("post-tool-use", brightness=0.9),
    "post-tool-use-modify":     Accent("post-tool-use", layer="shimmer"),
    "post-tool-use-network":    Accent("post-tool-use", brightness=1.3, air_db=-12),
    "post-tool-use-dispatch":   Accent("post-tool-use", transpose=3),
    "post-tool-use-interact":   Accent("post-tool-use", detune_cents=6),
    "notification-permission":  Accent("notification",  brightness=1.15),
    "notification-idle":        Accent("notification",  transpose=-2, brightness=0.9),
    "notification-auth":        Accent("notification",  layer="shimmer"),
    "notification-elicitation": Accent("notification",  transpose=2),
    "session-start-resume":     Accent("session-start", brightness=1.05),
    "session-start-compact":    Accent("session-start", transpose=-2),
    "session-start-clear":      Accent("session-start", brightness=1.1, air_db=-14),
}
