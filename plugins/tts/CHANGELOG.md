# Changelog

All notable changes to the tts plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-12

### Added
- Initial release. Piper-based text-to-speech for Claude Code.
- Unified `/tts` skill entry point with subcommand grammar
  (`/tts <speak|test|voices|voice|config|auto|help> [args...]`).
- `Stop` hook (`hooks/speak.sh`) — speaks each assistant response via
  `piper --output-raw` piped to `paplay --raw`. Async execution, detached
  via `setsid` so audio survives Claude Code process-group signals.
- `UserPromptSubmit` hook (`hooks/interrupt.sh`) — kills any in-flight
  `paplay` so typing a new prompt interrupts speech mid-sentence.
- Global config at `~/.claude/.tts-config` (KV-style). Keys: `VOICE`,
  `VOLUME`, `SPEAK_MODE`, `MAX_CHARS`, `TTS_ENABLED`, `INTERRUPT_ON_TYPE`.
- Three speak modes: `full` (entire response), `truncate` (hard-cut at
  `MAX_CHARS`, default), `summary` (Claude Haiku summarizes for speech,
  falls back to truncate on failure).
- `bin/` wrapper scripts (`tts-speak`, `tts-voices`, `tts-voice`,
  `tts-config`, `tts-auto`) for `$CLAUDE_PLUGIN_ROOT`-free helper invocation
  from SKILL.md (per anthropics/claude-code#9354).
- Default state on first install: `TTS_ENABLED=false`. User opts in via
  `/tts auto on`. No surprise audio on plugin install.
- Default voice: `aru` (en-GB female, medium quality). Configurable via
  `/tts voice <name>`.

### Requirements
- Linux with PipeWire (`paplay --raw` required, `pw-play` can't handle
  raw PCM from stdin per the PipeWire WIP gotcha list)
- `piper` binary on `PATH`
- Piper voices installed at `~/.local/share/piper-voices/`
- `pandoc` optional — used for markdown-to-plain-text conversion; falls
  back to `sed` if absent
