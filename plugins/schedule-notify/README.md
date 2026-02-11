# Schedule Notify Plugin

Hook-based scheduled notification system for recurring reminders in Claude Code.

## Overview

Provides passive, time-based notifications that appear in your Claude Code conversation when scheduled times arrive.

**Key Features:**
- Global schedules apply everywhere
- Per-project schedules with configurable modes (add/replace)
- 60-second deduplication to prevent spam
- No external dependencies (cron/systemd)
- Simple CLI skills for management

## Installation

This plugin is available in the cadrianmae-claude-marketplace. Enable it through your Claude Code plugin settings.

**Dependencies:**
- `jq` - JSON processor (install: `sudo dnf install jq` on Fedora)

**Verify installation:**
```bash
/schedule:list
```

## Configuration

### Global Schedules

Global schedules apply to all projects and directories. Managed user-wide.

**Create global schedule:**
```bash
/schedule:add "Morning standup" --time 09:00 --days weekdays global
```

**File location:** `~/.claude/schedules.json`

**Format:**
```json
[
  {
    "id": "morning-standup",
    "time": "09:00",
    "message": "Morning standup time!",
    "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
    "enabled": true
  }
]
```

### Per-Project Schedules

Project schedules apply only within specific projects. Useful for project-specific reminders like deployment windows or sprint reviews.

**Create project schedule:**
```bash
/schedule:add "Deploy window" --time 16:00 --days Mon,Wed,Fri
```

**File location:** `.claude/schedules.json` (in project root)

**Format:**
```json
{
  "mode": "add",
  "schedules": [
    {
      "id": "deploy-window",
      "time": "16:00",
      "message": "Daily deployment window",
      "days": ["Mon", "Wed", "Fri"],
      "enabled": true
    }
  ]
}
```

### Project Modes

**Mode: "add" (default)**
- Merges project schedules with global schedules
- Both global and project notifications appear

**Mode: "replace"**
- Uses only project schedules
- Ignores global schedules
- Useful for focused work sessions (e.g., pomodoro mode)

## Usage

### Add Schedule

**Interactive mode:**
```bash
/schedule:add
```
Claude prompts for message, time, days, and scope.

**All-in-one mode:**
```bash
# Weekday standup
/schedule:add "Standup time!" --time 09:00 --days weekdays

# Global afternoon break
/schedule:add "Take a break" --time 15:00 --days weekdays global

# Weekend reminder
/schedule:add "Weekend planning" --time 10:00 --days weekends

# Specific days
/schedule:add "Deploy day" --time 16:00 --days Mon,Wed,Fri

# Daily reminder
/schedule:add "End of day review" --time 17:00 --days daily
```

**Special day values:**
- `weekdays` → Mon,Tue,Wed,Thu,Fri
- `weekends` → Sat,Sun
- `daily` → Every day (*)

### List Schedules

```bash
/schedule:list              # Show all (global + project)
/schedule:list global       # Global only
/schedule:list project      # Project only
```

### Disable/Enable Schedule

```bash
# Disable (keeps configuration)
/schedule:disable morning-standup
/schedule:disable afternoon-break global

# Re-enable
/schedule:enable morning-standup
/schedule:enable afternoon-break global
```

### Remove Schedule

```bash
# Remove permanently (cannot be undone)
/schedule:remove deploy-window
/schedule:remove morning-standup global
```

## How It Works

The plugin uses a `UserPromptSubmit` hook that runs every time you send a message to Claude:

1. Checks current time and day
2. Matches against your schedules
3. Shows notifications for matches (if not shown in last 60 seconds)
4. Tracks state to prevent duplicates

**Passive notifications:** Reminders appear on your next prompt after the scheduled time, not immediately.

**Deduplication:** Notifications shown once per schedule within 60-second window to prevent spam.

## State Management

State files track last-shown timestamps:

- **Global:** `~/.claude/.schedule-state.json`
- **Project:** `.claude/.schedule-state.json`

Auto-created and managed by hook. Can be manually reset by deleting them.

## Examples

### Daily Standup
```bash
/schedule:add "Daily standup in 5 minutes" --time 08:55 --days weekdays global
```

### Lunch Break
```bash
/schedule:add "Time for lunch break!" --time 12:30 --days daily global
```

### Code Review Friday
```bash
/schedule:add "Friday code review session" --time 14:00 --days Fri
```

### Pomodoro (Project-Specific)
```json
{
  "mode": "replace",
  "schedules": [
    {
      "id": "work-block",
      "time": "09:00",
      "message": "Start 25-minute work block",
      "days": ["*"],
      "enabled": true
    },
    {
      "id": "break-time",
      "time": "09:25",
      "message": "5-minute break",
      "days": ["*"],
      "enabled": true
    }
  ]
}
```

## Troubleshooting

### No notifications appear

1. Check time format is HH:MM (24-hour)
2. Verify day abbreviations: Mon, Tue, Wed, Thu, Fri, Sat, Sun
3. Check `enabled: true` in configuration
4. Validate JSON: `jq . ~/.claude/schedules.json`
5. Wait 60+ seconds after last notification

### Notifications spam every prompt

- Check state files exist and are writable:
  - `~/.claude/.schedule-state.json`
  - `.claude/.schedule-state.json`
- Delete state files to reset

### Hook errors

**Missing jq:**
```bash
sudo dnf install jq
```

**Permission denied:**
```bash
chmod +x ~/.claude/plugins/.../hooks/scripts/check-schedule.sh
```

**Invalid JSON:**
```bash
jq . ~/.claude/schedules.json  # Check syntax errors
```

## Testing

To test without waiting for real time, temporarily modify the hook script:

**File:** Hook script in plugin installation

**Add after `set -euo pipefail`:**
```bash
# Test overrides
CURRENT_TIME="09:00"
CURRENT_DAY="Mon"
```

**Replace time/day lines:**
```bash
local current_time="$CURRENT_TIME"
local current_day="$CURRENT_DAY"
```

Submit a prompt - notifications should appear immediately.

**Remember to restore the original time/day code after testing!**

## Skills

- `/schedule:add` - Add new schedule
- `/schedule:list` - View schedules
- `/schedule:disable` - Disable schedule
- `/schedule:enable` - Enable schedule
- `/schedule:remove` - Remove schedule

## License

MIT
