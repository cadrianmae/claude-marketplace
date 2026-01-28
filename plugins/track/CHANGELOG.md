# Changelog

All notable changes to the track plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
