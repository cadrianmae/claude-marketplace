[![Version](https://img.shields.io/badge/version-1.1.1-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Audio Feedback Plugin v1.1.1

Audio feedback for Claude Code hook events. Plays short synth sounds on response complete, notifications, context compaction, user input, and more. Configurable per-event with bundled theme sounds. Independent of the tts plugin.

## Overview

Registers hooks on all 8 Claude Code events. Each event maps to a sound file (or `off`). A single `hooks/play-sound.sh` script handles all events — it receives the event name as an argument, loads config, and plays the matching WAV via `paplay`.

**Key features:**
- **Per-event sounds** — each hook event has its own configurable sound
- **Theme system** — sounds live in `sound-theme/<theme>/sounds/` subdirectories, switchable via `THEME` config
- **Master switch** — `ENABLED=true/false` silences everything at once
- **Lo-fi minimal default theme** — 8 sounds with reverb, 0dB peak, mono 44.1kHz
- **Independent of tts** — purely non-speech audio cues

## Prerequisites

| Requirement | How to verify | Notes |
|---|---|---|
| Linux + PipeWire | `paplay --version` | Required for all sounds |
| jq | `jq --version` | Optional — enables subtype-specific sounds (per-tool, per-notification) |
| uv | `uv --version` | Optional — enables the single-process playback daemon (supplies its python deps via PEP 723); without it, falls back to paplay per event |

## Command

- `/audio-feedback` — Interactive entry point for config / sounds / test / help.

## Quick Start

```bash
# Plugin is enabled by default with 4 events active.
# Just install and you'll hear sounds on:
#   - Stop (response complete)
#   - Notification (cron/alerts)
#   - PreCompact (context compaction)
#   - UserPromptSubmit (input acknowledged)

# Adjust which events play sounds:
/audio-feedback config SESSION_START_SOUND=session-start    # enable startup chime
/audio-feedback config PRE_TOOL_USE_SOUND=off               # keep tools silent

# Switch theme (when more themes are available):
/audio-feedback config THEME=retro

# Silence everything temporarily:
/audio-feedback config ENABLED=false
```

## Configuration

Global config: `~/.claude/.audio-feedback-config`

| Key | Default | Purpose |
|---|---|---|
| `THEME` | `default` | Sound theme (subdirectory of `sound-theme/`) |
| `ENABLED` | `true` | Master switch |
| `STOP_SOUND` | `stop` | Response complete |
| `NOTIFICATION_SOUND` | `notification` | Cron/alert fired |
| `PRE_COMPACT_SOUND` | `pre-compact` | Context compacting |
| `USER_PROMPT_SOUND` | `user-prompt-submit` | Input acknowledged |
| `SESSION_START_SOUND` | `off` | New session started |
| `SUBAGENT_STOP_SOUND` | `off` | Subagent finished |
| `PRE_TOOL_USE_SOUND` | `off` | Before tool call |
| `POST_TOOL_USE_SOUND` | `off` | After tool call |
| `DAEMON_ENABLED` | `true` | Use the resident playback daemon when available |
| `DAEMON_IDLE_TIMEOUT` | `30` | Seconds of inactivity before the daemon self-exits |
| `DAEMON_MAX_VOICES` | `8` | Max concurrent mixed voices in the daemon |
| `SUBAGENT_ACCENT` | `true` | Play the `-subagent` background variant (extra reverb, low-pass, level trim) for tool sounds fired on behalf of a subagent |
| `VOLUME` | `1.0` | Playback level, linear `0.0`-`1.0` (scales both daemon mix and `paplay`) |

Set any event to `off` to silence it. Sound values are filenames (without `.wav`) from the active theme directory.

## Default Theme Sounds

Note-map, voice, and cycle length are the source of truth in `variants.py`;
this table is generated from it. `Notes` is the mini-notation phrase (`@N` =
hold N sub-steps, `[...]` = one bracketed step, `,` = stacked/simultaneous).

| File | Event | Voice | Notes | Character | Cycle |
|---|---|---|---|---|---|
| `stop.wav` | Stop | pluck | `[c5 b4@2] g4 e4@2 c4@3` | Ionian fall, settles | 0.96s |
| `notification.wav` | Notification | pluck | `g4 a#4@2` | Open rise, kept subtle (quieter, sits back) | 0.48s |
| `pre-compact.wav` | PreCompact | sine | `[c3,e3,g3]` | Low sustained warn triad | 0.96s |
| `user-prompt-submit.wav` | UserPromptSubmit | pluck | `g4` | Single plucked tone, input ack | 0.12s |
| `session-start.wav` | SessionStart | pluck | `c3@3 e3@2 g3 [a#3 c4]` | Mixolydian rise, accelerating | 1.44s |
| `subagent-stop.wav` | SubagentStop | pluck | `e4 c4@2` | Short two-note fall | 0.36s |
| `pre-tool-use.wav` | PreToolUse | pluck | `a#4` | Open flat-7, barely-there tick | 0.06s |
| `post-tool-use.wav` | PostToolUse | pluck | `c5` | Tonic, resolved tick | 0.06s |

`Cycle` is the musical cycle length (`cycle_sec`); the rendered WAV runs a
little longer with its reverb tail. All sounds: mono 44.1 kHz, peak-normalized
then trimmed per-sound by ear (`level_db`). The 19 subtype variants (e.g.
`pre-tool-use-execute`, `notification-idle`) extend these base events with
`dsp` overrides and overlay layers — see `variants.py`.

## Sound design

The default theme's 27 cards (8 base events + 19 subtype variants) are derived from
the locked note-map in `variants.py`: each base event is a mini-notation `phrase` of
notes rendered by one of the numpy/scipy voices in `voices.py` (`bell`, `pluck`,
`sine`, `clicks`, `swoosh`), with the voice primitives defined in `dsp.py` and tuned
by `tuning.py`. Variants (e.g. `notification-permission`, `pre-tool-use-execute`) are
declared as per-sound `dsp` overrides and optional overlay layers (`clicks_layer`,
`slide_layer`) on top of their base event's contour, so the palette stays sonically
related while each event/subtype reads distinctly by ear. Tool sounds fired on behalf
of a subagent also render a `-subagent` background variant (see `SUBAGENT_ACCENT`),
for 41 WAVs total.

## Regenerating sounds

The palette is generated programmatically, not hand-mixed. The generator is a uv
project rooted at `sound-theme/default/` (deps in its `pyproject.toml`, pinned via
`uv.lock`). Use the `justfile` in this directory:

```bash
cd plugins/audio-feedback
just venv        # one-time: uv sync the dev env (Python 3.12 + numpy/scipy/numba)
just generate    # render the full palette into sound-theme/default/sounds/
just verify      # palette loudness gate (RMS spread <=5 dB, peak max <=-0.7 dBFS)
just test        # note-map + generator tests
```

Iterate on a single sound by ear:

```bash
just live stop notification   # watch the src files; re-render + play on save
just preview pre-tool-use-network   # render + play once (temp; sounds/ untouched)
```

Or preview the whole palette in the browser (lumae Dusk), with live-reload on save:

    just serve        # http://127.0.0.1:8765 — all sounds, waveforms, click to play

`just` (or `uv run` in `sound-theme/default/`) drives the synced venv; `generate.py`
also carries PEP 723 metadata so `uv run --script src/generate.py` works standalone.
Tuning lives in `sound-theme/default/src/` (`tuning.py` = the voice; `variants.py` =
per-event note-map + accents) - never loosen the loudness gate in `analyze.py` to make
a bad render pass.

## Themes

Sounds are organized in `sound-theme/<theme>/` subdirectories. The `THEME` config key selects which directory to use.

To create a custom theme:
1. Create `sound-theme/my-theme/` in the plugin directory
2. Add a `sounds/` subdirectory with WAV files named after hook events (e.g. `sounds/stop.wav`, `sounds/notification.wav`)
3. Add a `theme.json` (`{"name": "...", "comment": "..."}`) — without it the theme is not listed or selectable
4. Set `THEME=my-theme` in config

Missing sound files are a silent no-op — you don't need all 8 files in a theme.

## Playback daemon

A single resident `af-soundd` process can hold one PipeWire client and mix all event sounds together, instead of spawning a separate `paplay` process per event. It auto-spawns on the first event (via `uv run --script`, which supplies its python dependencies through PEP 723 inline metadata — no venv needed) and self-exits after `DAEMON_IDLE_TIMEOUT` seconds of inactivity. This collapses N concurrent agents each firing sounds into one player process and one PipeWire client, instead of N separate `paplay` calls. The per-event client itself is stdlib-only and runs under bare `python3`; when `uv` is absent the plugin falls back to `paplay` per event as before. The first spawn on a cold `uv` cache downloads wheels once, adding a short delay — pre-warm it ahead of time with `uv run --script bin/af-soundd selftest`.

## Coexistence with TTS Plugin

If both `audio-feedback` and `tts` are installed, both register Stop hooks. To avoid double-chime on response complete, disable one:

```bash
# Option 1: disable tts chime, keep audio-feedback's stop sound
/tts config CHIME_ENABLED=false

# Option 2: disable audio-feedback's stop, keep tts chime
/audio-feedback config STOP_SOUND=off
```

## See Also

- [CHANGELOG.md](./CHANGELOG.md) — Version history
- `/audio-feedback help` — In-app reference
