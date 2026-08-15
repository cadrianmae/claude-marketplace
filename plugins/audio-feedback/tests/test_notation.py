import os, sys
import pytest

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "sound-theme", "default", "src")
sys.path.insert(0, os.path.abspath(SRC))

from notation import note_to_midi  # noqa: E402


@pytest.mark.parametrize("name,midi", [
    ("c4", 60), ("C4", 60), ("a#3", 58), ("bb3", 58),
    ("g2", 43), ("c5", 72), ("b4", 71), ("c-1", 0), ("a4", 69),
])
def test_note_to_midi(name, midi):
    assert note_to_midi(name) == midi


@pytest.mark.parametrize("bad", ["h4", "", "c", "4", "c#", "x"])
def test_note_to_midi_rejects(bad):
    with pytest.raises(ValueError):
        note_to_midi(bad)
