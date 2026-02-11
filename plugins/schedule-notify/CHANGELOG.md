# Changelog

All notable changes to the schedule-notify plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-03
### Added
- Initial release of schedule-notify plugin
- UserPromptSubmit hook for checking scheduled notifications
- Global schedules configuration (~/.claude/schedules.json)
- Per-project schedules with add/replace modes (.claude/schedules.json)
- 60-second deduplication to prevent notification spam
- Five CLI skills: add, list, disable, enable, remove
- Helper scripts for schedule management
- State tracking to prevent duplicate notifications
- Support for special day values (weekdays, weekends, daily)
- Interactive and all-in-one modes for adding schedules

[Unreleased]: https://github.com/cadrianmae/claude-marketplace/compare/schedule-notify-v1.0.0...HEAD
[1.0.0]: https://github.com/cadrianmae/claude-marketplace/releases/tag/schedule-notify-v1.0.0
