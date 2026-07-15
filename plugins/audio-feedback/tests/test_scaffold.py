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
