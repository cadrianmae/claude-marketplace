# Audio-Feedback Sound Design Notes

Design bible for the default theme. The sounds are generated programmatically
by a pure-numpy engine, layered `dsp.py` -> `voices.py` -> `generate.py`,
from the locked note-map and category variants below, sourced from
`variants.py` in this directory. This file documents the design intent that
`variants.py` and the engine encode, so read it before touching either.

`audio-feedback.rpp` and the accompanying Vital fragment in this directory are
ARCHIVED reference from an earlier REAPER-based rendering approach and are no
longer part of the build; the note-map and premium-tips sections below still
apply to the current numpy synthesis.

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

## The engine

Pure numpy, no signalflow dependency, layered in three modules under `src/`:

- **`dsp.py`** - low-level primitives: oscillators, envelopes, a reverb, an
  `@njit`-compiled state-variable filter, pink noise, `midi_hz`. No knowledge
  of events or the palette; just signal generation.
- **`voices.py`** - the instrument layer built on `dsp.py`: the `bell`, `pluck`,
  `sine`, `swoosh`, and `clicks` voices plus `render_event`, which takes a
  `Sound` (from `variants.py`) and renders its full phrase. A per-sound `dsp`
  override dict lets any variant retune its voice's knobs
  (`knob(sound, key, tuning.default)`), and overlay LAYERS (`clicks_layer`,
  `slide_layer`, each with a `*_delay`) mix a texture over the base render via
  `_mix_at`. Envelope ramps are raised-cosine and every note fades to true zero,
  so there are no attack/release boundary clicks. This is where the premium-tips
  techniques below (inharmonic partials, soft attack, pre-delay reverb) live.
- **`generate.py`** - offline batch rendering: walks the palette
  (`theme.all_targets()`), calls `voices.render_event` per target, applies
  palette loudness normalisation (`loudness.py`), and writes WAVs to
  `../sounds/`. Also backs the `preview`/`live` subcommands (render-and-play,
  and watch-and-re-render-on-save).

`tuning.py` holds by-ear tuning knobs; `theme.py` and `variants.py` (locked
note-map, category accents) are unchanged by this engine and still the
source of design intent alongside this file.

## By-ear surfaces

Three ways to audition the sound design while iterating, all via the
justfile (run from `plugins/audio-feedback`):

- **`just generate` / `just preview NAME` / `just live NAME`** - offline
  render through `generate.py`: full palette write, one-off render-and-play,
  or watch-and-re-render-on-save. No audio device needed beyond playback.
- **`just live-play`** - real-time: `live.py` opens a `sounddevice` output
  stream and plays a connected MIDI keyboard (or a demo arpeggio if none is
  attached) through the voices, hot-reloading `voices.py`/`tuning.py` on
  save via `importlib`. Needs a working PortAudio output device and, for a
  real keyboard, `python-rtmidi`.

## Dev prerequisites

- **Python**: uv-managed Python 3.12 venv (`just venv` syncs it from
  `pyproject.toml`: numpy/scipy/numba/sounddevice/rtmidi, plus pytest in
  the dev group).
- **`python-rtmidi`**: needs ALSA (Linux) or JACK development headers
  installed on the system to build from source during `uv sync`.
- **Real-time audio** (`just live-play`): needs a working PortAudio output
  device on the machine. The offline render (`just generate`/`preview`/
  `live`) and the test suite (`just test`) do not touch audio hardware and
  do not need one.

## Verify

Verify the whole palette is loudness-consistent with headroom:

```
just verify
```

Passes when the RMS spread is <= 5 dB and the peak stays under -0.7 dBFS.

Event sounds are pre-rendered WAVs played by the audio-feedback hook
(`scripts/lib.sh`); there is no runtime synthesis at play time. The shipped
plugin only plays those committed WAVs, so it is unaffected by any of the
dev tooling or prerequisites above.

---

## Sources

Premium UI-audio research: fivepointseven "How to Design a Pleasant Alert
Sound"; Unison Audio "Harmonics and Overtones 101"; North Coast Synthesis
"Maximizing inharmonicity"; iZotope / mastering.com (true-peak, LUFS); Toptal
UX Sounds Guide; Material Design Sound Choreography. Note choices: 20K "The
Sound of Apple" (interval choices), Game Developer "Candy Crush audio
breakdown" (ascending-step precedent), Los Doggies "Duolingo" (major-3rd
success interval).
