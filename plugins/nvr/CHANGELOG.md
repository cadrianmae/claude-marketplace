# Changelog

All notable changes to the nvr plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.1] - 2026-04-13

### Fixed
- Standardise author name in plugin manifest

## [2.0.0] - 2026-04-13

### Added
- Unified `/nvr` skill with subcommand grammar:
  `/nvr <open|list|status|workspace|help> [args...]`.
  User-invocable with AUQ interactive flow when called without args.
- Git-root-aware socket discovery. `nvr-discover` now tries git root
  matching first (immune to `:lcd` changes from autocmds like
  cmp-pandoc-references), then falls back to closest parent cwd match.
- Dynamic workspace injection in SKILL.md -- auto-captures current
  socket, instance count, and instance list on skill load.
- CHANGELOG.md (this file).

### Changed
- **Breaking:** 4 separate skills (`nvr-open`, `nvr-list`, `nvr-status`,
  `nvr-workspace`) consolidated into single `/nvr` skill.
- Scripts moved from per-skill `skills/*/scripts/` to shared `scripts/`
  directory. bin/ wrappers updated to match.
- Socket matching picks closest (longest prefix) match instead of first
  match, fixing incorrect instance targeting with multiple sessions.

### Removed
- Legacy `commands/` directory (4 markdown files).
- Per-skill directories with duplicate `nvr-discover` copies.

### Fixed
- **#12:** Socket discovery picks wrong neovim instance when one has
  `:lcd`'d to a subdirectory. Git root matching makes discovery immune
  to working directory changes from autocmds.
- **#4:** Plugin consolidated from 4 separate skills into unified `/nvr`
  command following the cron/tts/audio-feedback pattern.

## [1.0.2] - 2026-04-12

### Added
- Initial release with 4 separate skills: open, list, status, workspace.
- Socket discovery based on neovim getcwd() matching.
- bin/ wrappers for PATH-based invocation from SKILL.md.
- $NVIM_SOCKET environment override.
