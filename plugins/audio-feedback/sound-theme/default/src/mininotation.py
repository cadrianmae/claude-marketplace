"""Strudel-style mini-notation parser -> normalized AST.

Parses a mini-notation spec string (e.g. "c4 e4 [g4 b4]*2") into the
Seq/Stack/Atom/Fast/Euclid/Reject node model. Cross-cycle constructs
(<>, |, ?, {}%, /, :n) still parse successfully but surface as Reject
nodes -- rejecting them semantically is the interpreter's job (Task 3).
"""
from dataclasses import dataclass

from parsimonious.grammar import Grammar
from parsimonious.nodes import NodeVisitor

from notation import note_to_midi

# ---- node model (see task brief "Interfaces") ----


@dataclass
class Seq:
    steps: list  # ordered; each is (node, weight:int)


@dataclass
class Stack:
    seqs: list  # parallel sequences


@dataclass
class Atom:
    midi: "int | None"  # None = rest


@dataclass
class Fast:
    child: object
    n: int


@dataclass
class Euclid:
    child: object
    k: int
    n: int
    rot: int = 0


@dataclass
class Reject:
    sym: str  # a parsed-but-unsupported op (<> | ? {}% / :n)


GRAMMAR = Grammar(r"""
    root      = ws? choose ws?
    choose    = stack (ws? "|" ws? stack)*
    stack     = group (ws? "," ws? group)*
    group     = element (ws element)*
    element   = value ops
    ops       = op*
    op        = euclid / fast / slow / replicate / degrade / weight / index
    value     = subgroup / polymeter / angle / term
    subgroup  = "[" ws? choose ws? "]"
    polymeter = "{" ws? choose ws? "}" psteps?
    psteps    = "%" number
    angle     = "<" ws? choose ws? ">"
    term      = rest / note / number
    rest      = "~"
    note      = ~"[a-gA-G][#b]?-?[0-9]+"
    number    = ~"-?[0-9]+"
    fast      = "*" value
    slow      = "/" value
    replicate = "!" number?
    degrade   = "?" number?
    weight    = "@" number
    euclid    = "(" ws? number ws? "," ws? number (ws? "," ws? number)? ws? ")"
    index     = ":" number
    ws        = ~"\s+"
""")


class MiniNotationVisitor(NodeVisitor):
    """Lowers the parsimonious parse tree into Seq/Stack/Atom/Fast/Euclid/Reject."""

    def generic_visit(self, node, visited_children):
        return visited_children or node.text

    # ---- terms ----

    def visit_root(self, node, visited_children):
        _, choose, _ = visited_children
        return choose

    def visit_note(self, node, visited_children):
        return Atom(note_to_midi(node.text))

    def visit_number(self, node, visited_children):
        # bare-MIDI term (via term) -> Atom(int); operator arg (via
        # weight/euclid/fast/replicate/degrade/index/psteps) -> plain int.
        # Callers that need the int extract it themselves; this default
        # (used when `number` is reached directly, i.e. as a term) is Atom.
        return int(node.text)

    def visit_rest(self, node, visited_children):
        return Atom(None)

    def visit_term(self, node, visited_children):
        (child,) = visited_children
        if isinstance(child, int):
            return Atom(child)
        return child

    # ---- value ----

    def visit_value(self, node, visited_children):
        (child,) = visited_children
        return child

    def visit_subgroup(self, node, visited_children):
        _, _, choose, _, _ = visited_children
        return choose

    def visit_polymeter(self, node, visited_children):
        return Reject("{}%")

    def visit_angle(self, node, visited_children):
        return Reject("<>")

    # ---- ops ----

    def visit_ops(self, node, visited_children):
        # list of op results (each a callable-ish descriptor), in source order
        return visited_children

    def visit_op(self, node, visited_children):
        (child,) = visited_children
        return child

    def visit_fast(self, node, visited_children):
        _, value = visited_children
        return ("fast", value)

    def visit_slow(self, node, visited_children):
        return ("slow",)

    def visit_replicate(self, node, visited_children):
        _, maybe_n = visited_children
        return ("replicate", _first_or(maybe_n, 2))

    def visit_degrade(self, node, visited_children):
        return ("degrade",)

    def visit_weight(self, node, visited_children):
        _, n = visited_children
        return ("weight", n)

    def visit_euclid(self, node, visited_children):
        (
            _lp, _ws1, k, _ws2, _comma1, _ws3, n, rot_opt, _ws4, _rp
        ) = visited_children
        rot = 0
        if isinstance(rot_opt, list) and rot_opt:
            # rot_opt = [(ws?, ",", ws?, number)] flattened by generic_visit
            triple = rot_opt[0]
            # find the trailing int in the flattened children
            for item in triple if isinstance(triple, list) else [triple]:
                if isinstance(item, int):
                    rot = item
        return ("euclid", k, n, rot)

    def visit_index(self, node, visited_children):
        return ("index",)

    # ---- element / group / stack / choose ----

    def visit_element(self, node, visited_children):
        value, ops = visited_children
        node_val = value
        weight = 1
        replicate_n = None
        for op in ops:
            kind = op[0]
            if kind == "fast":
                node_val = Fast(child=node_val, n=_as_int(op[1]))
            elif kind == "slow":
                node_val = Reject("/")
            elif kind == "replicate":
                replicate_n = op[1]
            elif kind == "degrade":
                node_val = Reject("?")
            elif kind == "weight":
                weight = _as_int(op[1])
            elif kind == "euclid":
                node_val = Euclid(
                    child=node_val, k=_as_int(op[1]), n=_as_int(op[2]), rot=_as_int(op[3])
                )
            elif kind == "index":
                node_val = Reject(":n")
        if replicate_n is not None:
            return [(node_val, 1)] * replicate_n
        return [(node_val, weight)]

    def visit_group(self, node, visited_children):
        first, rest = visited_children
        steps = list(first)
        for pair in rest:
            # pair = (ws, element_steps)
            _, elem_steps = pair
            steps.extend(elem_steps)
        return Seq(steps=steps)

    def visit_stack(self, node, visited_children):
        first, rest = visited_children
        groups = [first]
        for pair in rest:
            _, _, _, group = pair
            groups.append(group)
        if len(groups) == 1:
            return groups[0]
        return Stack(seqs=groups)

    def visit_choose(self, node, visited_children):
        first, rest = visited_children
        if not rest:
            return first
        return Reject("|")


def _as_int(v) -> int:
    if isinstance(v, Atom):
        assert v.midi is not None
        return v.midi
    assert isinstance(v, int)
    return v


def _first_or(maybe, default):
    if isinstance(maybe, list) and maybe:
        val = maybe[0]
        return val if isinstance(val, int) else default
    return default


def parse(spec: str):
    tree = GRAMMAR.parse(spec)
    return MiniNotationVisitor().visit(tree)


from fractions import Fraction


def bjorklund(k: int, n: int) -> list[bool]:
    """Euclidean rhythm: k pulses over n steps, first step a pulse."""
    if n <= 0:
        return []
    if k <= 0:
        return [False] * n
    if k >= n:
        return [True] * n
    counts: list[int] = []
    remainders = [k]
    divisor = n - k
    level = 0
    while remainders[level] > 1:
        counts.append(divisor // remainders[level])
        remainders.append(divisor % remainders[level])
        divisor = remainders[level]
        level += 1
    counts.append(divisor)
    pattern: list[bool] = []

    def build(lvl: int) -> None:
        if lvl == -1:
            pattern.append(False)
        elif lvl == -2:
            pattern.append(True)
        else:
            for _ in range(counts[lvl]):
                build(lvl - 1)
            if remainders[lvl] != 0:
                build(lvl - 2)

    build(level)
    i = pattern.index(True)          # rotate so a pulse starts the cycle
    return pattern[i:] + pattern[:i]


def _emit(node: object, begin: Fraction, end: Fraction,
          out: list[tuple[Fraction, int]]) -> None:
    if isinstance(node, Reject):
        raise ValueError(f"{node.sym!r} is a cross-cycle/sample operator with no "
                         f"meaning in a one-shot sound")
    if isinstance(node, Atom):
        if node.midi is not None:
            out.append((begin, node.midi))
        return
    if isinstance(node, Seq):
        total = sum(w for _, w in node.steps) or 1
        pos = begin
        span = end - begin
        for child, w in node.steps:
            nxt = pos + span * Fraction(w, total)
            _emit(child, pos, nxt, out)
            pos = nxt
        return
    if isinstance(node, Stack):
        for seq in node.seqs:
            _emit(seq, begin, end, out)
        return
    if isinstance(node, Fast):
        span = (end - begin) / node.n
        for j in range(node.n):
            _emit(node.child, begin + span * j, begin + span * (j + 1), out)
        return
    if isinstance(node, Euclid):
        pat = bjorklund(node.k, node.n)
        span = (end - begin) / node.n
        for j, on in enumerate(pat):
            if on:
                _emit(node.child, begin + span * j, begin + span * (j + 1), out)
        return
    raise TypeError(f"unhandled node: {node!r}")


def phrase(spec: str) -> list[tuple[Fraction, int]]:
    """Parse a mini-notation string, interpret one cycle -> (onset, midi) events."""
    out: list[tuple[Fraction, int]] = []
    _emit(parse(spec), Fraction(0), Fraction(1), out)
    out.sort(key=lambda ev: ev[0])
    return out
