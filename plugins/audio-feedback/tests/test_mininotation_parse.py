import os, sys
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "sound-theme", "default", "src")
sys.path.insert(0, os.path.abspath(SRC))

import pytest
from mininotation import parse, Seq, Stack, Atom, Fast, Euclid, Reject


def test_sequence_of_notes():
    node = parse("c4 e4 g4")
    assert isinstance(node, Seq)
    assert [w for _, w in node.steps] == [1, 1, 1]
    assert [s.midi for s, _ in node.steps] == [60, 64, 67]

def test_bare_midi_and_rest():
    node = parse("60 ~ 62")
    kinds = [s.midi for s, _ in node.steps]
    assert kinds == [60, None, 62]

def test_weight():
    node = parse("c4 e4@3")
    assert [w for _, w in node.steps] == [1, 3]

def test_replicate_expands():
    node = parse("c4!3")
    assert [s.midi for s, _ in node.steps] == [60, 60, 60]

def test_subgroup_is_nested_seq():
    node = parse("c4 [e4 g4]")
    sub = node.steps[1][0]
    assert isinstance(sub, Seq) and [s.midi for s, _ in sub.steps] == [64, 67]

def test_stack():
    node = parse("[c4,e4,g4]")
    inner = node.steps[0][0]
    assert isinstance(inner, Stack) and len(inner.seqs) == 3

def test_fast_and_euclid_nodes():
    assert isinstance(parse("c4*2").steps[0][0], Fast)
    assert isinstance(parse("c4(3,8)").steps[0][0], Euclid)

@pytest.mark.parametrize("spec,sym", [
    ("<c4 e4>", "<>"), ("c4|e4", "|"), ("c4?", "?"),
    ("{c4 e4}%3", "{}%"), ("c4/2", "/"), ("c4:3", ":n"),
])
def test_rejected_ops_parse_to_Reject(spec, sym):
    # they must parse (so the interpreter can name them), surfacing a Reject node
    node = parse(spec)
    found = _find_reject(node)
    assert found is not None and found.sym == sym

def _find_reject(n):
    from mininotation import Seq, Stack, Reject, Fast, Euclid
    if isinstance(n, Reject): return n
    if isinstance(n, Seq):
        for s, _ in n.steps:
            r = _find_reject(s)
            if r: return r
    if isinstance(n, Stack):
        for s in n.seqs:
            r = _find_reject(s)
            if r: return r
    if isinstance(n, (Fast, Euclid)):
        return _find_reject(n.child)
    return None
