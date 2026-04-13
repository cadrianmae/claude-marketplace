# Changelog

All notable changes to the tts plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.5] - 2026-04-13

### Fixed
- **Summary mode no longer speaks error messages.** Previously, if
  the Haiku call failed (e.g. "Credit balance too low"), the error
  text was treated as a summary and spoken aloud. Now checks exit
  code properly and falls back to truncate silently.
- **Summary mode no longer over-compresses short responses.** Only
  calls Haiku when text exceeds `MAX_CHARS`. Responses under the
  threshold pass through with just markdown stripped.

### Changed
- **Summary mode uses JSON schema output.** The Haiku call now uses
  `--output-format json --json-schema` for structured output, ensuring
  only the summary text is extracted (no preamble, no fluff).
- **Summary Haiku call is leaner.** Uses `--allowed-tools ""
  --no-session-persistence --disable-slash-commands` to minimise
  overhead and prevent tool use.
- **Summary prompt rewritten.** Now instructs Haiku to "rewrite for
  spoken delivery, keep as much detail as possible, use most of the
  character budget" instead of "summarize under N characters" which
  caused aggressive compression.

## [0.1.4] - 2026-04-12

### Added
- **Stop hook chime.** Plays a short synth sound before speech starts
  to signal "Claude finished responding." Default: `soft-chime` (warm
  C4+E4 chord, 0.4s). Four bundled sounds: `soft-chime`, `pip`, `hum`,
  `bell`. All generated with sox, normalized to 0dB peak, mono 44.1kHz.
- Two new config keys:
  - `CHIME_ENABLED` (default `true`) — toggle chime on/off
  - `CHIME_SOUND` (default `soft-chime`) — which bundled sound to play
- `tts-config` view mode now shows available chime sounds.
- `config.sh` validates `CHIME_SOUND` against bundled files.
- Chime plays only when `TTS_ENABLED=true` (no sound when TTS is off).
- Chime plays synchronously before speech, so you hear
  "ding... [spoken response]" with no overlap.

### Technical Details
- `scripts/lib.sh` — new `_tts_sounds_dir()`, `tts_play_chime()`,
  `tts_list_chimes()` functions. Config defaults and loading for
  `CHIME_ENABLED` and `CHIME_SOUND`.
- `hooks/speak.sh` — calls `tts_play_chime` after `TTS_ENABLED` check,
  before transcript extraction and speech.
- `sounds/` — four bundled WAV files (292KB total), generated via sox
  synth with normalize to 0dB peak.

## [0.1.3] - 2026-04-12

### Added
- **Voice configuration parameters.** Four new config keys for tuning
  piper's voice output:
  - `SPEED` (default `1.0`, range 0.1-3.0) — maps to `--length-scale`.
    **Inverted scale**: <1.0 = faster, >1.0 = slower. 0.7 is a good
    fast default.
  - `EXPRESSIVENESS` (default `0.667`, range 0.0-1.0) — maps to
    `--noise-scale`. Higher = more expressive/varied speech.
  - `PRONUNCIATION_VARIATION` (default `0.8`, range 0.0-1.0) — maps to
    `--noise-w-scale`. Higher = more variation in phoneme timing.
  - `SENTENCE_SILENCE` (default `0.0`, range 0.0-5.0) — maps to
    `--sentence-silence`. Seconds of silence between sentences.
- `tts-config` view mode now displays all 10 config keys (was 6).
- Float validation in `config.sh` using awk for range checking.
- Speed note in `tts-config` output reminding about the inverted scale.

### Technical Details
- `scripts/lib.sh` — 4 new default vars, 4 new case entries in
  `tts_load_config`, 4 new lines in `tts_ensure_config` heredoc,
  4 new `--length-scale`/`--noise-scale`/`--noise-w-scale`/
  `--sentence-silence` flags in `tts_speak`'s piper command string.
- `scripts/config.sh` — 4 new validation cases using regex + awk
  float range checks. Updated view mode and error message key list.
- `skills/tts/SKILL.md` — updated Configuration Reference table and
  Important Notes section with speed scale explanation.
- `README.md` — updated Configuration table.

## [0.1.2] - 2026-04-12

### Added
- **Multi-speaker voice support.** Piper voices that bundle multiple
  speakers in a single `.onnx` file (e.g. `semaine` with `prudence`,
  `spike`, `obadiah`, `poppy`, or `aru` with 12 numeric speaker ids)
  can now be selected with `name:speaker` syntax:
  - `/tts voice semaine:poppy` — look up speaker by name in the voice's
    `.onnx.json` `speaker_id_map`
  - `/tts voice semaine:3` — select speaker by integer id
  - `/tts voice semaine` — use Piper's default (speaker id 0)
- `tts-voices` now annotates multi-speaker voices with their speaker
  list: `semaine (speakers: prudence, spike, obadiah, poppy)`. The
  annotation is read from the `speaker_id_map` in each voice's sidecar
  JSON, sorted by speaker id.
- `tts-voice` error messages now distinguish between "voice not found"
  and "speaker is invalid for this voice", and include a reminder
  about the `name:speaker` syntax.
- `tts-voices` output now distinguishes current default vs. other voices,
  and displays the active speaker when a multi-speaker voice is selected
  (e.g. `* semaine (speakers: ...) (current default: poppy)`).

### Changed
- `tts_speak` now passes `--speaker N` to `piper` when a speaker is
  resolved, instead of always omitting the flag.
- Internal: new `tts_resolve_voice` function sets `TTS_RESOLVED_FILE`
  and `TTS_RESOLVED_SPEAKER` globals. `tts_voice_file` is retained as
  a backwards-compat wrapper that returns only the path. A new
  `_tts_short_name` helper deduplicates the filename-stripping logic
  previously inlined in two places.

### Technical Details
- `scripts/lib.sh` — added `tts_resolve_voice`, `_tts_short_name`,
  refactored `tts_list_voices` and `tts_speak` to use them.
- `scripts/voice.sh` — uses `tts_resolve_voice` directly; reports
  speaker id on success.
- `scripts/voices.sh` — splits `TTS_VOICE` on `:` to find the base
  voice for "current default" marking, appends speaker name to the
  annotation when applicable.
- `skills/tts/SKILL.md` — new "Multi-speaker voices" section in the
  VOICE workflow; examples updated.
- `README.md` — Quick Start shows `semaine:poppy` example;
  feature list mentions multi-speaker support.
- All existing tests pass; shellcheck clean; manual audio test
  confirmed `--speaker 3` reaches piper for `semaine:poppy`.

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
