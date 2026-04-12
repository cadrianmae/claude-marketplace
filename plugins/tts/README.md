[![Version](https://img.shields.io/badge/version-0.1.1-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# TTS Plugin v0.1

Piper-based text-to-speech for Claude Code. Speaks Claude's responses aloud via Stop hook, interrupts speech on user input via UserPromptSubmit hook. Replacement for AgentVibes with fewer dependencies and no MCP server.

## Overview

TTS plugin v0.1 is a minimal bash-based Piper wrapper for Claude Code. It calls `piper` directly (never through speech-dispatcher) and plays raw PCM through `paplay`. A single `/tts` skill handles all user-facing commands; two hooks handle speech and interrupt behavior.

**Key features:**
- **Unified `/tts` skill** — one interactive entry point, subcommand grammar, follows cron/track plugin pattern
- **Stop hook** — speaks each assistant response automatically when `TTS_ENABLED=true`
- **UserPromptSubmit hook** — kills in-flight `paplay` so typing interrupts Claude mid-sentence
- **Three speak modes** — `full`, `truncate` (default, 1000 chars), `summary` (via Claude Haiku)
- **Off by default** — no surprise audio on install; user runs `/tts auto on` to enable
- **Global config** — voice / volume / mode live at `~/.claude/.tts-config`, not per-project
- **Multi-voice support** — use any Piper voice installed at `~/.local/share/piper-voices/`

## Prerequisites

| Requirement | Why | How to verify |
|---|---|---|
| Linux + PipeWire | `paplay --raw` is PipeWire-native on Fedora/modern distros | `paplay --version` |
| `piper` binary on `PATH` | Called directly, not via speech-dispatcher | `which piper && piper --version` |
| At least one voice at `~/.local/share/piper-voices/*.onnx` | Voices are not bundled | `ls ~/.local/share/piper-voices/` |
| `pandoc` (optional) | Cleaner markdown-to-plain-text than sed fallback | `which pandoc` |

## Command

A single unified interactive command:

- `/tts` — Interactive entry point for speak / test / voices / voice / config / auto / help. Uses AskUserQuestion to walk through each workflow. Accepts arguments to skip prompts (e.g. `/tts voice lessac`, `/tts auto on`).

See the subcommand grammar below for the full argument form.

## Quick Start

```bash
# 1. Install and enable
/tts auto on
# Creates ~/.claude/.tts-config with defaults and enables hooks

# 2. Pick a voice
/tts voices                      # List installed voices
/tts voice lessac                # Set default voice

# 3. Test it
/tts test                        # Play a canned sample

# 4. Work normally — responses are spoken automatically
# - Interrupt by typing anything (kills in-flight paplay)
# - Adjust verbosity with /tts config SPEAK_MODE=full

# 5. Pause when you need silence
/tts auto off                    # Stop hook becomes a no-op until re-enabled
```

## Configuration

Global config file: `~/.claude/.tts-config`

| Key | Default | Values | Purpose |
|---|---|---|---|
| `VOICE` | `aru` | any installed voice name | Which Piper voice to use |
| `VOLUME` | `40000` | 0–65536 | `paplay --volume=N` attenuation level |
| `SPEAK_MODE` | `truncate` | `full` / `truncate` / `summary` | How to handle Claude's response |
| `MAX_CHARS` | `1000` | integer | Char cap for `truncate` and `summary` modes |
| `TTS_ENABLED` | `false` | `true` / `false` | Master on/off switch |
| `INTERRUPT_ON_TYPE` | `true` | `true` / `false` | Kill in-flight paplay on UserPromptSubmit |

## Speak modes

- **`full`** — Entire assistant response. Markdown stripped (via `pandoc -f markdown -t plain` if available, else `sed`). Code blocks removed. Can be 30+ seconds for long answers; interrupt by typing.
- **`truncate`** (default) — Same pipeline as `full`, but hard-cut at `MAX_CHARS` with `…` suffix. Safer default.
- **`summary`** — Calls Claude Haiku to summarize the response for speech in under `MAX_CHARS` characters. Falls back to `truncate` mode silently if the Haiku call fails (error logged to stderr, visible only in `claude --debug`).

## Subcommand Grammar

```
/tts                              → fully interactive (action AUQ first)
/tts speak <text>                 → manually speak a one-off string
/tts test                         → play a canned sample with current voice
/tts voices                       → list installed voices
/tts voice <name>                 → set VOICE config value
/tts config [KEY=VALUE ...]       → view or update global config
/tts auto [on|off]                → toggle TTS_ENABLED
/tts help                         → subcommand grammar + voice list
```

## Architectural notes

### Why no MCP server?

AgentVibes used an MCP server for voice management. That introduced a separate npm install, a separate hook directory, and a command/script mismatch bug (`voice-manager.sh sample` not being a valid subcommand). A pure-bash plugin that shells out to `piper` directly has a much smaller attack surface.

### Why `paplay --raw` instead of `pw-play`?

`pw-play` and `pw-cat` use libsndfile which requires a file header. Piper's `--output-raw` produces headerless s16le PCM at 22050 Hz mono. `paplay --raw --format=s16le --rate=22050 --channels=1` is the only working pipe target.

### Why attenuation-only volume control?

Piper raw output is already at −13.8 LUFS with +0.8 dBFS true peak. There is **zero headroom** for amplification. Any gain via `sox -v` or similar causes clipping and a loud "earrape" incident. Volume is controlled exclusively via `paplay --volume=N` attenuation.

### Why `setsid` detach in the Stop hook?

The Stop hook fires when Claude's response completes. If Claude Code is killed mid-speech (user closes terminal, signal to process group), a foreground child would be killed too. `setsid bash -c "…" </dev/null & disown` detaches audio from the process group so speech completes even if Claude Code exits.

## See Also

- [CHANGELOG.md](./CHANGELOG.md) — Version history
- `/tts help` — In-app subcommand reference
- [Piper TTS](https://github.com/rhasspy/piper) — Upstream project
- `plugins/cron/`, `plugins/track/` — Other consolidated-skill plugins in this marketplace that share the `bin/` wrapper + unified-skill pattern
