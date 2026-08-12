import json, os, sys
HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "sound-theme", "default", "src")
sys.path.insert(0, SRC)
from variants import VARIANTS, Accent  # noqa: E402
BASE = ["session-start","user-prompt-submit","pre-tool-use","notification",
        "pre-compact","post-tool-use","subagent-stop","stop"]
VALUES = {"quaver","crotchet","minim"}

def test_note_map_complete_and_valid():
    nm = json.load(open(os.path.join(SRC, "note_map.json")))
    assert set(nm) == set(BASE)
    assert nm["stop"]["notes"][0][0] == 72 and nm["session-start"]["notes"][0][0] == 48
    assert nm["pre-compact"]["mode"] == "chord"
    for ev in nm.values():
        assert ev["mode"] in {"seq","chord"}
        for midi, val in ev["notes"]:
            assert 0 <= midi <= 127 and val in VALUES

def test_variants_reference_valid_bases():
    nm = json.load(open(os.path.join(SRC, "note_map.json")))
    assert len(VARIANTS) == 19
    for name, accent in VARIANTS.items():
        assert isinstance(accent, Accent)
        assert accent.base in nm
