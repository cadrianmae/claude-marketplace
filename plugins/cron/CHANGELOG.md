# Changelog

All notable changes to the cron plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-04-07
### Added
- **Cron expression support** via new `cron` field on schedules. Full crontab(5) syntax: 5 fields, ranges, lists, steps, named months/days, and the OR-rule for restricted day-of-month/day-of-week.
- **`command` field** as an alternative to `message`. Runs the value via `bash -c` and uses stdout as the notification text. Enables dynamic content (e.g. `date '+%H:%M'`).
- **`catchup` toggle** (default `true`). When true, missed ticks fire on the next prompt (anacron-style). When false, only ticks in the current wall-clock minute fire.
- New `--cron`, `--command`, `--catchup` flags on `cron:add`.
- New helper script `scripts/cron-match.py` (Python) — pure-Python cron evaluator that returns the most recent matching tick.

### Changed
- **Renamed plugin from `schedule-notify` to `cron`.** All commands moved from `/schedule:*` to `/cron:*`.
- Dedup model rewritten: now per-tick (`last_fired_tick` per schedule), not per-day. A given matching tick fires exactly once.
- Hook now uses unified cron-based matching for both new `cron`-style schedules and legacy `time`+`days` schedules (legacy entries are converted to a synthesized cron expression at load time, so they keep working unchanged).
- New dependency: `python3` (already present on Fedora).

### Fixed
- Disabled schedules (`enabled: false`) were incorrectly firing because `jq`'s `//` operator treats `false` the same as `null`. Now tested explicitly.

## [1.0.0] - 2026-02-03
### Added
- Initial release of cron plugin
- UserPromptSubmit hook for checking scheduled notifications
- Global schedules configuration (~/.claude/schedules.json)
- Per-project schedules with add/replace modes (.claude/schedules.json)
- 60-second deduplication to prevent notification spam
- Five CLI skills: add, list, disable, enable, remove
- Helper scripts for schedule management
- State tracking to prevent duplicate notifications
- Support for special day values (weekdays, weekends, daily)
- Interactive and all-in-one modes for adding schedules

[Unreleased]: https://github.com/cadrianmae/claude-marketplace/compare/cron-v1.0.0...HEAD
[1.0.0]: https://github.com/cadrianmae/claude-marketplace/releases/tag/cron-v1.0.0
