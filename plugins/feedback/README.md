# feedback

Track bugs and feature requests for cadrianmae-claude-marketplace plugins.

## Overview

This plugin provides commands to log bugs and feature requests for marketplace plugins. All feedback is timestamped and appended to the marketplace's FEEDBACK.md file for later review and implementation in dedicated development sessions.

**IMPORTANT:** This plugin is for LOGGING ONLY. Claude will not attempt to implement fixes or features when using these commands - it will log them and continue with your current work.

## Commands

### `/feedback:bug`

Log a bug report for the marketplace.

**Usage:**
```bash
/feedback:bug "Bug description here"
```

**Example:**
```bash
/feedback:bug "Session management /current command shows stale session info"
```

**What it does:**
1. Asks clarifying questions if description is unclear
2. Appends timestamped bug entry to FEEDBACK.md
3. Confirms it's logged and returns to your current work
4. Does NOT implement the fix

### `/feedback:feature`

Log a feature request for the marketplace.

**Usage:**
```bash
/feedback:feature "Feature description here"
```

**Example:**
```bash
/feedback:feature "Add /session:archive command to move old sessions to archive directory"
```

**What it does:**
1. Asks clarifying questions if description is unclear
2. Appends timestamped feature request to FEEDBACK.md
3. Confirms it's logged and returns to your current work
4. Does NOT implement the feature

## Output

Both commands append to `~/.claude/marketplaces/cadrianmae-claude-marketplace/FEEDBACK.md`:

```markdown
## Bugs

- [2026-01-26] Bug description here

## Feature Requests

- [2026-01-26] Feature description here
```

## Installation

This plugin is part of the cadrianmae-claude-marketplace. No additional installation needed.

## Author

Mae Capacite (cadrianmae@users.noreply.github.com)

## Version

1.0.1

## License

MIT
