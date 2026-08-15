# `phrase()` mini-notation reference

Author a sound's note-map as a Strudel-style string in `variants.py`:
`notes = phrase("c3 e3 g3 a#3 c4@4")`. Parsed by `src/mininotation.py` into
`(onset_fraction, midi)` events over one cycle, scaled to seconds by the
sound's `cycle_sec`.

## Pitch tokens

| token | means | -> MIDI |
|---|---|---|
| `c4` | note name: letter + octave (C4 = 60) | 60 |
| `a#3` | sharp | 58 |
| `eb3` `bb3` | flat (`b` = flat; letter `b` = note B) | 51, 58 |
| `C4` | letter is case-insensitive | 60 |
| `60` | bare integer = raw MIDI number | 60 |
| `c-1` | negative octave | 0 |
| `~` | rest (holds its slot, no sound) | -- |

Octave is required on names (`c4`, not `c`). Accidentals are lowercase `#`/`b`.

## Structure & operators

| token | means | example -> onsets (fraction of cycle) |
|---|---|---|
| `a b c` | sequence, splits the cycle evenly | `c4 e4 g4` -> 0, 1/3, 2/3 |
| `[a b]` | subgroup -- subdivides one slot | `c4 [e4 g4]` -> 0, 1/2, 3/4 |
| `a,b` | stack -- simultaneous (replaces old `mode=chord`) | `[c4,e4,g4]` -> 0, 0, 0 |
| `a@n` | weight -- `a` takes n slots (bare `@` = 2) | `c4@2 e4` -> 0, 2/3 |
| `a _` | hold -- each `_` adds one slot to the previous note | `c4 _ _ e4` -> 0, 3/4 |
| `a!n` | replicate -- n copies (bare `!` = 2) | `c4!2 e4` -> 0, 1/3, 2/3 |
| `a*n` | fast -- n copies inside a's slot | `c4*2 e4` -> 0, 1/4, 1/2 |
| `(k,n)` | euclid -- k pulses over n slots | `c4(3,8)` -> 0, 3/8, 6/8 |
| `(k,n,r)` | euclid + left-rotate by r | `c4(3,8,1)` -> 2/8, 5/8, 7/8 |

Compose freely: `c4 [e4,g4] a4@2`, `[c3,e3] g3 a#3 c4@4`.

## Rejected -- raise `ValueError` (no meaning in a one-shot cycle)

`<a b>` (alternate) · `a|b` (choose) · `a?` (degrade) · `{a b}%n` (polymeter) ·
`a/n` (slow) · `a:n` (sample-index)

## Timing model

- One cycle = **`cycle_sec`** seconds -- a per-sound knob on the `Sound` class
  (root default 0.12; override per variant). Real onset = fraction * `cycle_sec`.
- Operators place *onsets*; bells overlap (a bell is never cut short).

## Sustain (note length -> ring)

A note's **duration** (its slot span x `cycle_sec`) sets how long it rings,
**floored at the sound's natural decay** (`BELL_DUR x decay_scale`, ~0.5s):

- short notes keep their natural pluck (no change, no click);
- a note **longer than the natural decay rings on for its full duration**.

So to make a note sustain, give it enough duration to exceed ~0.5s -- widen it
with `@n` / `_`, and/or raise the sound's `cycle_sec`. Examples (at `cycle_sec`
= 1.2s): `c4@4 e4` -> c4's slot is 4/5 x 1.2 = 0.96s, so c4 rings ~0.96s while
e4 stays a natural pluck. `c4 _ _ _` holds c4 across the whole cycle.
