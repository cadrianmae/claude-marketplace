# Changelog

All notable changes to the tts plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-04-12

### Fixed
- **Stop hook text extraction was broken in two ways.** First, it stopped
  at the first assistant message in the transcript regardless of whether
  the message had any text content — so turns whose most recent JSONL
  line was a pure `thinking` or `tool_use` block resulted in empty
  speech and a silent hook.
- **Second, the turn-boundary detection was wrong.** The hook walked
  backwards looking for the last `role: "user"` message, but in Claude
  Code transcripts `role: "user"` covers BOTH real human prompts AND
  tool_result responses (tool results are modeled as user-role messages
  in the API). The old logic would stop at the most recent tool_result,
  missing most of the current agent turn's text.

### Changed
- **Stop hook now extracts the full current agent turn.** A single turn
  can span many JSONL lines: text → thinking → tool_use → tool_result
  → more text → another tool_use → final text. The new implementation
  uses `jq -s` to slurp the transcript, finds the index of the most
  recent REAL user message (filtering by content type: string or
  text-block array, NOT tool_result array), then concatenates text
  from every assistant message that comes after it. Thinking and
  tool_use blocks contribute nothing; text blocks are joined with
  blank lines between messages.

### Technical Details
- `hooks/speak.sh` — replaced the per-line `tac | while` walk with a
  single `jq -rs` slurp invocation that filters, collects, and joins
  in one pass. Includes an `is_real_user` predicate that distinguishes
  human input from tool_result entries by inspecting
  `.message.content` type and block types.

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
