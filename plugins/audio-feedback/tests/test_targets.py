import json
import os

TARGETS_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "sound_targets.json")


def load_targets():
    with open(TARGETS_PATH) as f:
        return json.load(f)


def test_stop_dominant_hz_matches_final_note():
    targets = load_targets()
    assert abs(targets["stop"]["dominant_hz"] - 261.6) < 0.5


def test_post_tool_use_dominant_hz_matches_final_note():
    targets = load_targets()
    assert abs(targets["post-tool-use"]["dominant_hz"] - 523.3) < 0.5
