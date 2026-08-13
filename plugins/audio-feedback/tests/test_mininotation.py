import os, sys
from fractions import Fraction as F
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "sound-theme", "default", "src")
sys.path.insert(0, os.path.abspath(SRC))

import pytest
from mininotation import phrase, bjorklund


def test_even_sequence_onsets():
    assert phrase("c4 e4 g4") == [(F(0), 60), (F(1, 3), 64), (F(2, 3), 67)]

def test_rest_holds_its_slot():
    assert phrase("c4 ~ g4") == [(F(0), 60), (F(2, 3), 67)]

def test_weight_shifts_later_onsets():
    # c4 takes 2 of 3 units, e4 the last
    assert phrase("c4@2 e4") == [(F(0), 60), (F(2, 3), 64)]

def test_subgroup_subdivides():
    # c4 fills [0,1/2); [e4 g4] splits [1/2,1)
    assert phrase("c4 [e4 g4]") == [(F(0), 60), (F(1, 2), 64), (F(3, 4), 67)]

def test_stack_shares_onset():
    assert sorted(phrase("[c4,e4,g4]")) == [(F(0), 60), (F(0), 64), (F(0), 67)]

def test_fast_repeats_in_slot():
    assert phrase("c4*2 e4") == [(F(0), 60), (F(1, 4), 60), (F(1, 2), 64)]

def test_replicate():
    assert phrase("c4!2 e4") == [(F(0), 60), (F(1, 3), 60), (F(2, 3), 64)]

def test_euclid_pattern():
    assert bjorklund(3, 8) == [True, False, False, True, False, False, True, False]
    # c4(3,8): pulses at slots 0,3,6 of 8
    onsets = [b for b, _ in phrase("c4(3,8)")]
    assert onsets == [F(0), F(3, 8), F(6, 8)]

def test_bare_midi():
    assert phrase("60 64") == [(F(0), 60), (F(1, 2), 64)]

@pytest.mark.parametrize("spec,frag", [
    ("<c4 e4>", "<>"), ("c4|e4", "|"), ("c4?", "?"),
    ("{c4 e4}%3", "{}%"), ("c4/2", "/"), ("c4:3", ":"),
])
def test_cross_cycle_rejected(spec, frag):
    with pytest.raises(ValueError) as e:
        phrase(spec)
    assert frag in str(e.value)

# The 8 base events reproduce their exact onset fractions (drives Task 4 byte-identity).
BASE = {
    "c3 e3 g3 a#3 c4@4": [F(0), F(1, 8), F(2, 8), F(3, 8), F(4, 8)],
    "c5 b4 g4 e4 c4@4":  [F(0), F(1, 8), F(2, 8), F(3, 8), F(4, 8)],
    "c4 g4 a#4@2":       [F(0), F(1, 4), F(2, 4)],
    "e4 c4@2":           [F(0), F(1, 3)],
    "g4":                [F(0)],
}
@pytest.mark.parametrize("spec,onsets", list(BASE.items()))
def test_base_event_onsets(spec, onsets):
    assert [b for b, _ in phrase(spec)] == onsets
