# Changelog

All notable changes to the track plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
