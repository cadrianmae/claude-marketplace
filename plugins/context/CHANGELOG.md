# Changelog

All notable changes to the context plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-07-25

### Added
- `context-manage` script (`bin/context-manage`) owning
  handover naming, direction mapping, listing, pruning, and send/receive.
- Persistent handover location under `$XDG_STATE_HOME/claude-context` (survives
  reboot; was `/tmp/claude-ctx`), configurable via `~/.claude/.context-config`.
- TTL auto-prune on send (default 90 days), `list` with LIVE/SUPERSEDED + stale
  markers, service-captured front-matter (git/cwd/time), and a size guard so
  oversized handovers are referenced by path rather than truncated.

### Changed
- `/context:send` and `/context:receive` now route through `context-manage`;
  the hardcoded `/tmp/claude-ctx` path and the `path` argument are removed.

## [1.3.2] - 2026-01-27
### Added
- CHANGELOG.md following Keep a Changelog format
- LICENSE file (MIT)


### Changed
- Updated README.md with version badge and license information

## [1.3.1] - 2026-01-27
### Fixed
- Fix dynamic injection syntax in context plugin (v1.3.1)

### Changed
- Plugin validation and release preparation


[Unreleased]: https://github.com/cadrianmae/claude-marketplace/compare/context-v1.3.2...HEAD
[1.3.2]: https://github.com/cadrianmae/claude-marketplace/releases/tag/context-v1.3.2
