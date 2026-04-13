# Changelog

All notable changes to the track plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.7.1] - 2026-04-13

### Fixed
- Replace /tmp paths with ${CLAUDE_PLUGIN_DATA} for debounce files and LLM error logs
- Add mkdir -p to ensure plugin data directory exists before stderr redirections
- Fix remaining /tmp reference in capture-sources.sh
- Normalise allowed-tools frontmatter format in skill

## [2.7.0] - 2026-04-11

### Changed
- **Unified all commands into a single interactive `/track` entry point.**
  Replaced five separate `/track:init`, `/track:config`, `/track:auto`,
  `/track:export`, `/track:help` skills with one `/track` skill driven by
  AskUserQuestion. Supports a subcommand grammar
  (`/track <init|config|auto|export|help> [args...]`) to skip prompts.
  Mirrors the cron plugin's v2.1.0 consolidation.

### Added
- `bin/` directory with thin wrapper scripts (`track-init`, `track-config`,
  `track-auto`, `track-export`). Claude Code puts `bin/` on `PATH`
  automatically, so the skill can invoke bare commands without needing
  `$CLAUDE_PLUGIN_ROOT` (which is not substituted inside SKILL.md; see
  anthropics/claude-code#9354).

### Removed
- **BREAKING:** Individual skills `/track:init`, `/track:config`,
  `/track:auto`, `/track:export`, `/track:help`. Use `/track <subcommand>`
  instead.
- Deprecated skills `migrate`, `ref-tracker`, `update`. These were flagged
  `deprecated: true` in frontmatter as early as v2.0 but remained loadable.
  Migration history is preserved in `MIGRATION.md`.

### Technical Details
- `skills/auto/scripts/auto.sh` → `scripts/auto.sh`
- `skills/config/scripts/config.sh` → `scripts/config.sh`
- All four helper scripts now colocated at `plugins/track/scripts/`.
- Skill body written in imperative form per `plugin-dev:skill-development`
  best practices (deviation from the cron template's second-person style).
- Hooks (`capture-prompt.sh`, `capture-sources.sh`) unchanged.

## [2.6.2] - 2026-03-03

### Fixed
- **Runaway claude haiku processes** - Stop hook now debounces rapid-fire events; only the last Stop in a burst triggers the LLM call, preventing process pile-up

### Technical Details
- `hooks/capture-prompt.sh`: Added 5-second debounce using `/tmp/track-capture-prompt-debounce` timestamp file; concurrent Stop events exit early, only the last writer proceeds

## [2.6.1] - 2026-02-24

### Changed
- **Source timestamp format** - Timestamps in `sources.md` now use ISO 8601 format with minutes (`2026-02-24T23:58+00:00`) instead of time-only (`23:58:00`)

### Technical Details
- `hooks/capture-sources.sh`: Changed `date +%H:%M:%S` to `date --iso-8601=minutes` for full datestamp context

## [2.6.0] - 2026-02-11

### Added
- **WebFetch LLM summarization** - WebFetch results now include AI-generated summaries instead of just headings
- **Multiple consecutive user messages** - Captures all user messages in a row (from interrupted responses) with "[continued]" separator
- **Enhanced Grep output** - Shows actual match content for content mode, full file paths for files mode
- **Full WebSearch URLs** - WebSearch results show complete URLs without truncation (up to 5 results)

### Changed
- **Tool extraction scope** - Now extracts tools from last 5 assistant messages instead of just the last one (captures tools across full interaction)
- **sources.md formatting** - More informative output for WebFetch (summaries), WebSearch (full URLs), and Grep (actual matches)

### Technical Details
- `hooks/capture-prompt.sh`: `extract_latest_interaction()` now captures ALL user messages after last assistant message
- `hooks/capture-prompt.sh`: `extract_tool_uses()` searches last 5 assistant messages for tools
- `hooks/capture-sources.sh`: `format_webfetch_entry()` calls Claude Haiku for content summarization
- `hooks/capture-sources.sh`: `format_websearch_entry()` removed URL truncation, increased from 3 to 5 URLs
- `hooks/capture-sources.sh`: `format_grep_entry()` shows actual match content based on output_mode

## [2.5.2] - 2026-02-11

### Fixed
- **Hook transcript extraction** - Fixed `$HOME` path expansion in transcript path (was looking for literal `$HOME` string)
- **User message extraction** - Skip tool_result arrays to find actual user text prompts
- **Assistant message extraction** - Skip thinking/tool_use blocks to find actual assistant text responses
- **Session history pollution** - Added `--no-session-persistence` flag to LLM summarization calls to prevent hook-spawned sessions from cluttering conversation history

### Technical Details
- `hooks/capture-prompt.sh`: Added `TRANSCRIPT_PATH="${TRANSCRIPT_PATH/\$HOME/$HOME}"` for path expansion
- `hooks/capture-prompt.sh`: User extraction now searches backwards for `.message.content` of type string (skips tool results)
- `hooks/capture-prompt.sh`: Assistant extraction now searches backwards for messages with text content
- `hooks/common/llm.sh`: All `claude` CLI calls now use `--no-session-persistence` flag

## [2.5.1] - 2026-02-11

### Changed
- **Unified tracking state** - Replaced `.ref-autotrack` marker file with `TRACKING_ENABLED` key in `.ref-config`
- **Single source of truth** - All tracking configuration now in one file (`.ref-config`)
- **Simpler state management** - Toggle tracking by changing config value instead of file existence

### Migration
- Existing `.ref-autotrack` files ignored (state read from `TRACKING_ENABLED` in `.ref-config`)
- `/track:init` now creates `TRACKING_ENABLED=true` in `.ref-config` by default
- `/track:auto` toggles `TRACKING_ENABLED` value instead of creating/deleting marker file
- `/track:config` preserves `TRACKING_ENABLED` when updating other settings

### Technical Details
- `hooks/common/config.sh`: `is_tracking_enabled()` reads `TRACKING_ENABLED` from config
- `scripts/init.sh`: Creates `TRACKING_ENABLED=true` in `.ref-config`, removed marker file creation
- `skills/auto/scripts/auto.sh`: Uses `sed` to toggle config value instead of file operations
- `skills/config/scripts/config.sh`: Preserves `TRACKING_ENABLED` when rewriting config

## [2.5.0] - 2026-02-11

### BREAKING CHANGES
- **New sources.md format** - ASCII compact format instead of LLM multi-line
- **Hook split** - Sources tracking moved from Stop hook to PostToolUse hook

### Added
- **capture-sources.sh** - Dedicated PostToolUse hook for sources tracking
- **ASCII format** - Compact `[HH:MM:SS] Tool(params) -> summary` format
- **Smart summaries** - Tool-specific formatting without LLM calls
- **Immediate tracking** - Tool calls written as they happen (per-call, not per-turn)
- **Detail lines** - Optional `|> details` for functions, matches, headings, URLs

### Changed
- **Renamed stop.sh** - Now `capture-prompt.sh` (prompts only)
- **Sources format** - No more JSON params, readable ASCII with timestamps
- **Hook type** - Sources use PostToolUse instead of Stop
- **No LLM for sources** - Pure bash parsing, zero API cost

### Removed
- **Sources tracking from Stop hook** - Moved to dedicated PostToolUse hook
- **LLM summarization for sources** - Replaced with deterministic formatting

### Migration
- Existing sources.md entries remain compatible
- New entries use ASCII format automatically
- No action required - hooks update automatically

### Technical Details
- PostToolUse hook matcher: `Read|Grep|WebFetch|WebSearch`
- capture-prompt.sh is stop.sh with sources code removed (~150 lines vs 228)
- capture-sources.sh uses tool_input/tool_response directly (no transcript parsing)
- Both hooks run async and respect SOURCES_VERBOSITY/PROMPTS_VERBOSITY config

## [2.4.0] - 2026-02-11

### BREAKING CHANGES
- **Removed PostToolUse hook** - Sources tracking now exclusively via Stop hook
- Projects using v2.0 tracking must migrate with `/track:migrate`

### Added
- **Migration tool** - `/track:migrate` skill for v2.0 → v2.1 upgrades
- **Improved export regex** - Handles all PostToolUse format variations (multi-param, named params)

### Changed
- **Simplified hook architecture** - Single tracking system (Stop hook only)
- **Updated templates** - sources.md template now shows v2.1+ multi-line format
- **Updated README** - Removed PostToolUse references, clarified Stop hook is sole tracker

### Fixed
- **Export compatibility** - WebFetch and Grep with multiple parameters no longer skipped
- **Template accuracy** - Matches actual v2.1+ output format
- **Hook conflict** - Eliminated duplicate tracking from PostToolUse + Stop running simultaneously

### Migration
- Run `/track:migrate` in projects initialized with v2.0
- Existing v2.0 entries preserved and backward compatible
- New entries use v2.1+ multi-line format

### Technical Details
- PostToolUse hook archived to `hooks/archive/post-tool-use.sh`
- Hooks.json now only registers Stop hook
- Export.sh enhanced with multi-param and named-param regex patterns
- Migration creates `.claude/.track-backup/` before making changes
- `.ref-autotrack` marker updated with version info

## [2.3.0] - 2026-02-11

### Added
- **Smart prompt summarization** - Long user prompts (>500 chars, ~1 paragraph) automatically summarized to 100-150 chars using Claude Haiku
- **Graceful fallback** - If LLM summarization fails, falls back to verbatim prompt
- **Summarization indicator** - Appends "(summarized from N chars)" to show original length

### Changed
- Prompt handling now length-aware: short prompts (<500 chars) remain verbatim, long prompts get concise summaries
- Summary preserves key intent and important details while preventing file bloat

### Technical Details
- New `summarize_long_prompt()` function in `hooks/common/llm.sh`
- Uses structured outputs with JSON schema for guaranteed format
- Threshold: 500 chars (~1 paragraph typical length)
- Target summary: 100-150 chars (readable, preserves context)
- Cost: ~$0.00005 per long prompt (Haiku input/output)

## [2.2.0] - 2026-02-11

### Fixed
- **YAML frontmatter parsing** - Fixed "Unexpected token" errors in skill metadata by properly quoting description strings and using array syntax for allowed-tools fields
- **Skill loading** - All 7 skills now load without parse warnings in Claude Code debug logs
- **Plugin structure** - Removed empty commands/ directory, consolidated to user-invocable skills only

### Changed
- **Skill frontmatter format** - Quoted long description fields, used array syntax for allowed-tools: `[Read, Write, Bash]`
- **Structured outputs implementation** - LLM calls now use `--json-schema` flag with guaranteed-valid JSON responses
- **Stop hook output** - Changed from text parsing (awk/sed) to direct JSON extraction with jq for reliability

### Technical Details
- Skills affected: auto, config, export, help, init (all now use proper YAML quoting)
- LLM output uses Claude CLI structured outputs with inline JSON schemas
- Removed duplicate echo statements causing "NONE NONE" output
- Fixed AWK pattern matching causing double line printing
- Cache invalidation requires uninstall/reinstall for immediate effect

## [2.1.0] - 2026-02-09

### Added
- **Real-time Stop hook tracking** - Tracks prompts and tool calls after each Claude response instead of batch processing at session end
- **LLM-enhanced summaries** - Natural language documentation using Claude Haiku for outcome and tool call summarization
- **Multi-line output format** - Rich, structured metadata with `Outcome:`, `Files:`, `Summary:`, `Links:` fields
- **Intelligent significance classification** - LLM determines MAJOR vs MINOR instead of word count heuristic
- **Unified tool call extraction** - Sources tracking integrated into Stop hook for consistent attribution
- **Graceful LLM fallback** - Falls back to v2.0.5 truncation format if Claude CLI unavailable

### Changed
- **BREAKING:** Replaced SessionEnd batch processing with real-time Stop hook (no data loss if session crashes)
- **Output format:** Multi-line entries with structured fields instead of single-line truncated text
- **Sources format:** `[Attribution] Tool(params)` with multi-line `Summary:` instead of single-line result
- **Export tools:** Updated to parse both v2.0.5 (single-line) and v2.1.0 (multi-line) formats
- **Async execution:** Stop hook runs without blocking Claude's workflow (`async: true`, 30s timeout)
- **Loop prevention:** Critical `stop_hook_active` flag check prevents infinite hook recursion
- **Deduplication:** Tool calls deduplicated within each turn using bash associative arrays

### Removed
- **SessionEnd hook** - Archived to `hooks/archive/session-end.sh` (replaced by Stop hook)
- **UserPromptSubmit hook** - Archived to `hooks/archive/user-prompt-submit.sh` (Stop hook extracts prompts from transcript directly)

### Technical Details
- Stop hook fires once per Claude turn (after complete response with all tool results)
- LLM calls use Haiku model for cost-effective summarization (~$0.0002/turn for 2 calls)
- Transcript parsing extracts latest user/assistant messages via jq
- Multi-line parsing in export.sh maintains backward compatibility with v2.0.5 format
- Verbosity filtering uses LLM classification instead of word count
- Attribution (USER/CLAUDE) determined by LLM context analysis

### Migration
- Existing v2.0.5 entries continue to work with export tools (backward compatible)
- Stop hook activates automatically when plugin updates
- No configuration changes required
- Mixed format files supported (old and new entries in same file)

## [2.0.5] - 2026-02-09

### Fixed
- **Critical: Multi-turn conversation tracking** - UserPromptSubmit hook now captures ALL prompts during a session, not just the last one
- **JSONL storage format** - Prompts stored as compact JSON Lines for efficient parsing
- **SessionEnd pairing** - Processes all captured prompts and pairs each with corresponding assistant response from transcript
- **No data loss** - Complete conversation history preserved for methodology documentation

### Changed
- `user-prompt-submit.sh` - Appends prompts to `${session_id}_prompts.jsonl` instead of overwriting single file
- `session-end.sh` - Reads all prompts from JSONL and pairs with all transcript responses
- Backward compatible with old single-prompt files

### Technical Details
- Prompt storage: `{timestamp, sequence, prompt}` in JSONL format
- Sequential pairing: prompt[i] → response[i] from transcript
- Maintains verbosity filtering for each pair independently
- Cleanup includes new `_prompts.jsonl` temp files

## [2.0.4] - 2026-02-09

### Fixed
- Hook variable syntax for CLAUDE_PLUGIN_ROOT environment variable

## [2.0.3] - 2026-02-09

### Fixed
- Command frontmatter formatting in track plugin skills

## [2.0.2] - 2026-01-27

### Fixed
- Force cache rebuild with correct skill names (previous cache still had `track-` prefix)

## [2.0.1] - 2026-01-27

### Fixed
- Removed explicit hooks reference from plugin.json (Claude Code automatically loads hooks/hooks.json by convention)
- Fixed skill names to remove `track-` prefix (skills should be named `init`, `auto`, etc., not `track-init`, `track-auto`)

## [2.0.0] - 2026-01-27

### Added
- **Hooks-based automatic tracking** via PostToolUse, UserPromptSubmit, and SessionEnd hooks
- **New claude_usage/ directory** for tracked files (sources.md and prompts.md)
- **File preambles** explaining format, usage, and configuration in tracked files
- **Export functionality** via `/track:export` command:
  - `bibliography` - Markdown bibliography/works cited
  - `methodology` - Methodology section from prompts
  - `bibtex` - BibTeX entries for LaTeX papers
  - `citations` - Numbered citation list
  - `timeline` - Chronological timeline of all activity
- **EXPORT_PATH configuration** in `.claude/.ref-config`
- **Interactive configuration** via AskUserQuestion in `/track:config`
- **Session timestamps** in prompts.md for temporal tracking
- **Common utilities** in hooks/common.sh for shared functionality
- **Migration detection** for old CLAUDE_*.md files

### Changed
- **BREAKING:** Replaced skill-based tracking with hooks-based architecture
- **BREAKING:** Moved tracked files from root to `claude_usage/` directory
- **BREAKING:** File names changed from `CLAUDE_SOURCES.md`/`CLAUDE_PROMPTS.md` to `claude_usage/sources.md`/`claude_usage/prompts.md`
- **BREAKING:** Default behavior - tracking now enabled by default after `/track:init`
- **Enhanced:** `/track:init` now creates files with preambles and enables hooks
- **Enhanced:** `/track:auto` updated for hooks-based tracking with better messaging
- **Enhanced:** `/track:config` supports both interactive and direct modes
- **Enhanced:** All commands converted to skills with `disable-model-invocation: true`
- **Enhanced:** Improved `.ref-autotrack` marker file with metadata and timestamp
- **Updated:** Plugin description to reflect hooks-based architecture
- **Updated:** README.md with hooks architecture documentation (pending)

### Deprecated
- **ref-tracker skill** - No longer needed; hooks replace skill-based tracking
- **`/track:update` command** - Retroactive scanning unnecessary with real-time hooks

### Removed
- Manual skill activation requirement for tracking

### Fixed
- Tracking reliability - hooks guarantee all activity is captured
- No more missed sources/prompts due to skill not being invoked

### Migration
- Existing `.ref-autotrack` and `.ref-config` files work unchanged
- Run `/track:init` to migrate from old CLAUDE_*.md files to claude_usage/
- Remove manual `/track:update` calls from workflows
- Hooks activate automatically when plugin updates

## [1.2.1] - 2026-01-27
### Changed
- Plugin refinements and stability improvements
- Enhanced skill descriptions and documentation

## [1.1.1] - 2026-01-27
### Added
- CHANGELOG.md following Keep a Changelog format



### Changed
- Updated README.md with version badge and license information

### Changed
- Plugin validation and release preparation


[Unreleased]: https://github.com/cadrianmae/claude-marketplace/compare/track-v2.0.0...HEAD
[2.0.0]: https://github.com/cadrianmae/claude-marketplace/releases/tag/track-v2.0.0
[1.2.1]: https://github.com/cadrianmae/claude-marketplace/releases/tag/track-v1.2.1
[1.1.1]: https://github.com/cadrianmae/claude-marketplace/releases/tag/track-v1.1.1
