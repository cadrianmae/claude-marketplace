# Changelog

All notable changes to the cron plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.2.1] - 2026-04-07
### Fixed
- **Hook jq-bootstrap error.** If `jq` itself was missing, the dependency check still tried to emit its error message via `jq -n`, which obviously failed and hid the real cause. The `jq`-missing branch now prints a literal JSON string via `printf`. (Copilot review)
- **`/tmp/.cron-cmd-err` race condition.** `resolve_text` captured command stderr to a fixed shared path, so concurrent hook invocations (multiple Claude sessions) could clobber each other. Now uses a per-invocation `mktemp` file. (Copilot review)
- **`prev_tick()` performance.** Replaced minute-by-minute walk with field-aware jumping: on a mismatch the algorithm skips directly to the previous allowed month/day/hour/minute boundary. Sparse expressions (e.g. yearly) now resolve in microseconds instead of iterating hundreds of thousands of minutes per prompt. (Copilot review)
- **Leap-year lookback.** Bumped `prev_tick` lookback from 1 year to 4 years so expressions like `30 4 29 2 *` (Feb 29) resolve in non-leap years. The new jumping algorithm makes the larger bound effectively free.
- **Stale README dedup docs.** "How It Works" and "Deduplication" sections still described the old 60-second dedup window; rewritten to reflect the per-tick state-file model with anacron-style catch-up. (Copilot review)

## [2.2.0] - 2026-04-07
### Added
- New `bin/` directory with thin wrapper scripts (`cron-add`, `cron-list`, `cron-edit`, `cron-modify`, `cron-match`). Claude Code puts each plugin's `bin/` on `PATH` automatically, so the skill can now invoke helpers as bare commands with no path construction.

### Changed
- **Skill now calls helpers as bare commands** (e.g. `cron-list all`) instead of `bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-list.sh"`. This works around [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354): `$CLAUDE_PLUGIN_ROOT` is not substituted inside SKILL.md files, causing previous invocations to silently expand to empty and fail with "No such file or directory".
- **Renamed all `schedule-*` code files to `cron-*`** for consistency with the plugin name:
  - `scripts/schedule-add.sh` → `scripts/cron-add.sh`
  - `scripts/schedule-list.sh` → `scripts/cron-list.sh`
  - `scripts/schedule-edit.sh` → `scripts/cron-edit.sh`
  - `scripts/schedule-modify.sh` → `scripts/cron-modify.sh`
  - `hooks/check-schedule.sh` → `hooks/check-cron.sh`
- Hook status message updated: `"Checking scheduled notifications..."` → `"Checking cron schedules..."`.

### Not changed (preserved for backwards compatibility)
- User data files keep their original names: `~/.claude/schedules.json`, `.claude/schedules.json`, `~/.claude/.schedule-state.json`, `.claude/.schedule-state.json`. Renaming these would silently break every existing installation.

## [2.1.0] - 2026-04-07
### Added
- New `edit` subcommand and `scripts/schedule-edit.sh` helper. Modifies fields of an existing schedule in place; mutually-exclusive groups (`cron` vs `time/days`, `message` vs `command`) are handled automatically.
- New `help` subcommand that prints subcommand grammar and cron syntax reference inline (no helper script).

### Changed
- **Unified all commands into a single interactive `/cron` entry point** driven by AskUserQuestion. Replaces the five separate `/cron:add`, `/cron:list`, `/cron:enable`, `/cron:disable`, `/cron:remove` skills with one workflow-driven skill that branches per action. Helper scripts are unchanged — the new skill calls them under the hood.
- Subcommand grammar formalized: `/cron <add|list|edit|enable|disable|remove|help> [args...]`. With no arguments, runs the fully interactive flow.

### Removed
- `cron:add`, `cron:list`, `cron:enable`, `cron:disable`, `cron:remove` skill subdirectories. All functionality is reachable from `/cron`.

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
