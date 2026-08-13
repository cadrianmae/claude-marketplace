# Audio-Feedback Mini-Notation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author variant note-maps as Strudel-style mini-notation strings (`phrase("c3 e3 g3 a#3 c4@4")`), parsed to one-cycle event lists, with a byte-identical migration of the existing palette.

**Architecture:** A new `mininotation.py` holds a `parsimonious` (MIT) PEG grammar plus our own one-cycle interpreter that emits `list[tuple[Fraction, int]]` (onset-fraction, MIDI). `notation.py` keeps `note_to_midi`. `synth.render_event` maps onset fractions through a per-sound `cycle_sec` (a new `Sound` ClassVar). Final long notes are weight-encoded so every current onset — and thus every WAV — is reproduced exactly.

**Tech Stack:** Python 3.12, `parsimonious` (MIT), `fractions.Fraction`, signalflow 0.5.3, numpy, pytest, uv.

**Spec:** `docs/superpowers/specs/2026-08-13-audio-feedback-mini-notation-design.md`

## Global Constraints

- Base directory for all paths: `plugins/audio-feedback/`. The uv project root is `plugins/audio-feedback/sound-theme/default/` (has `pyproject.toml`, `.venv`); its `src/` is the import root.
- `C4 = MIDI 60` (matches `generate.midi_to_name`). Pitch: letter `a`–`g`, optional `#`/`b`, signed integer octave. Case-insensitive. A bare signed integer token is a raw MIDI number. `~` is a rest.
- Timing is **cycle-normalized**: a sequence fills one cycle `[0,1)`; onset fractions follow the weighted slot layout. `render_event` multiplies by `sound.cycle_sec`.
- **Ring is onset-only**: fractional timing sets onsets; bells ring their natural decay and overlap. No operator clips the ring.
- **One-cycle scope**: support `[]` subgroup, `,` stack, `@` weight, `!` replicate, `*` fast, `~` rest, `(k,n[,r])` euclid, pitch names, bare MIDI. The cross-cycle operators `<a b>`, `a|b`, `a?`, `{a b}%n`, `a/n` and the sample-index `a:n` MUST raise `ValueError` with a specific message naming the operator. Never render them silently.
- **Stacks replace `mode`**: the `mode="chord"` field is removed; simultaneity is `,` in the string.
- **Byte-identity is the acceptance gate**: after migration, `md5sum` of all 28 WAVs in `sound-theme/default/sounds/` MUST be identical to the committed set at plan start (HEAD `6a52847`). Record the baseline md5s before Task 4.
- **License**: depend only on `parsimonious` (MIT). Do NOT vendor vortex or its interpreter (GPLv3). The grammar is our own, derived from the public `krill.pegjs`.
- `notation.py` owns `note_to_midi`; `mininotation.py` owns the grammar, interpreter, and `phrase()`.
- basedpyright "standard" mode must stay clean (config in `sound-theme/default/pyproject.toml`). Prefer `X | None` over `Optional`.
- Run tests with the project venv: `sound-theme/default/.venv/bin/python -m pytest ...` from `plugins/audio-feedback/`.

---

### Task 1: `note_to_midi` in `notation.py`

**Files:**
- Create: `sound-theme/default/src/notation.py`
- Test: `tests/test_notation.py`

**Interfaces:**
- Produces: `note_to_midi(name: str) -> int` — scientific-pitch name to MIDI. `"c4"->60`, `"a#3"->58`, `"bb3"->58`, `"g2"->43`, `"c-1"->0`. Raises `ValueError` on a bad name.

- [ ] **Step 1: Write the failing test**

`tests/test_notation.py`:
```python
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
```

- [ ] **Step 2: Run it, verify it fails**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_notation.py -q`
Expected: FAIL (`ModuleNotFoundError: notation`).

- [ ] **Step 3: Write `notation.py`**

```python
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
```

- [ ] **Step 4: Run tests, verify pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_notation.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/notation.py plugins/audio-feedback/tests/test_notation.py
git commit -m "feat(audio-feedback): note_to_midi pitch-name parser"
```

---

### Task 2: `parsimonious` grammar + parse to AST in `mininotation.py`

**Files:**
- Create: `sound-theme/default/src/mininotation.py`
- Modify: `sound-theme/default/pyproject.toml` (add `parsimonious` dep)
- Modify: `sound-theme/default/src/generate.py` (PEP-723 header: add `parsimonious`)
- Test: `tests/test_mininotation_parse.py`

**Interfaces:**
- Produces: `parse(spec: str) -> Node` — parses a mini-notation string into a normalized node tree. `Node` is one of the dataclasses below. Raises `parsimonious.exceptions.ParseError` (or a wrapped `ValueError`) on unparseable input. Semantic rejection of cross-cycle operators happens in Task 3 (the interpreter), but the grammar MUST still *parse* `<>`, `|`, `?`, `{}%`, `/`, `:n` so the interpreter can name them in its error.

**Node model** (module-level dataclasses, used by Tasks 2 & 3):
```python
from dataclasses import dataclass, field

@dataclass
class Seq:      steps: list                       # ordered; each is (node, weight:int)
@dataclass
class Stack:    seqs: list                        # parallel sequences
@dataclass
class Atom:     midi: int | None                  # None = rest
@dataclass
class Fast:     child: object; n: int
@dataclass
class Euclid:   child: object; k: int; n: int; rot: int = 0
@dataclass
class Reject:   sym: str                          # a parsed-but-unsupported op (<> | ? {}% / :n)
```

- [ ] **Step 1: Add the dependency**

In `sound-theme/default/pyproject.toml`, add to `[project].dependencies`:
```toml
dependencies = ["signalflow==0.5.3", "numpy", "scipy", "parsimonious"]
```
In `sound-theme/default/src/generate.py`, add `"parsimonious"` to the PEP-723 `dependencies` list in the `# /// script` header.
Then: `cd sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uv sync`

- [ ] **Step 2: Write the failing parse test**

`tests/test_mininotation_parse.py`:
```python
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
```

- [ ] **Step 3: Run it, verify it fails**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_mininotation_parse.py -q`
Expected: FAIL (`ModuleNotFoundError: mininotation`).

- [ ] **Step 4: Write the grammar + visitor in `mininotation.py`**

Start from this grammar (adapted from the public krill/vortex grammar; iterate against the tests). Use `parsimonious`'s `Grammar` + a `NodeVisitor`. The visitor lowers the parse tree into the `Seq/Stack/Atom/Fast/Euclid/Reject` node model, applying `note_to_midi` for pitch names, `int` for bare MIDI, `None` for `~`, expanding `!n` into repeated steps, and attaching `@n` weights.

```python
from dataclasses import dataclass
from parsimonious.grammar import Grammar
from parsimonious.nodes import NodeVisitor

from notation import note_to_midi

# ---- node model (see Interfaces) ----
@dataclass
class Seq:    steps: list
@dataclass
class Stack:  seqs: list
@dataclass
class Atom:   midi: "int | None"
@dataclass
class Fast:   child: object; n: int
@dataclass
class Euclid: child: object; k: int; n: int; rot: int = 0
@dataclass
class Reject: sym: str

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
```

Visitor design (implement each `visit_*` to return nodes; keys to get right):
- `visit_note` → `Atom(note_to_midi(text))`; `visit_number` used both as a bare-MIDI term (→ `Atom(int)`) and as an operator argument — disambiguate by grammar position (a `number` reached via `term` is an Atom; via `weight`/`euclid`/`fast` it is an int argument).
- `visit_rest` → `Atom(None)`.
- `visit_group` → `Seq` of `(node, weight)`; default weight 1. Apply ops to the element: `@n` sets that step's weight; `!n` expands into `n` copies (each weight 1); `*n` wraps the node in `Fast(node, n)`; `(k,n[,r])` wraps in `Euclid(node, k, n, r)`.
- `visit_stack` → if one group, return it; else `Stack([...])`.
- `visit_choose` → if one stack, return it; else `Reject("|")` wrapping is not needed — represent the choose itself as `Reject("|")` (its children are unreachable in one cycle). Similarly `angle` → `Reject("<>")`, `polymeter` → `Reject("{}%")`, `slow` op → mark the element `Reject("/")`, `degrade` op → `Reject("?")`, `index` op → `Reject(":n")`.
- A `Reject` node parses successfully and is surfaced so Task 3 raises with the exact `sym`.

Keep the visitor small and test-driven; the grammar above may need tweaks (e.g. ordering of `op` alternatives, optional octave) — fix against the Step 2 tests.

- [ ] **Step 5: Run tests, verify pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_mininotation_parse.py -q`
Expected: PASS. Then confirm basedpyright is clean: `cd sound-theme/default && uvx basedpyright src/mininotation.py src/notation.py`.

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/mininotation.py \
        plugins/audio-feedback/sound-theme/default/pyproject.toml \
        plugins/audio-feedback/sound-theme/default/src/generate.py \
        plugins/audio-feedback/sound-theme/default/uv.lock \
        plugins/audio-feedback/tests/test_mininotation_parse.py
git commit -m "feat(audio-feedback): mini-notation grammar + parse to AST"
```

---

### Task 3: One-cycle interpreter + `phrase()` in `mininotation.py`

**Files:**
- Modify: `sound-theme/default/src/mininotation.py`
- Test: `tests/test_mininotation.py`

**Interfaces:**
- Consumes: `parse()` and the node model from Task 2; `note_to_midi` (indirectly).
- Produces:
  - `bjorklund(k: int, n: int) -> list[bool]` — euclidean rhythm, length `n`, first slot a pulse. `bjorklund(3, 8) == [True,False,False,True,False,False,True,False]`.
  - `phrase(spec: str) -> list[tuple[Fraction, int]]` — parse + interpret one cycle; events sorted by onset; stacks share an onset; rests emit nothing. Raises `ValueError` naming any cross-cycle operator or `:n`.

- [ ] **Step 1: Write the failing interpreter tests**

`tests/test_mininotation.py`:
```python
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
```

- [ ] **Step 2: Run it, verify it fails**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_mininotation.py -q`
Expected: FAIL (`ImportError: cannot import name 'phrase'`).

- [ ] **Step 3: Implement `bjorklund`, `_emit`, `phrase`**

Append to `mininotation.py`:
```python
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
```

- [ ] **Step 4: Run tests, verify pass**

Run: `sound-theme/default/.venv/bin/python -m pytest tests/test_mininotation.py -q`
Expected: PASS. If euclid rotation differs, adjust `bjorklund` so `(3,8)` matches the asserted pattern.

- [ ] **Step 5: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/mininotation.py \
        plugins/audio-feedback/tests/test_mininotation.py
git commit -m "feat(audio-feedback): one-cycle mini-notation interpreter + phrase()"
```

---

### Task 4: Integrate — `cycle_sec`, `render_event`, migrate palette, byte-identity gate

**Files:**
- Modify: `sound-theme/default/src/variants.py`
- Modify: `sound-theme/default/src/synth.py`
- Modify: `sound-theme/default/src/tuning.py` (remove `VALUE_SEC`)
- Test: `tests/test_note_map.py` (update to new note shape if it inspects `notes`)

**Interfaces:**
- Consumes: `phrase()` from `mininotation`.
- Produces: `Sound.cycle_sec: ClassVar[float]`; `Sound.notes: ClassVar[list[tuple[Fraction, int]]]`; `render_event` reading fractional onsets.

- [ ] **Step 1: Record the byte-identity baseline**

From `plugins/audio-feedback/`:
```bash
md5sum sound-theme/default/sounds/*.wav > /tmp/palette-baseline.md5
```

- [ ] **Step 2: Write the failing byte-identity test**

`tests/test_note_map.py` — add (or a new `tests/test_byte_identity.py`):
```python
import os, subprocess, hashlib, glob, sys, pytest
HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
SOUNDS = os.path.join(PLUGIN, "sound-theme", "default", "sounds")

BASELINE = {   # md5s captured at plan start (HEAD 6a52847); fill from Step 1
    # "session-start.wav": "....",
}

@pytest.mark.skipif(not BASELINE, reason="baseline md5s not recorded")
def test_palette_byte_identical():
    env = dict(os.environ, UV_PYTHON_PREFERENCE="only-managed")
    subprocess.run(["uv", "run", "--script", GEN], cwd=PLUGIN, check=True, env=env)
    for name, want in BASELINE.items():
        got = hashlib.md5(open(os.path.join(SOUNDS, name), "rb").read()).hexdigest()
        assert got == want, f"{name} changed"
```
Paste the real md5s from Step 1 into `BASELINE`.

- [ ] **Step 3: Migrate `variants.py`**

- Add to `Sound`: `cycle_sec: ClassVar[float] = 0.12` and change the `notes` annotation to `list[tuple[Fraction, int]]` (import `Fraction`). Import `phrase`. Remove the `mode` field.
- Rewrite the 8 base events (delete `mode="chord"` on `PreCompact`):
```python
from fractions import Fraction  # noqa: F401  (annotation)
from mininotation import phrase

class SessionStart(Sound):     notes = phrase("c3 e3 g3 a#3 c4@4"); cycle_sec = 0.96
class UserPromptSubmit(Sound): notes = phrase("g4");                 cycle_sec = 0.12
class PreToolUse(Sound):       notes = phrase("a#4");                cycle_sec = 0.12
class Notification(Sound):     notes = phrase("c4 g4 a#4@2");        cycle_sec = 0.48
class PreCompact(Sound):       notes = phrase("[g2,a#2]");           cycle_sec = 0.48
class PostToolUse(Sound):      notes = phrase("c5");                 cycle_sec = 0.12
class SubagentStop(Sound):     notes = phrase("e4 c4@2");            cycle_sec = 0.36
class Stop(Sound):             notes = phrase("c5 b4 g4 e4 c4@4");   cycle_sec = 0.96
```
- Update the module docstring: `notes` is a mini-notation string via `phrase(...)`; `cycle_sec` is the per-sound cycle length; `,` = simultaneous (no more `mode`). Keep the accent-knob list.
- Remove `mode` references anywhere in the file.

- [ ] **Step 4: Update `synth.render_event` and remove `mode`/`VALUE_SEC`**

Replace the onset-building block in `render_event`:
```python
    events = sound.notes                       # [(Fraction, midi)]
    cyc = sound.cycle_sec
    bells = [render_bell(midi_hz(m + sound.transpose), **kw) for _, m in events]
    onsets = [int(SR * float(begin) * cyc) for begin, _ in events]
    total = max(o + len(b) for o, b in zip(onsets, bells))
    out = np.zeros(total, dtype="float32")
    for bell, o in zip(bells, onsets):
        out[o:o + len(bell)] += bell
    return postprocess(out)
```
Delete the old `notes`/`onsets`/`mode`/`VALUE_SEC` logic. Remove `VALUE_SEC` from `tuning.py`. `render_swoosh` and the `voice=="swoosh"` dispatch are unchanged.

- [ ] **Step 5: Run the byte-identity gate + regressions**

Run, from `plugins/audio-feedback/`:
```bash
sound-theme/default/.venv/bin/python -m pytest tests/test_note_map.py tests/test_no_click.py -q
sound-theme/default/.venv/bin/python scripts/analyze.py --palette sound-theme/default/sounds
git diff --stat -- sound-theme/default/sounds   # expect: NO wav changes
```
Expected: byte-identity test PASS, `test_no_click` PASS, loudness gate PASS, and `git diff` shows **zero** changed WAVs. If any WAV differs, the migration's `cycle_sec`/weights are wrong — fix before proceeding (do not regenerate-and-accept).

- [ ] **Step 6: Commit**

```bash
git add plugins/audio-feedback/sound-theme/default/src/variants.py \
        plugins/audio-feedback/sound-theme/default/src/synth.py \
        plugins/audio-feedback/sound-theme/default/src/tuning.py \
        plugins/audio-feedback/tests/test_note_map.py
git commit -m "feat(audio-feedback): drive palette from mini-notation (byte-identical)"
```

---

## Notes for the executor

- The euclid pattern orientation in `bjorklund` may need a rotation tweak to match `(3,8) = x..x..x.`; the Task 3 test pins it.
- `parsimonious` returns its own `Node` tree; the `NodeVisitor` in Task 2 is where most iteration happens — lean on the Step 2 parse tests.
- Byte-identity depends only on onset sample indices (`int(SR·float(begin)·cyc)`) matching the old `int(SR·Σvalue)`; the accent knobs and `postprocess` are untouched, so equal onsets ⇒ equal WAVs.
- After Task 4, `mininotation.py`, `notation.py`, and the three new/updated test files are the whole feature; the swoosh voice, loudness policy, daemon, and dashboard are untouched.
