#!/usr/bin/env python3
"""Generate a starter REAPER project: one named track + region marker per
audio-feedback sound filename. Mae opens it and adds synths per track.
Dev-time tool. Run: python scaffold_rpp.py > ../sounds/src/audio-feedback.rpp

Built via the `rpp` library (Element tree -> rpp.dumps), rather than hand
concatenating .rpp text -- REAPER's bracketed project format is easy to get
subtly wrong (e.g. mismatched region-marker IDs) when built as raw strings."""

import rpp
from rpp import Element

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
    """Build the sequence of E (event) directives for a MIDI item body.

    Each directive is a plain list: ["E", delta, status, note_hex, velocity].
    """
    events = []
    if mode == "chord":
        for note in notes:
            events.append(["E", "0", "90", _note_hex(note), f"{VELOCITY:02x}"])
        for i, note in enumerate(notes):
            delta = PPQN if i == 0 else 0
            events.append(["E", str(delta), "80", _note_hex(note), "00"])
    else:
        for note in notes:
            events.append(["E", "0", "90", _note_hex(note), f"{VELOCITY:02x}"])
            events.append(["E", str(PPQN), "80", _note_hex(note), "00"])
    events.append(["E", "0", "b0", "7b", "00"])
    return events


def _midi_source(mode, notes):
    """Build the <SOURCE MIDI ...> Element containing the event stream."""
    return Element(
        tag="SOURCE",
        attrib=["MIDI"],
        children=[["HASDATA", "1", str(PPQN), "QN"]] + _midi_events(mode, notes),
    )


def _region_markers(name, idx):
    """Build the two MARKER directives (start + end) forming one region.

    Both share the same integer id (idx + 1) -- that is what makes REAPER
    read them as a single named region rather than two independent point
    markers.
    """
    region_id = str(idx + 1)
    start = idx * 2.0
    end = start + 1.5
    guid = "{{00000000-0000-0000-0000-{:012d}}}".format(idx)
    start_marker = ["MARKER", region_id, str(start), name, "1", "0", "1", "R", guid]
    end_marker = ["MARKER", region_id, str(end), "", "1"]
    return start_marker, end_marker


def _track(name, idx):
    """Build the <TRACK ...> Element for one sound (index gives its slot)."""
    event = base_event(name)
    entry = NOTE_MAP[event]
    mode, notes = entry["mode"], entry["notes"]
    position = idx * 2.0
    length = 1.5 if mode == "chord" else max(1.5, len(notes) * 0.5)
    return Element(
        tag="TRACK",
        attrib=[],
        children=[
            ["NAME", name],
            Element(
                tag="ITEM",
                attrib=[],
                children=[
                    ["POSITION", str(position)],
                    ["LENGTH", str(length)],
                    ["NAME", name],
                    _midi_source(mode, notes),
                ],
            ),
        ],
    )


def sound_names():
    names = list(BASE)
    names += [f"pre-tool-use-{g}" for g in GROUPS]
    names += [f"post-tool-use-{g}" for g in GROUPS]
    names += [f"notification-{s}" for s in NOTIF]
    names += [f"session-start-{s}" for s in SESSION]
    return names


def build_rpp(names):
    """Build the full REAPER project as an rpp Element tree and dump it."""
    children = [["SAMPLERATE", "44100", "0", "0"]]

    # region marker pair around a 2s slot per sound (MARKER start / end).
    for i, n in enumerate(names):
        start_marker, end_marker = _region_markers(n, i)
        children.append(start_marker)
        children.append(end_marker)

    # one named track + MIDI item per sound.
    for i, n in enumerate(names):
        children.append(_track(n, i))

    proj = Element(tag="REAPER_PROJECT", attrib=["0.1", "7.0", "0"], children=children)
    return rpp.dumps(proj)


if __name__ == "__main__":
    import sys
    sys.stdout.write(build_rpp(sound_names()))
