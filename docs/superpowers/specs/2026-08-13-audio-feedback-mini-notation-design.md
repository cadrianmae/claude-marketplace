# Audio-Feedback Mini-Notation — Design Spec

**Date:** 2026-08-13
**Component:** `plugins/audio-feedback/sound-theme/default`
**Status:** Approved design, ready for implementation plan.

## Goal

Author variant note-maps as Strudel-style mini-notation strings
(`phrase("c3 e3 g3 a#3 c4@4")`) instead of raw MIDI/rhythm tuples. Support the
subset of Strudel mini-notation that is meaningful for a **one-shot static
sound** (one rendered cycle → one WAV), rejecting cross-cycle operators with a
clear error. The migration of the existing palette must be **byte-identical**
to the current (post-click-fix) WAVs.

## Background

The palette is a `Sound` class hierarchy in `variants.py`. Each base EVENT
carries a note-map; each VARIANT extends a base event and overrides accent
knobs (`transpose`, `brightness`, …). Today a note-map is
`list[tuple[int, str]]` — `(midi, "quaver"|"crotchet"|"minim")` — and
`synth.render_event` builds onsets by summing per-note `VALUE_SEC` spacings
(quaver 0.12s, crotchet 0.24s, minim 0.48s). Bells ring their natural decay and
overlap; the named value only sets the *spacing to the next note*, so the value
on the **final** note of every phrase is decorative (nothing follows it).

Strudel/TidalCycles mini-notation is a richer, well-known way to write rhythmic
pitch sequences. Its grammar is a PEG (`krill.pegjs`); the Python port `vortex`
implements it with the MIT library `parsimonious` (`vortex/mini/grammar.py`,
131 lines). `parsimonious` parses to an AST cleanly with **no** vortex runtime
(no Qt/OSC/Link). vortex itself is GPLv3 and drags a live-coding stack — we do
NOT depend on it; we depend only on `parsimonious` (MIT) and write our own
one-cycle interpreter against the public grammar.

## Design Decisions (locked)

1. **Timing model: cycle-normalized (pure Strudel).** A sequence fills exactly
   one cycle; onset fractions come from the weighted slot layout.
2. **Tempo knob: `cycle_sec`**, a `Sound` ClassVar (root default), overridable
   per variant — like the other accent knobs.
3. **Ring: onset-only.** Fractional timing sets *onsets*; each bell rings its
   natural decay and overlaps. `@`/`*`/subgroups are purely rhythmic — they
   never clip the ring (which would reopen the truncation click just fixed).
4. **Scope: one-cycle operators only.** Cross-cycle operators
   (`<a b>`, `a|b`, `a?`, `{}%n`, `a/2`) raise a clear `ValueError`. So does
   `a:n` (Strudel sample-index — there are no samples here).
5. **Stacks replace `mode`.** Simultaneity is written `,` in the string
   (`[g2,a#2]`); the `mode="chord"` field is retired.
6. **Migration is byte-identical.** Final long notes are encoded as weights
   (`crotchet`→`@2`, `minim`→`@4`); `cycle_sec = weighted_units × 0.12`. This
   reproduces every current onset exactly.

## Supported Syntax

| token | meaning | status |
|---|---|---|
| `c4 e4 g4` | sequence, fills the cycle | supported |
| `c4` / `a#3` / `eb3` | pitch name → MIDI (C4 = 60) | supported |
| `60` | bare integer = raw MIDI number | supported |
| `~` | rest (advances onset, emits no bell) | supported |
| `[a b]` | subgroup / subdivide a slot | supported |
| `a,b` / `[a,b]` | stack — simultaneous onsets (replaces `mode`) | supported |
| `a@4` | weight — `a` occupies 4 units | supported |
| `a!3` | replicate — `a a a` | supported |
| `a*3` | fast — 3 onsets within `a`'s slot | supported |
| `(3,8)` / `(3,8,1)` | euclid (bjorklund) rhythm | supported |
| `<a b>` `a\|b` `a?` `{a b}%n` `a/2` | cross-cycle | **`ValueError`** |
| `a:n` | Strudel sample-index (no samples here) | **`ValueError`** |

Pitch grammar: letter `a`–`g`, optional `#`/`b`, integer octave. C4 = MIDI 60
(matches `generate.midi_to_name`). Case-insensitive. A bare signed integer is a
raw MIDI number. `~` is a rest.

## Architecture

```
notation.py       note_to_midi()  — pitch-name → MIDI. KEEP.
mininotation.py   NEW. parsimonious grammar + one-cycle interpreter.
                  phrase(spec: str) -> list[tuple[Fraction, int]]   # (onset, midi)
variants.py       Sound gains `cycle_sec`; base events use phrase(...);
                  `mode` field retired; variants unchanged (inherit notes+cycle_sec).
synth.py          render_event: onset_samples = int(SR * float(begin) * cycle_sec)
                  (drops VALUE_SEC; ring = natural decay, onset-only).
tuning.py         VALUE_SEC removed (superseded).
pyproject.toml    add parsimonious (MIT) to [project] dependencies.
generate.py       add parsimonious to the PEP-723 script header.
```

### Interpreter contract

- Input: a mini-notation string (one cycle).
- Output: `list[tuple[Fraction, int]]` — `(onset_fraction_in_[0,1), midi)`,
  sorted by onset. Stacks share an onset. Rests consume span, emit nothing.
- Errors: `ValueError` with a specific message for any cross-cycle operator,
  for `:n`, and for an unparseable string.
- Pure/deterministic: no RNG, no global state (euclid is deterministic).

### `render_event` (synth.py)

```python
events = sound.notes                    # [(Fraction, midi)]
cyc    = sound.cycle_sec
kw     = {accent knobs, as today}
bells  = [render_bell(midi_hz(m + sound.transpose), **kw) for _, m in events]
onsets = [int(SR * float(begin) * cyc) for begin, _ in events]
total  = max(o + len(b) for o, b in zip(onsets, bells))
out    = np.zeros(total, dtype="float32")
for (o, b) in zip(onsets, bells):
    out[o:o + len(b)] += b
return postprocess(out)
```

Single-note and stack sounds have all onsets at fraction 0 → `cycle_sec` does
not move them (byte-identical to today's single/chord onsets at 0).

## Migration (all byte-identical)

Value → weight: quaver = 1 unit, crotchet = `@2`, minim = `@4`.
`cycle_sec = total_weighted_units × 0.12`.

| sound | phrase | cycle_sec |
|---|---|---|
| session-start | `c3 e3 g3 a#3 c4@4` | 0.96 |
| stop | `c5 b4 g4 e4 c4@4` | 0.96 |
| notification | `c4 g4 a#4@2` | 0.48 |
| subagent-stop | `e4 c4@2` | 0.36 |
| pre-compact | `[g2,a#2]` | 0.48 |
| user-prompt-submit | `g4` | 0.12 |
| pre-tool-use | `a#4` | 0.12 |
| post-tool-use | `c5` | 0.12 |

Proof (session-start): weighted units = 4×quaver + minim(4) = 8;
onset_i = `int(44100 · (i/8) · 0.96)` = 0, 5292, 10584, 15876, 21168 =
`int(44100 · i · 0.12)` (the current onsets). Exact.

Variants inherit `notes` and `cycle_sec` from their base event and override
only accent knobs, exactly as today.

## Testing

- **`test_mininotation.py`** (new):
  - each supported operator parses and yields the expected onset fractions
    (sequence, subgroup, stack, weight, replicate, fast, euclid, rest, bare
    MIDI, pitch names);
  - euclid `(3,8)` yields the canonical pulse pattern;
  - each cross-cycle operator and `a:n` raises `ValueError`;
  - the 8 base-event phrases reproduce their exact onset fractions.
- **`test_notation.py`**: rewritten — keep `note_to_midi` cases, drop the old
  `:q/:c/:m` `phrase()` shape.
- **Byte-identity gate (acceptance):** regenerate the palette; md5 of all 28
  WAVs must be **identical** to the committed set. This is the hard gate.
- **Regression:** `test_no_click`, the loudness gate (`analyze.py --palette`),
  and `test_note_map` still pass.

## Dependencies & License

- Add `parsimonious` (MIT) — pure-Python, no build step — to
  `pyproject.toml` `[project].dependencies` and to `generate.py`'s PEP-723
  header. Dev-time only (the generator renders WAVs; runtime playback is
  unaffected).
- Do NOT vendor vortex or its interpreter (GPLv3). The grammar spec is derived
  from the public `krill.pegjs`; the interpreter is our own.

## Out of Scope

- Cross-cycle behaviour (`<> | ? % /`) — inert for a static one-shot; rejected.
- Sample-index `:n` — no sample back-end.
- Live/looping playback — this renders fixed WAV assets.
- Changing any accent knob, the swoosh voice, loudness policy, or the daemon.

## Risks

- **parsimonious AST shape**: the interpreter must walk `parsimonious`
  `Node`/`NodeVisitor` output. Mitigation: the vortex grammar's node names are
  known; write a `NodeVisitor` with explicit `visit_*` methods and unit-test
  each rule.
- **Fraction → sample rounding**: byte-identity depends on
  `int(SR·float(begin)·cyc)` matching `int(SR·Σvalue)`. Proven for the 8
  sounds above; the byte-identity gate catches any drift.
