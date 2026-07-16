import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import rpp
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


def _parse(txt):
    return rpp.loads(txt)


def _tracks(tree):
    return [e for e in tree if getattr(e, "tag", None) == "TRACK"]


def _child_tag(c):
    """Tag of a child, whether it's a nested Element or a plain directive
    list (rpp represents leaf directives like ["NAME", "x"] as plain lists,
    not Elements)."""
    tag = getattr(c, "tag", None)
    if tag is not None:
        return tag
    if isinstance(c, list) and c:
        return c[0]
    return None


def _find(element, tag):
    """First direct child (Element or plain directive list) with the given
    tag."""
    for c in element:
        if _child_tag(c) == tag:
            return c
    return None


def _findall(element, tag):
    return [c for c in element if _child_tag(c) == tag]


def test_build_rpp_has_three_vital_layer_tracks():
    names = s.sound_names()
    txt = s.build_rpp(names)
    tree = _parse(txt)
    tracks = _tracks(tree)
    assert len(tracks) == 3

    track_names = []
    for tr in tracks:
        name_child = _find(tr, "NAME")
        track_names.append(name_child[1])
        fxchain = _find(tr, "FXCHAIN")
        assert fxchain is not None
        vst = _find(fxchain, "VST")
        assert vst is not None

    assert track_names == ["Layer 1", "Layer 2", "Layer 3"]


def test_layer_track_has_stop_midi_item_with_correct_notes():
    names = s.sound_names()
    txt = s.build_rpp(names)
    tree = _parse(txt)
    tracks = _tracks(tree)
    layer1 = tracks[0]
    items = _findall(layer1, "ITEM")
    assert len(items) == len(names)

    stop_idx = names.index("stop")
    stop_item = items[stop_idx]
    item_txt = rpp.dumps(stop_item)
    assert "<SOURCE MIDI" in item_txt
    note_ons = [l.strip() for l in item_txt.splitlines() if l.strip().startswith("E ") and " 90 " in l]
    assert note_ons[0] == "E 0 90 48 60"
    note_offs = [l.strip() for l in item_txt.splitlines() if l.strip().startswith("E ") and " 80 " in l]
    assert note_offs[-1] == "E 1920 80 3c 00"


def test_regions_positions_and_shared_ids():
    names = s.sound_names()
    txt = s.build_rpp(names)
    assert len(names) == 27 or len(names) >= 27
    n_regions = len(names)

    marker_lines = [l for l in txt.splitlines() if l.strip().startswith("MARKER ")]
    assert len(marker_lines) == 2 * n_regions

    starts = [l for l in marker_lines if " R " in l]
    ends = [l for l in marker_lines if " R " not in l]
    assert len(starts) == n_regions
    assert len(ends) == n_regions

    start_ids = sorted(int(l.split()[1]) for l in starts)
    end_ids = sorted(int(l.split()[1]) for l in ends)
    assert start_ids == list(range(1, n_regions + 1))
    assert end_ids == list(range(1, n_regions + 1))

    # region 0 and region 2: positions 0.0/4.0 and 12.0/16.0 (3-bar step).
    def region_by_id(region_id):
        matching = [l for l in marker_lines if l.split()[1] == str(region_id)]
        assert len(matching) == 2
        return matching

    r0 = region_by_id(1)
    r0_start = [l for l in r0 if " R " in l][0]
    r0_end = [l for l in r0 if " R " not in l][0]
    assert float(r0_start.split()[2]) == 0.0
    assert float(r0_end.split()[2]) == 4.0

    r2 = region_by_id(3)
    r2_start = [l for l in r2 if " R " in l][0]
    r2_end = [l for l in r2 if " R " not in l][0]
    assert float(r2_start.split()[2]) == 12.0
    assert float(r2_end.split()[2]) == 16.0


def test_note_map_covers_all_base_events():
    base = ["stop", "notification", "session-start", "subagent-stop",
            "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
    for name in base:
        assert name in s.NOTE_MAP
        entry = s.NOTE_MAP[name]
        assert entry["mode"] in ("seq", "chord")
        assert len(entry["notes"]) >= 1


def test_note_map_events_fit_within_one_bar():
    """Every base event's total duration must fit within one 4/4 bar (3840
    ticks) -- seq durations sum, chord notes share a single duration."""
    for name, entry in s.NOTE_MAP.items():
        mode, notes = entry["mode"], entry["notes"]
        if mode == "chord":
            total_ticks = notes[0][1]
        else:
            total_ticks = sum(ticks for _midi, ticks in notes)
        assert total_ticks <= s.BAR, f"{name} exceeds one bar: {total_ticks} > {s.BAR}"


def test_base_event_maps_variants():
    assert s.base_event("pre-tool-use-execute") == "pre-tool-use"
    assert s.base_event("post-tool-use-network") == "post-tool-use"
    assert s.base_event("notification-permission") == "notification"
    assert s.base_event("session-start-resume") == "session-start"
    assert s.base_event("stop") == "stop"


def test_midi_item_pre_compact_chord_notes_on_before_off():
    item = s._midi_item("pre-compact", 0)
    item_txt = rpp.dumps(item)
    event_lines = [l.strip() for l in item_txt.splitlines() if l.strip().startswith("E ")]
    on_lines = [l for l in event_lines if " 90 " in l]
    off_lines = [l for l in event_lines if " 80 " in l]
    assert on_lines[:2] == ["E 0 90 2b 60", "E 0 90 2e 60"]
    # both note-ons occur before any note-off
    first_off_index = event_lines.index(off_lines[0])
    assert event_lines.index(on_lines[0]) < first_off_index
    assert event_lines.index(on_lines[1]) < first_off_index
    # pre-compact notes are minims (1920 ticks); first off carries the delta.
    assert off_lines[0] == "E 1920 80 2b 00"
    assert off_lines[1] == "E 0 80 2e 00"


def test_midi_item_variant_inherits_base_event_notes():
    item = s._midi_item("post-tool-use-network", 0)
    item_txt = rpp.dumps(item)
    note_ons = [l.strip() for l in item_txt.splitlines() if l.strip().startswith("E ") and " 90 " in l]
    assert note_ons[0] == "E 0 90 48 60"


def test_layer_tracks_do_not_share_fxchain_object():
    names = ["stop"]
    txt = s.build_rpp(names)
    tree = _parse(txt)
    tracks = _tracks(tree)
    fxchains = [_find(tr, "FXCHAIN") for tr in tracks]
    assert fxchains[0] is not fxchains[1]
    assert fxchains[1] is not fxchains[2]
