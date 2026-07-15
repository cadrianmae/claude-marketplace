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
