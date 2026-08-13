"""Scientific-pitch note-name parsing (C4 = MIDI 60)."""
import re

_LETTER = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
_ACCIDENTAL = {"": 0, "#": 1, "b": -1}
_NAME = re.compile(r"([a-gA-G])([#b]?)(-?\d+)$")


def note_to_midi(name: str) -> int:
    """Scientific-pitch name -> MIDI number. 'c4' -> 60, 'a#3' -> 58."""
    m = _NAME.fullmatch(name.strip())
    if not m:
        raise ValueError(f"bad note name: {name!r}")
    letter, acc, octave = m.group(1).lower(), m.group(2), int(m.group(3))
    return (octave + 1) * 12 + _LETTER[letter] + _ACCIDENTAL[acc]
