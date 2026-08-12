[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Audio Feedback Plugin v1.0

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
| `SUBAGENT_ACCENT` | `true` | Overlay `subagent-accent.wav` on tool sounds fired on behalf of a subagent |

Set any event to `off` to silence it. Sound values are filenames (without `.wav`) from the active theme directory.

## Default Theme Sounds

| File | Event | Character | Duration |
|---|---|---|---|
| `stop.wav` | Stop | Descending G4-C4 fifth, settling | 1.0s |
| `notification.wav` | Notification | Ascending A4-C5, attention | 0.9s |
| `pre-compact.wav` | PreCompact | Low G3 tone, warning | 1.1s |
| `user-prompt-submit.wav` | UserPromptSubmit | Tiny 600Hz click | 0.55s |
| `session-start.wav` | SessionStart | Ascending C4-E4-G4 arpeggio | 0.94s |
| `subagent-stop.wav` | SubagentStop | Double ping E5 | 0.66s |
| `pre-tool-use.wav` | PreToolUse | Barely-there 500Hz tick | 0.53s |
| `post-tool-use.wav` | PostToolUse | Short 700Hz tick | 0.54s |

All sounds: lo-fi minimal aesthetic, synthesised with reverb, 0.5s decay tail, normalized to 0dB peak, mono 44.1kHz.

## Sound design

The default theme's 27 sounds (8 base events + 19 subtype variants) are all derived
from the locked note-map in `variants.py`: each base event is a `seq` (melodic line) or `chord`
(simultaneous notes) of MIDI note/duration pairs, additively synthesised as bells by
`generate.py`. Variants (e.g. `notification-permission`, `pre-tool-use-execute`) are
declared in `variants.py` as small accent deltas (brightness, detune, punch) layered
on top of their base event's contour, rather than hand-authored from scratch, so the
whole palette stays sonically related while each event/subtype still reads distinctly
by ear.

## Regenerating sounds

The palette is generated programmatically, not hand-mixed. Regenerate it with:

```bash
# One-time: dev venv for analyze.py (needs numpy/scipy; generate.py supplies
# its own deps via PEP 723 + uv run --script, so it doesn't need this venv).
cd plugins/audio-feedback
uv venv sound-theme/default/src/.venv-gen
uv pip install --python sound-theme/default/src/.venv-gen numpy scipy

# Regenerate the full palette (renders into sound-theme/default/sounds/):
UV_PYTHON_PREFERENCE=only-managed uv run --script \
  sound-theme/default/src/generate.py

# Verify the palette loudness gate (RMS spread <=3 dB, peak max <=-0.7 dBFS):
sound-theme/default/src/.venv-gen/bin/python scripts/analyze.py --palette \
  sound-theme/default/sounds
```

Use `generate.py --only NAME` to re-render a single sound. Tuning (brightness, decay,
levels) lives entirely in `generate.py` / `variants.py` - never loosen the loudness
gate in `analyze.py` to make a bad render pass.

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
