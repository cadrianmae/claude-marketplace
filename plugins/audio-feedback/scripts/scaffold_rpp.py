#!/usr/bin/env python3
"""Generate a starter REAPER project: 3 Vital "layer" tracks, each holding
a copy of every audio-feedback sound as a MIDI item, plus one region marker
per sound. Mae opens it and can layer/detune the 3 Vital instances per
sound. Dev-time tool. Run: python scaffold_rpp.py > ../sounds/src/audio-feedback.rpp

Built via the `rpp` library (Element tree -> rpp.dumps), rather than hand
concatenating .rpp text -- REAPER's bracketed project format is easy to get
subtly wrong (e.g. mismatched region-marker IDs) when built as raw strings."""

import copy
import os

import rpp
from rpp import Element

_FRAGMENT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "sounds", "src", "vital-fxchain.rpp-fragment"
)

BASE = ["stop", "notification", "session-start", "subagent-stop",
        "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
GROUPS = ["execute", "modify", "network", "observe", "dispatch", "interact"]
NOTIF = ["auth", "elicitation", "idle", "permission"]
SESSION = ["clear", "compact", "resume"]

# Note-value constants (PPQN 960). One 4/4 bar = 3840 ticks.
SEMIQUAVER = 240
QUAVER = 480
CROTCHET = 960
MINIM = 1920
BAR = 3840  # one 4/4 bar

# Locked note-map: MIDI note numbers + durations (ticks) per base event.
# "seq" = notes played sequentially (arpeggio), each with its own duration;
# "chord" = all notes struck together, sharing one duration. Every event's
# total duration fits within one 4/4 bar (BAR ticks).
NOTE_MAP = {
    "session-start":      {"mode": "seq",   "notes": [[48, QUAVER], [52, QUAVER], [55, QUAVER], [58, QUAVER], [60, MINIM]]},  # C3 E3 G3 Bb3 C4 (rise) -- 3840 = 1 bar
    "user-prompt-submit": {"mode": "seq",   "notes": [[67, QUAVER]]},                                                          # G4
    "pre-tool-use":       {"mode": "seq",   "notes": [[70, QUAVER]]},                                                          # Bb4 (open)
    "notification":       {"mode": "seq",   "notes": [[60, QUAVER], [67, QUAVER], [70, CROTCHET]]},                           # C4 G4 Bb4 (rise, open) -- 1920
    "pre-compact":        {"mode": "chord", "notes": [[43, MINIM], [46, MINIM]]},                                             # G2 Bb2 (low warn dyad) -- 1920
    "post-tool-use":      {"mode": "seq",   "notes": [[72, QUAVER]]},                                                          # C5 (tonic, resolved)
    "subagent-stop":      {"mode": "seq",   "notes": [[64, QUAVER], [60, CROTCHET]]},                                         # E4 C4 (fall) -- 1440
    "stop":               {"mode": "seq",   "notes": [[72, QUAVER], [71, QUAVER], [67, QUAVER], [64, QUAVER], [60, MINIM]]},  # C5 B4 G4 E4 C4 (fall, settle) -- 3840 = 1 bar
}

PPQN = 960
VELOCITY = 0x60

# Zone geometry. Tempo is 120 BPM 4/4, so 1 bar = 2.0s. Each sound gets a
# 2-bar region with a 1-bar gap before the next sound's region starts.
BAR_SEC = 2.0
ZONE_LEN_SEC = 4.0   # 2-bar region
ZONE_STEP_SEC = 6.0  # 3 bars = 2-bar zone + 1-bar gap

LAYER_COUNT = 3


def _vital_fxchain():
    """Load the Vital instrument <FXCHAIN> fragment as an rpp Element.

    Callers must deepcopy the result before attaching it to a track -- the
    same Element object must never be shared between tracks."""
    with open(_FRAGMENT_PATH) as f:
        return rpp.loads(f.read())


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
    `notes` is a list of [midi, ticks] pairs -- each note carries its own
    duration so rhythms can vary (quavers, crotchets, minims) instead of
    every note being a fixed-length crotchet.
    """
    events = []
    if mode == "chord":
        for note, _ticks in notes:
            events.append(["E", "0", "90", _note_hex(note), f"{VELOCITY:02x}"])
        duration = notes[0][1]
        for i, (note, _ticks) in enumerate(notes):
            delta = duration if i == 0 else 0
            events.append(["E", str(delta), "80", _note_hex(note), "00"])
    else:
        for note, ticks in notes:
            events.append(["E", "0", "90", _note_hex(note), f"{VELOCITY:02x}"])
            events.append(["E", str(ticks), "80", _note_hex(note), "00"])
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
    start = idx * ZONE_STEP_SEC
    end = start + ZONE_LEN_SEC
    guid = "{{00000000-0000-0000-0000-{:012d}}}".format(idx)
    start_marker = ["MARKER", region_id, str(start), name, "1", "0", "1", "R", guid]
    end_marker = ["MARKER", region_id, str(end), "", "1"]
    return start_marker, end_marker


def _midi_item(name, idx):
    """Build the <ITEM ...> Element for one sound at its zone slot (index
    gives the zone position, shared by every layer track)."""
    event = base_event(name)
    entry = NOTE_MAP[event]
    mode, notes = entry["mode"], entry["notes"]
    position = idx * ZONE_STEP_SEC
    # total_ticks: chord notes share one duration; seq notes sum their own.
    total_ticks = notes[0][1] if mode == "chord" else sum(ticks for _midi, ticks in notes)
    # REAPER default 120 BPM => 1920 ticks/sec.
    length = total_ticks / 1920.0
    return Element(
        tag="ITEM",
        attrib=[],
        children=[
            ["POSITION", str(position)],
            ["LENGTH", str(length)],
            ["NAME", name],
            _midi_source(mode, notes),
        ],
    )


def _layer_track(layer_num, names):
    """Build one <TRACK ...> Element for a Vital layer: the deepcopied
    Vital FXCHAIN plus one MIDI item per sound name (every layer plays
    every sound)."""
    children = [["NAME", f"Layer {layer_num}"], copy.deepcopy(_vital_fxchain())]
    children += [_midi_item(n, i) for i, n in enumerate(names)]
    return Element(tag="TRACK", attrib=[], children=children)


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

    # region marker pair per sound: 2-bar zone (ZONE_LEN_SEC) with a 1-bar
    # gap before the next sound's zone (MARKER start / end).
    for i, n in enumerate(names):
        start_marker, end_marker = _region_markers(n, i)
        children.append(start_marker)
        children.append(end_marker)

    # 3 Vital layer tracks, each carrying every sound as a MIDI item.
    for layer_num in range(1, LAYER_COUNT + 1):
        children.append(_layer_track(layer_num, names))

    proj = Element(tag="REAPER_PROJECT", attrib=["0.1", "7.0", "0"], children=children)
    return rpp.dumps(proj)


if __name__ == "__main__":
    import sys
    sys.stdout.write(build_rpp(sound_names()))
