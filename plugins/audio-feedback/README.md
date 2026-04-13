[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Audio Feedback Plugin v0.2

Audio feedback for Claude Code hook events. Plays short synth sounds on response complete, notifications, context compaction, user input, and more. Configurable per-event with bundled theme sounds. Independent of the tts plugin.

## Overview

Registers hooks on all 8 Claude Code events. Each event maps to a sound file (or `off`). A single `hooks/play-sound.sh` script handles all events — it receives the event name as an argument, loads config, and plays the matching WAV via `paplay`.

**Key features:**
- **Per-event sounds** — each hook event has its own configurable sound
- **Theme system** — sounds live in `sounds/<theme>/` subdirectories, switchable via `THEME` config
- **Master switch** — `ENABLED=true/false` silences everything at once
- **Click sounds** — glassy sci-fi click sequences proportional to response word count, with ease-out timing. Plays on Stop, PostToolUse, SubagentStop. Requires `sox` at runtime.
- **Lo-fi minimal default theme** — 8 sox-generated sounds with reverb, 0dB peak, mono 44.1kHz
- **Independent of tts** — purely non-speech audio cues

## Prerequisites

| Requirement | How to verify | Notes |
|---|---|---|
| Linux + PipeWire | `paplay --version` | Required for all sounds |
| sox | `sox --version` | Required for click sounds only |

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
| `THEME` | `default` | Sound theme (subdirectory of `sounds/`) |
| `ENABLED` | `true` | Master switch |
| `CLICKS_ENABLED` | `true` | Click sounds on Stop/PostToolUse/SubagentStop |
| `STOP_SOUND` | `stop` | Response complete |
| `NOTIFICATION_SOUND` | `notification` | Cron/alert fired |
| `PRE_COMPACT_SOUND` | `pre-compact` | Context compacting |
| `USER_PROMPT_SOUND` | `user-prompt-submit` | Input acknowledged |
| `SESSION_START_SOUND` | `off` | New session started |
| `SUBAGENT_STOP_SOUND` | `off` | Subagent finished |
| `PRE_TOOL_USE_SOUND` | `off` | Before tool call |
| `POST_TOOL_USE_SOUND` | `off` | After tool call |

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

All sounds: lo-fi minimal aesthetic, sox synth with reverb, 0.5s decay tail, normalized to 0dB peak, mono 44.1kHz.

## Themes

Sounds are organized in `sounds/<theme>/` subdirectories. The `THEME` config key selects which directory to use.

To create a custom theme:
1. Create `sounds/my-theme/` in the plugin directory
2. Add WAV files named after hook events (e.g. `stop.wav`, `notification.wav`)
3. Set `THEME=my-theme` in config

Missing sound files are a silent no-op — you don't need all 8 files in a theme.

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
