#!/usr/bin/env python3
"""Generate a starter REAPER project: one named track + region marker per
audio-feedback sound filename. Mae opens it and adds synths per track.
Dev-time tool. Run: python scaffold_rpp.py > ../sounds/src/audio-feedback.rpp"""

BASE = ["stop", "notification", "session-start", "subagent-stop",
        "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
GROUPS = ["execute", "modify", "network", "observe", "dispatch", "interact"]
NOTIF = ["auth", "elicitation", "idle", "permission"]
SESSION = ["clear", "compact", "resume"]

# Locked note-map: MIDI note numbers per base event. "seq" = notes played
# sequentially (arpeggio); "chord" = all notes struck together.
NOTE_MAP = {
    "session-start":      {"mode": "seq",   "notes": [48, 52, 55, 58, 60]},  # C3 E3 G3 Bb3 C4 (rise)
    "user-prompt-submit": {"mode": "seq",   "notes": [67]},                   # G4
    "pre-tool-use":       {"mode": "seq",   "notes": [70]},                   # Bb4 (open)
    "notification":       {"mode": "seq",   "notes": [60, 67, 70]},           # C4 G4 Bb4 (rise, open)
    "pre-compact":        {"mode": "chord", "notes": [43, 46]},               # G2 Bb2 (low warn dyad)
    "post-tool-use":      {"mode": "seq",   "notes": [72]},                   # C5 (tonic, resolved)
    "subagent-stop":      {"mode": "seq",   "notes": [64, 60]},               # E4 C4 (fall)
    "stop":               {"mode": "seq",   "notes": [72, 71, 67, 64, 60]},   # C5 B4 G4 E4 C4 (fall, settle)
}

PPQN = 960
VELOCITY = 0x60


def base_event(name):
    """Map a sound name (possibly a variant) to its base NOTE_MAP key."""
    prefixes = [
        ("pre-tool-use-", "pre-tool-use"),
        ("post-tool-use-", "post-tool-use"),
        ("notification-", "notification"),
        ("session-start-", "session-start"),
    ]
    for prefix, base in prefixes:
        if name.startswith(prefix):
            return base
    return name


def _note_hex(note):
    return format(note, "02x")


def _midi_events(mode, notes):
    """Build the sequence of E (event) lines for a MIDI item body."""
    events = []
    if mode == "chord":
        for note in notes:
            events.append(f"E 0 90 {_note_hex(note)} {VELOCITY:02x}")
        for i, note in enumerate(notes):
            delta = PPQN if i == 0 else 0
            events.append(f"E {delta} 80 {_note_hex(note)} 00")
    else:
        for note in notes:
            events.append(f"E 0 90 {_note_hex(note)} {VELOCITY:02x}")
            events.append(f"E {PPQN} 80 {_note_hex(note)} 00")
    events.append("E 0 b0 7b 00")
    return events


def sound_names():
    names = list(BASE)
    names += [f"pre-tool-use-{g}" for g in GROUPS]
    names += [f"post-tool-use-{g}" for g in GROUPS]
    names += [f"notification-{s}" for s in NOTIF]
    names += [f"session-start-{s}" for s in SESSION]
    return names


def build_rpp(names):
    lines = ['<REAPER_PROJECT 0.1 "7.0" 0', "  SAMPLERATE 44100 0 0"]
    for i, n in enumerate(names):
        # region marker pair around a 2s slot per sound (MARKER start / end).
        # Both lines of a region MUST share the same integer ID -- that is
        # what makes REAPER read them as one named region rather than two
        # independent point markers.
        region_id = i + 1
        start = i * 2.0
        end = start + 1.5
        guid = "{{00000000-0000-0000-0000-{:012d}}}".format(i)
        lines.append(f'  MARKER {region_id} {start} "{n}" 1 0 1 R {guid}')
        lines.append(f'  MARKER {region_id} {end} "" 1')
    for i, n in enumerate(names):
        event = base_event(n)
        entry = NOTE_MAP[event]
        mode, notes = entry["mode"], entry["notes"]
        position = i * 2.0
        length = 1.5 if mode == "chord" else max(1.5, len(notes) * 0.5)

        lines.append("  <TRACK")
        lines.append(f'    NAME "{n}"')
        lines.append("    <ITEM")
        lines.append(f"      POSITION {position}")
        lines.append(f"      LENGTH {length}")
        lines.append(f'      NAME "{n}"')
        lines.append("      <SOURCE MIDI")
        lines.append(f"        HASDATA 1 {PPQN} QN")
        for event_line in _midi_events(mode, notes):
            lines.append(f"        {event_line}")
        lines.append("      >")
        lines.append("    >")
        lines.append("  >")
    lines.append(">")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    import sys
    sys.stdout.write(build_rpp(sound_names()))
