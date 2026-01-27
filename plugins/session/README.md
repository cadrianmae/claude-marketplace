[![Version](https://img.shields.io/badge/version-1.3.2-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Session Management Plugin

Flat session management system for Claude Code development workflows using `.current-session` file tracking.

## Origin

This plugin is adapted from **[claude-sessions](https://github.com/iannuttall/claude-sessions)** by Ian Nuttall (MIT License).

See [ATTRIBUTION.md](./ATTRIBUTION.md) for detailed attribution and modification information.

## Commands

### `/session-start [name]`
Start a new development session by creating a timestamped markdown file in `.claude/sessions/`.

**Format:** `YYYY-MM-DD-HHMM-name.md`

Creates session file with:
- Session name and timestamp
- Overview with start time
- Goals section
- Empty progress section

Updates `.claude/sessions/.current-session` to track the active session.

### `/session-end`
End the current development session with a comprehensive summary including:
- Session duration
- Git summary (files changed, commits, status)
- Todo summary (completed/remaining tasks)
- Key accomplishments, features, problems, solutions
- Breaking changes, dependencies, configuration changes
- Lessons learned and tips for future developers

Clears `.claude/sessions/.current-session`.

### `/session-update [notes]`
Add update to current session with:
- Timestamp
- Notes (from arguments or auto-summary)
- Git status summary
- Todo list status
- Issues and solutions

### `/session-current`
Show current session status:
- Session name and filename
- Duration since start
- Last few updates
- Current goals/tasks

### `/session-list`
List all development sessions:
- All `.md` files in `.claude/sessions/`
- Filename, title, date/time, overview
- Highlights currently active session
- Sorted by most recent first

### `/session-resume [filename]`
Resume a previous development session:
- Display session overview and goals
- Calculate elapsed time
- Show last updates
- Update `.current-session` to mark as active

### `/session-help`
Show help for the session management system with available commands, workflow, and best practices.

## Workflow Example

```bash
/session-start refactor-auth
# Work on authentication refactoring...
/session-update Added Google OAuth restriction
# Continue working...
/session-update Fixed Next.js 15 params Promise issue
/session-end
```

## Modifications from Original

This plugin includes the following adaptations by Mae Capacite:

1. **Namespace changes:** `/project:session-*` → `/session-*` for user-level commands
2. **New command:** Added `/session-resume` for resuming previous sessions
3. **Plugin packaging:** Proper Claude Code plugin structure with manifest
4. **Git subtree:** Original code preserved in `upstream/` directory

## Installation

```bash
/plugin install session-management@cadrianmae-claude-marketplace
```

## License

MIT License - See [LICENSE](./LICENSE) file

Original work Copyright (c) Ian Nuttall
Modifications Copyright (c) Mae Capacite
