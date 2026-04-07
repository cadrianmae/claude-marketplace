# Cron Plugin

Hook-based scheduled notification system for recurring reminders in Claude Code.

## Overview

Provides passive, time-based notifications that appear in your Claude Code conversation when scheduled times arrive.

**Key Features:**
- Full **crontab(5) syntax** for schedules (5 fields, ranges, lists, steps, named months/days)
- **Dynamic notification text** via shell commands (`date`, `git`, `curl`, etc.)
- **Anacron-style catch-up** by default — missed ticks fire on the next prompt; toggleable per schedule
- Per-tick deduplication — each matching tick fires exactly once
- Global and per-project schedules with add/replace modes
- Legacy `time`+`days` form still supported

## Cron Syntax

Standard 5-field crontab(5):

```
MIN  HOUR  DOM  MONTH  DOW
0-59 0-23  1-31 1-12   0-7  (0 or 7 = Sunday)
```

Operators: `*`, `a-b`, `a,b`, `*/n`, `a-b/n`. Named months (`jan`-`dec`) and days (`sun`-`sat`).

> **OR rule:** if both day-of-month and day-of-week are restricted (neither is `*`), the match is **OR** — same as `crond`. E.g. `0 9 1,15 * 5` fires on the 1st, the 15th, **and** every Friday at 9:00.

### Quick examples

```bash
# Hourly chime with live timestamp
/cron --command "date '+Chime: %H:%M %A'" --cron "0 * * * *" global

# Every 15 minutes during work hours, weekdays
/cron "Stretch break" --cron "*/15 9-17 * * 1-5" global

# Standup at 9:00 weekdays, no catchup (only fires if active in that minute)
/cron "Standup time!" --cron "0 9 * * 1-5" --catchup false global
```

### catchup

| Value | Behavior |
|---|---|
| `true` (default) | Anacron-style. If a tick was missed (no prompt during that minute), the next prompt still fires it once. |
| `false` | Strict cron. Only fires if the matching tick is in the current wall-clock minute. Missed ticks are lost. |

### message vs command

- `message` — static text (positional argument).
- `--command` — shell command run via `bash -c`; stdout becomes the notification text. Lets the message change every time it fires.

Mutually exclusive. Commands run with your shell privileges; treat `~/.claude/schedules.json` as trusted (same as `~/.bashrc`).

## Installation

This plugin is available in the cadrianmae-claude-marketplace. Enable it through your Claude Code plugin settings.

**Dependencies:**
- `jq` - JSON processor (`sudo dnf install jq` on Fedora)
- `python3` - cron expression evaluator (preinstalled on Fedora)

**Verify installation:**
```bash
/cron
```

## Configuration

### Global Schedules

Global schedules apply to all projects and directories. Managed user-wide.

**Create global schedule:**
```bash
/cron "Morning standup" --time 09:00 --days weekdays global
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
/cron "Deploy window" --time 16:00 --days Mon,Wed,Fri
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
/cron
```
Claude prompts for message, time, days, and scope.

**All-in-one mode:**
```bash
# Weekday standup
/cron "Standup time!" --time 09:00 --days weekdays

# Global afternoon break
/cron "Take a break" --time 15:00 --days weekdays global

# Weekend reminder
/cron "Weekend planning" --time 10:00 --days weekends

# Specific days
/cron "Deploy day" --time 16:00 --days Mon,Wed,Fri

# Daily reminder
/cron "End of day review" --time 17:00 --days daily
```

**Special day values:**
- `weekdays` → Mon,Tue,Wed,Thu,Fri
- `weekends` → Sat,Sun
- `daily` → Every day (*)

### List Schedules

```bash
/cron              # Show all (global + project)
/cron global       # Global only
/cron project      # Project only
```

### Disable / Enable / Remove

Run `/cron` and pick the action. The skill lists existing schedules so you can pick one by id. `disable` keeps the entry (so it can be re-enabled later); `remove` deletes it.

## How It Works

The plugin uses a `UserPromptSubmit` hook that runs every time you send a message to Claude:

1. For each schedule, computes the most recent matching minute (the "tick") using the cron expression
2. Compares it against the last tick that was already fired (stored in the state file)
3. Fires the notification if this tick is newer — including ticks missed while you were away (anacron-style catch-up), unless `catchup` is set to `false`
4. Records the fired tick so the same tick is never shown twice

**Passive notifications:** Reminders appear on your next prompt after the scheduled tick, not immediately.

**Deduplication:** Per-tick, not time-windowed. A given matching minute fires exactly once; subsequent prompts in the same minute (or any time before the next matching tick) produce nothing.

## State Management

State files track last-shown timestamps:

- **Global:** `~/.claude/.schedule-state.json`
- **Project:** `.claude/.schedule-state.json`

Auto-created and managed by hook. Can be manually reset by deleting them.

## Examples

### Daily Standup
```bash
/cron "Daily standup in 5 minutes" --time 08:55 --days weekdays global
```

### Lunch Break
```bash
/cron "Time for lunch break!" --time 12:30 --days daily global
```

### Code Review Friday
```bash
/cron "Friday code review session" --time 14:00 --days Fri
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

## Command

A single unified interactive command:

- `/cron` — Interactive entry point for add / list / enable / disable / remove. Uses AskUserQuestion to walk through each workflow. Accepts arguments to skip prompts (e.g. `/cron list`, `/cron add "Standup" --cron "0 9 * * 1-5" global`).

## License

MIT
