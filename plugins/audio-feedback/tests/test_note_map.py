import os, sys

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "sound-theme", "default", "src")
sys.path.insert(0, SRC)
from variants import SOUNDS, Sound  # noqa: E402

BASE = ["session-start", "user-prompt-submit", "pre-tool-use", "notification",
        "pre-compact", "post-tool-use", "subagent-stop", "stop"]


def test_registry_complete():
    # 8 base + 19 variants, every entry a Sound subclass
    assert len(SOUNDS) == 27
    assert set(BASE) <= set(SOUNDS)
    for cls in SOUNDS.values():
        assert isinstance(cls, type) and issubclass(cls, Sound)


def test_note_map_locked_and_valid():
    # notes are (onset_fraction, midi) events, sorted by onset, over one cycle
    assert SOUNDS["stop"].notes[0][1] == 72
    assert SOUNDS["session-start"].notes[0][1] == 48
    assert len(SOUNDS["pre-compact"].notes) == 2  # "[g2,a#2]" -> simultaneous stack
    for name in BASE:
        cls = SOUNDS[name]
        for begin, midi in cls.notes:
            assert 0 <= midi <= 127
            assert 0 <= begin < 1


def test_variants_inherit_base_notes():
    # a variant extends its base event -> shares its note-map
    assert SOUNDS["pre-tool-use-execute"].notes == SOUNDS["pre-tool-use"].notes
    assert SOUNDS["session-start-clear"].notes == SOUNDS["session-start"].notes
    # and it overrides at least one accent knob away from the neutral default
    assert SOUNDS["pre-tool-use-execute"].transpose == -2
