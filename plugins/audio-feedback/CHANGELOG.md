# Changelog

All notable changes to the audio-feedback plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-04-13

### Added
- Click sounds: Elite Dangerous station UI-inspired click sequences that
  play after Stop, PostToolUse, and SubagentStop events. Click rate is
  proportional to response word count with ease-out timing (starts at
  16 clicks/sec, decelerates). Each click is a noise impulse with
  dissonant resonance and reverb, generated at runtime via sox.
- `CLICKS_ENABLED` config key (default `true`) to toggle click sounds
  independently of event sounds.
- Background sound sequencing: event sound + clicks play in a backgrounded
  subshell so hooks return instantly.

### Changed
- Stop, PostToolUse, and SubagentStop hooks now extract word count from
  JSON payload (`assistant_message`, `tool_response`, `result` fields).

## [0.1.0] - 2026-04-12

### Added
- Initial release. Audio feedback for 8 Claude Code hook events.
- Unified `/audio-feedback` skill entry point with subcommand grammar
  (`/audio-feedback <config|sounds|test|help> [args...]`).
- Single `hooks/play-sound.sh` script handling all events — called with
  event name as `$1` from `hooks.json`.
- Hook registrations for all 8 events: Stop, Notification, PreCompact,
  UserPromptSubmit, SessionStart, SubagentStop, PreToolUse, PostToolUse.
- Per-event sound config: each event has its own `*_SOUND` key that can
  be set to any bundled sound name or `off`.
- Theme support via `THEME` config key. Sounds live in `sounds/<theme>/`
  subdirectories. Ships with `default` theme.
- `default` theme with 8 lo-fi minimal synth sounds (sox-generated,
  0dB peak, reverb with 0.5s decay tail, mono 44.1kHz):
  - `stop.wav` — descending G4-C4 fifth, settling feel
  - `notification.wav` — ascending A4-C5, attention-getting
  - `pre-compact.wav` — low G3 tone, slight unease
  - `user-prompt-submit.wav` — tiny 600Hz click
  - `session-start.wav` — ascending C4-E4-G4 arpeggio, welcoming
  - `subagent-stop.wav` — soft double ping E5
  - `pre-tool-use.wav` — barely-there 500Hz tick
  - `post-tool-use.wav` — short 700Hz confirmation tick
- Default on for: Stop, Notification, PreCompact, UserPromptSubmit.
- Default off for: SessionStart, SubagentStop, PreToolUse, PostToolUse
  (high-frequency events that could be annoying).
- Master `ENABLED` switch to silence everything at once.
- Global config at `~/.claude/.audio-feedback-config` (KV-style).

### Requirements
- Linux with PipeWire (`paplay` required for WAV playback)
