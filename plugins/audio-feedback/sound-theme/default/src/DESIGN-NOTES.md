# Audio-Feedback Sound Design Notes

Design bible for the default theme. The sounds are generated programmatically
by `generate.py` (built on signalflow) from the locked note-map and category
variants below, sourced from `variants.py` in this
directory. This file documents the design intent that those JSON files and
`generate.py` encode, so read it before touching either.

`audio-feedback.rpp` and the accompanying Vital fragment in this directory are
ARCHIVED reference from an earlier REAPER-based rendering approach and are no
longer part of the build; the note-map and premium-tips sections below still
apply to the current signalflow synthesis.

---

## The sound system

Two orthogonal axes encode an event's meaning. They reinforce each other.

- **Mode = phase of work**
  - **Mixolydian** (flat-7, no leading tone -> open, "more coming") for STARTS.
  - **Ionian** (major, leading tone -> closure) for FINISHES.
- **Contour = direction**
  - **Rising** for starts.
  - **Falling / settling on the low tonic** for finishes.

Key: C. Register: one octave below the "named" pitches (warm). Consonant
intervals throughout (octave, fifth, major third).

The signature arc: `pre-tool-use` hangs open on the flat-7 (unresolved), and
`stop` resolves it by falling through the major 7th to the tonic. Progress
opens; completion closes.

## Locked note-map

Rhythm fits within one 4/4 bar per event. Quavers carry movement; minims hold
the settling/landing notes. Notes are the actual sounding pitches (MIDI).

| Event | Mode | Contour | Notes (MIDI) | Rhythm |
|-------|------|---------|--------------|--------|
| `session-start` | Mixolydian | rise | C3 E3 G3 Bb3 C4 (48 52 55 58 60) | 4 quavers + minim (full bar) |
| `user-prompt-submit` | Mixolydian | - | G4 (67) | quaver |
| `pre-tool-use` | Mixolydian | - | Bb4 (70), open flat-7 | quaver |
| `notification` | Mixolydian | rise | C4 G4 Bb4 (60 67 70) | 2 quavers + crotchet |
| `pre-compact` | Mixolydian | warn | G2 + Bb2 (43 46) low dyad | minim chord |
| `post-tool-use` | Ionian | - | C5 (72), tonic | quaver |
| `subagent-stop` | Ionian | fall | E4 C4 (64 60) | quaver + crotchet |
| `stop` | Ionian | fall | C5 B4 G4 E4 C4 (72 71 67 64 60) | 4 quavers + minim (full bar) |

Frequent events (tool ticks, user-prompt, subagent-stop) are short by design;
rare events (session-start, stop) get the full phrase. More frequent = more
subtle.

### Category variants

The `pre-tool-use-*`, `post-tool-use-*`, `notification-*`, and
`session-start-*` tracks inherit their base event's notes as a starting point.
Give each category a light accent (a timbre tweak or a small transposition) so
the tool group is recognisable, without departing from the base's mode/contour:
`execute`, `modify`, `network`, `observe`, `dispatch`, `interact`.

---

## Premium tips (making it sound expensive)

1. **Attack** - kill the click, keep the transient. A 2-5 ms soft fade-in
   (not zero, not long). A little energy in the 700-2000 Hz presence band
   gives definition.
2. **Envelope** - struck, not sustained. Fast attack, long smooth exponential
   decay, zero sustain (bell/mallet, not organ). Always fade the last ~100 ms
   to silence; never let the tail cut abruptly.
3. **Harmonics** - glassy = inharmonic. A bare sine is sterile; saw/square is
   buzzy/cheap. Layer a tonal body + a soft slightly-inharmonic upper partial
   + optional quiet high "air", then low-pass to shave fizz.
4. **Width and space** - tiny detune (a few cents) or micro-delay between
   layers for richness. Reverb with a 5-15 ms pre-delay keeps the transient
   crisp while giving the tail a small bright room. Low reverberance; a little.
5. **EQ - three moves** - cut low-mid mud ~300-500 Hz (few dB) for clarity;
   gentle high-shelf "air" ~6-10 kHz for sheen; tame the 2.5-4 kHz
   ear-fatigue zone / fizz with a dip or low-pass.
6. **Loudness** - normalise the whole palette to one level, ceiling -1 dBTP
   (~1 dB headroom). No sound startlingly louder than another.
7. **Restraint** - short, quiet, unobtrusive. Frequent sounds especially so.
   Premium reads as restrained, never loud/long/bright-hot.

**Don'ts:** raw oscillator onset; truncated tail; saw/square as the main body;
over-chorus / over-reverb / over-drive; anything peaking at 0 dBFS.

The four that matter most for these bells: **inharmonic partials + soft attack
+ light pre-delay reverb + palette-consistent loudness.**

---

## Render + verify workflow

1. Render: from this src directory (or the repo root), run

   ```
   UV_PYTHON_PREFERENCE=only-managed uv run --script generate.py
   ```

   This synthesises the full palette from `variants.py`
   straight to `../sounds/`; uv resolves the signalflow dependency itself, no
   separate venv needed.

2. Verify the whole palette is loudness-consistent with headroom:

   ```
   python scripts/analyze.py --palette sound-theme/default/sounds
   ```

   Passes when the RMS spread is <= 5 dB and the peak stays under -0.7 dBFS.

Event sounds are pre-rendered WAVs played by the audio-feedback hook
(`scripts/lib.sh`); there is no runtime synthesis at play time.

---

## Sources

Premium UI-audio research: fivepointseven "How to Design a Pleasant Alert
Sound"; Unison Audio "Harmonics and Overtones 101"; North Coast Synthesis
"Maximizing inharmonicity"; iZotope / mastering.com (true-peak, LUFS); Toptal
UX Sounds Guide; Material Design Sound Choreography. Note choices: 20K "The
Sound of Apple" (interval choices), Game Developer "Candy Crush audio
breakdown" (ascending-step precedent), Los Doggies "Duolingo" (major-3rd
success interval).
