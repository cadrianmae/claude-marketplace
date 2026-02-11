---
name: schedule:list
description: This skill should be used when the user asks to "list schedules", "show reminders", "view notifications", "what schedules exist", "display my reminders", or wants to see configured scheduled notifications.
version: 1.0.0
user-invocable: true
allowed-tools: [Bash]
argument-hint: "[global|project|all]"
---

# List Scheduled Notifications

Display all configured scheduled notifications with their settings and status.

## When to Use

Use this skill when the user wants to:
- View all configured schedules
- Check what reminders are active
- See global vs project-specific schedules
- Verify schedule configuration

## Scope Options

Control which schedules to display:

| Argument | Shows |
|----------|-------|
| `global` | Only global schedules from `~/.claude/schedules.json` |
| `project` | Only project schedules from `.claude/schedules.json` |
| `all` | Both global and project schedules (default) |

## Implementation

Call the helper script with the requested scope:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-list.sh" ${ARGUMENTS:-all}
```

**Default:** If no argument provided, defaults to `all` (shows both scopes).

## Output Format

The helper script formats schedules with:

**Scope label:** `[GLOBAL]` or `[PROJECT]`
**Status:** `[ENABLED]` or `[DISABLED]`
**ID:** Schedule identifier
**Time:** When it triggers (HH:MM)
**Days:** Which days it runs
**Message:** Notification text

**Example output:**
```
=== Global Schedules ===
[GLOBAL] [ENABLED] morning-standup - 09:00 on Mon, Tue, Wed, Thu, Fri
  Message: Morning standup time!

[GLOBAL] [ENABLED] afternoon-break - 15:00 on Mon, Tue, Wed, Thu, Fri
  Message: Break reminder - step away from the screen

=== Project Schedules (mode: add) ===
[PROJECT] [ENABLED] deploy-window - 16:00 on Mon, Wed, Fri
  Message: Daily deployment window

[PROJECT] [DISABLED] code-review - 14:00 on Fri
  Message: Friday code review session
```

## Project Mode Display

For project schedules, the output includes the mode:
- **mode: add** - Merges with global schedules
- **mode: replace** - Uses only project schedules, ignores global

This helps understand which schedules will actually trigger.

## Empty Schedule Handling

When no schedules exist for a scope, helpful messages appear:

```
[INFO] No global schedules found
[INFO] No project schedules found
```

## Helper Script Reference

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/schedule-list.sh`:

**Responsibilities:**
- Reads global schedules from `~/.claude/schedules.json`
- Reads project schedules from `.claude/schedules.json` (if exists)
- Formats output with scope labels and status
- Shows project mode configuration
- Handles missing files gracefully

**Parameters:**
- `global` - Show only global schedules
- `project` - Show only project schedules
- `all` - Show both (default)

## Usage Examples

**Show all schedules:**
```
User: /schedule:list
Claude: [Displays global and project schedules]
```

**Show only global:**
```
User: /schedule:list global
Claude: [Displays only global schedules]
```

**Show only project:**
```
User: /schedule:list project
Claude: [Displays only project schedules]
```

## Tips

- Use `all` (default) to see complete picture of active notifications
- Use `global` to audit organization-wide reminders
- Use `project` to see project-specific configuration
- Disabled schedules still appear in output but won't trigger
- Project mode indicates whether global schedules will merge or be replaced
