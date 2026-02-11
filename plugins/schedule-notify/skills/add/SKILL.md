---
name: schedule:add
description: This skill should be used when the user asks to "add a schedule", "create a reminder", "set up notification", "schedule a standup", "add recurring task", or wants to configure scheduled notifications.
version: 1.0.0
user-invocable: true
allowed-tools: [Bash, AskUserQuestion]
argument-hint: "[message] [--time HH:MM] [--days Days] [global]"
---

# Add Scheduled Notification

Add a new scheduled notification to the system. Supports both interactive mode (prompts for inputs) and all-in-one mode (parses arguments directly).

## When to Use

Use this skill when the user wants to:
- Create a new recurring reminder
- Set up time-based notifications
- Schedule standups, breaks, or reviews
- Add project-specific or global schedules

## Modes of Operation

### Interactive Mode (No Arguments Provided)

When `$ARGUMENTS` is empty, use AskUserQuestion to collect inputs from the user.

**Collect the following information:**

1. **Message** - What should the notification say?
   - Example: "Morning standup time!"
   - Example: "Break reminder - step away from screen"

2. **Time** - When should it trigger? (HH:MM format, 24-hour)
   - Example: "09:00", "15:30", "14:00"
   - Validate format: Must be HH:MM with valid hours (00-23) and minutes (00-59)

3. **Days** - Which days should it trigger?
   - Options:
     - `weekdays` → Mon,Tue,Wed,Thu,Fri
     - `weekends` → Sat,Sun
     - `daily` → Every day (*)
     - Custom: `Mon,Tue,Wed` or any combination
   - Multiple days separated by commas

4. **Scope** - Global (all projects) or project-specific?
   - Default: project
   - Use `global` for schedules that apply everywhere

**Implementation:**

```bash
# Use AskUserQuestion to gather inputs
# Then call helper script with collected values
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-add.sh" \
  "$message" \
  --time "$time" \
  --days "$days" \
  $scope
```

### All-In-One Mode (Arguments Provided)

When `$ARGUMENTS` contains parameters, parse them directly and call the helper script.

**Argument Format:**
```
"message" --time HH:MM --days Days [global]
```

**Examples:**
```bash
# Weekday standup
"Standup time!" --time 09:00 --days weekdays

# Global afternoon break
"Take a break" --time 15:00 --days weekdays global

# Weekend reminder
"Weekend planning session" --time 10:00 --days weekends

# Specific days
"Deploy day" --time 16:00 --days Mon,Wed,Fri

# Daily reminder
"End of day review" --time 17:00 --days daily
```

**Implementation:**

```bash
# Pass arguments directly to helper script
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-add.sh" $ARGUMENTS
```

## Special Day Values

The helper script expands special day keywords:

| Keyword | Expands To |
|---------|------------|
| `weekdays` | Mon,Tue,Wed,Thu,Fri |
| `weekends` | Sat,Sun |
| `daily` | * (wildcard, matches every day) |

Custom day lists use three-letter abbreviations: Mon, Tue, Wed, Thu, Fri, Sat, Sun

## Schedule ID Generation

When no ID is explicitly provided, the helper script auto-generates an ID by slugifying the message:

- Message: "Morning standup time!" → ID: `morning-standup-time`
- Message: "Break reminder - step away" → ID: `break-reminder-step-away`

This ensures unique, readable IDs without user input.

## Scope Behavior

**Project scope (default):**
- Creates `.claude/schedules.json` in current directory
- Applies only to this project
- Mode defaults to "add" (merges with global schedules)

**Global scope:**
- Updates `~/.claude/schedules.json`
- Applies to all projects and directories
- No mode configuration (always active)

## Validation

The helper script validates inputs:

1. **Time format:** Must be HH:MM with valid hours (00-23) and minutes (00-59)
2. **Days:** Must be valid day abbreviations or special keywords
3. **Message:** Must not be empty

Invalid inputs return error messages with correction guidance.

## Configuration Files

**Global schedules:**
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

**Project schedules:**
```json
{
  "mode": "add",
  "schedules": [
    {
      "id": "deploy-window",
      "time": "16:00",
      "message": "Daily deployment window",
      "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
      "enabled": true
    }
  ]
}
```

## Helper Script Reference

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/schedule-add.sh`:

**Responsibilities:**
- Parses and validates inputs
- Expands special day keywords
- Generates IDs from messages
- Creates schedule JSON objects
- Updates appropriate configuration file
- Auto-creates missing files (schedules.json, .claude/ directory)
- Returns success/error messages

**Exit codes:**
- 0: Success, schedule added
- 1: Validation error or missing required inputs

## Usage Examples

**Interactive mode:**
```
User: /schedule:add
Claude: [Prompts for message, time, days, scope]
```

**All-in-one mode:**
```
User: /schedule:add "Standup" --time 09:00 --days weekdays
Claude: [Adds schedule directly]

User: /schedule:add "Break time" --time 15:00 --days daily global
Claude: [Adds global schedule]
```

## Tips

- Use `weekdays` for most work-related reminders
- Use `global` scope for reminders that apply everywhere (breaks, standup)
- Use `project` scope for project-specific reminders (deploy windows, sprint reviews)
- Time is in 24-hour format (use 14:00 instead of 2:00 PM)
- Notifications appear on the next user prompt after the scheduled time
