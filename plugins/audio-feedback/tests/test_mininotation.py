import os, sys
from fractions import Fraction as F
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "sound-theme", "default", "src")
sys.path.insert(0, os.path.abspath(SRC))

import pytest
from mininotation import phrase, bjorklund


def om(spec):
    """(onset, midi) pairs — drops duration."""
    return [(b, m) for b, m, _ in phrase(spec)]


def durs(spec):
    """per-note durations (fraction of the cycle)."""
    return [d for _, _, d in phrase(spec)]


def onsets(spec):
    return [b for b, _, _ in phrase(spec)]


def test_even_sequence_onsets():
    assert om("c4 e4 g4") == [(F(0), 60), (F(1, 3), 64), (F(2, 3), 67)]

def test_rest_holds_its_slot():
    assert om("c4 ~ g4") == [(F(0), 60), (F(2, 3), 67)]

def test_weight_shifts_later_onsets():
    # c4 takes 2 of 3 units, e4 the last
    assert om("c4@2 e4") == [(F(0), 60), (F(2, 3), 64)]

def test_subgroup_subdivides():
    # c4 fills [0,1/2); [e4 g4] splits [1/2,1)
    assert om("c4 [e4 g4]") == [(F(0), 60), (F(1, 2), 64), (F(3, 4), 67)]

def test_stack_shares_onset():
    assert sorted(om("[c4,e4,g4]")) == [(F(0), 60), (F(0), 64), (F(0), 67)]

def test_fast_repeats_in_slot():
    assert om("c4*2 e4") == [(F(0), 60), (F(1, 4), 60), (F(1, 2), 64)]

def test_replicate():
    assert om("c4!2 e4") == [(F(0), 60), (F(1, 3), 60), (F(2, 3), 64)]

def test_euclid_pattern():
    assert bjorklund(3, 8) == [True, False, False, True, False, False, True, False]
    assert onsets("c4(3,8)") == [F(0), F(3, 8), F(6, 8)]

def test_euclid_rotation():
    # bjorklund(3,8) = [T,F,F,T,F,F,T,F]; left-rotate by 1 -> [F,F,T,F,F,T,F,T]
    assert onsets("c4(3,8,1)") == [F(2, 8), F(5, 8), F(7, 8)]

def test_bare_midi():
    assert om("60 64") == [(F(0), 60), (F(1, 2), 64)]


# ---- duration = each note's slot span (drives sustain in render_event) ----

def test_duration_is_the_slot_span():
    assert durs("c4 e4") == [F(1, 2), F(1, 2)]
    assert durs("c4@2 e4") == [F(2, 3), F(1, 3)]
    assert durs("c4 [e4 g4]") == [F(1, 2), F(1, 4), F(1, 4)]

def test_stack_notes_span_the_whole_slot():
    assert durs("[c4,e4]") == [F(1), F(1)]


# ---- `_` hold and bare `@` (both Strudel-native elongation) ----

def test_bare_at_is_weight_two():
    # bare @ == @2 (Strudel default)
    assert phrase("c4@ e4") == phrase("c4@2 e4")
    assert durs("c4@ e4") == [F(2, 3), F(1, 3)]

def test_hold_elongates_previous():
    # `c4 _ _ e4`: each `_` adds one unit to c4 -> weight 3, e4 weight 1, total 4
    assert om("c4 _ _ e4") == [(F(0), 60), (F(3, 4), 64)]
    assert durs("c4 _ _ e4") == [F(3, 4), F(1, 4)]

def test_single_hold():
    # `c4 _ e4`: c4 weight 2, e4 weight 1, total 3
    assert om("c4 _ e4") == [(F(0), 60), (F(2, 3), 64)]


@pytest.mark.parametrize("spec,frag", [
    ("<c4 e4>", "<>"), ("c4|e4", "|"), ("c4?", "?"),
    ("{c4 e4}%3", "{}%"), ("c4/2", "/"), ("c4:3", ":"),
])
def test_cross_cycle_rejected(spec, frag):
    with pytest.raises(ValueError) as e:
        phrase(spec)
    assert frag in str(e.value)


# The 8 base events reproduce their exact onset fractions.
BASE = {
    "c3 e3 g3 a#3 c4@4": [F(0), F(1, 8), F(2, 8), F(3, 8), F(4, 8)],
    "c5 b4 g4 e4 c4@4":  [F(0), F(1, 8), F(2, 8), F(3, 8), F(4, 8)],
    "c4 g4 a#4@2":       [F(0), F(1, 4), F(2, 4)],
    "e4 c4@2":           [F(0), F(1, 3)],
    "g4":                [F(0)],
}
@pytest.mark.parametrize("spec,expected", list(BASE.items()))
def test_base_event_onsets(spec, expected):
    assert onsets(spec) == expected
