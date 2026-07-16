import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import scaffold_rpp as s

def test_sound_names_cover_base_and_variants():
    names = s.sound_names()
    assert "stop" in names
    assert "pre-tool-use-execute" in names
    assert "post-tool-use-network" in names
    assert "notification-permission" in names
    assert "session-start-resume" in names
    # 8 base + 6 pre + 6 post + 4 notification + 3 session-start = 27..28
    assert len(names) >= 27

def test_build_rpp_is_reaper_project_with_regions():
    names = ["stop", "notification"]
    txt = s.build_rpp(names)
    assert txt.startswith("<REAPER_PROJECT")
    assert txt.strip().endswith(">")
    # one named track + region marker per name
    for n in names:
        assert f'NAME "{n}"' in txt or f'NAME {n}' in txt
    assert txt.count("<TRACK") == len(names)

    # Each region is a PAIR of MARKER lines sharing the same integer ID --
    # a start line (quoted name + " R ") and an end line (empty name "").
    # Under the old bug each pair used distinct IDs (2*slot+1, 2*slot+2),
    # which this test would catch.
    marker_lines = [l for l in txt.splitlines() if l.strip().startswith("MARKER ")]
    assert len(marker_lines) == 2 * len(names)

    starts = [l for l in marker_lines if " R " in l]
    ends = [l for l in marker_lines if " R " not in l]
    assert len(starts) == len(names)
    assert len(ends) == len(names)

    start_ids = sorted(int(l.split()[1]) for l in starts)
    end_ids = sorted(int(l.split()[1]) for l in ends)
    assert start_ids == list(range(1, len(names) + 1))
    assert end_ids == list(range(1, len(names) + 1))

    # Each start's name matches an end with the SAME id.
    for start in starts:
        parts = start.split()
        region_id = int(parts[1])
        matching_ends = [l for l in ends if int(l.split()[1]) == region_id]
        assert len(matching_ends) == 1
        assert '""' in matching_ends[0]


def test_note_map_covers_all_base_events():
    base = ["stop", "notification", "session-start", "subagent-stop",
            "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
    for name in base:
        assert name in s.NOTE_MAP
        entry = s.NOTE_MAP[name]
        assert entry["mode"] in ("seq", "chord")
        assert len(entry["notes"]) >= 1


def test_base_event_maps_variants():
    assert s.base_event("pre-tool-use-execute") == "pre-tool-use"
    assert s.base_event("post-tool-use-network") == "post-tool-use"
    assert s.base_event("notification-permission") == "notification"
    assert s.base_event("session-start-resume") == "session-start"
    assert s.base_event("stop") == "stop"


def test_build_rpp_stop_track_has_midi_item_with_five_notes():
    txt = s.build_rpp(["stop"])
    # Isolate the stop track block. Hyphenated names have no spaces, so rpp
    # dumps them unquoted (`NAME stop`, not `NAME "stop"`).
    start = txt.index("NAME stop")
    track_txt = txt[start:]
    assert "<SOURCE MIDI" in track_txt
    note_ons = [l for l in track_txt.splitlines() if l.strip().startswith("E ") and " 90 " in l]
    assert len(note_ons) == 5
    assert note_ons[0].strip() == "E 0 90 48 60"
    assert track_txt.strip().splitlines()[-1].strip() == ">" or "E 0 b0 7b 00" in track_txt


def test_build_rpp_pre_compact_chord_notes_on_before_off():
    txt = s.build_rpp(["pre-compact"])
    start = txt.index("NAME pre-compact")
    track_txt = txt[start:]
    event_lines = [l.strip() for l in track_txt.splitlines() if l.strip().startswith("E ")]
    on_lines = [l for l in event_lines if " 90 " in l]
    off_lines = [l for l in event_lines if " 80 " in l]
    assert on_lines[:2] == ["E 0 90 2b 60", "E 0 90 2e 60"]
    # both note-ons occur before any note-off
    first_off_index = event_lines.index(off_lines[0])
    assert event_lines.index(on_lines[0]) < first_off_index
    assert event_lines.index(on_lines[1]) < first_off_index


def test_build_rpp_variant_inherits_base_event_notes():
    txt = s.build_rpp(["post-tool-use-network"])
    start = txt.index("NAME post-tool-use-network")
    track_txt = txt[start:]
    note_ons = [l.strip() for l in track_txt.splitlines() if l.strip().startswith("E ") and " 90 " in l]
    assert note_ons[0] == "E 0 90 48 60"
