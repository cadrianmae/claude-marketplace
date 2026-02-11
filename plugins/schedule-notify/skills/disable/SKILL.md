---
name: schedule:disable
description: This skill should be used when the user asks to "disable a schedule", "turn off reminder", "pause notification", "stop schedule temporarily", or wants to temporarily deactivate a scheduled notification without deleting it.
version: 1.0.0
user-invocable: true
allowed-tools: [Bash]
argument-hint: "<schedule-id> [global|project]"
---

# Disable Scheduled Notification

Temporarily disable a scheduled notification without deleting it. The schedule remains in configuration but won't trigger notifications.

## When to Use

Use this skill when the user wants to:
- Temporarily stop a reminder
- Pause a notification without losing configuration
- Disable a schedule while keeping it for later
- Turn off a recurring task temporarily

## Arguments

**Required:**
- `<schedule-id>` - The ID of the schedule to disable

**Optional:**
- `global` or `project` - Scope to search (default: project)

## Implementation

Call the helper script with the disable operation:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-modify.sh" disable $ARGUMENTS
```

## Behavior

The helper script:
1. Finds the schedule by ID in the specified scope
2. Sets `"enabled": false` in the JSON configuration
3. Confirms the schedule was disabled

**Important:** The schedule remains in the configuration file. It can be re-enabled later with `/schedule:enable`.

## Scope Selection

**Project scope (default):**
```bash
/schedule:disable morning-standup
```
Searches in `.claude/schedules.json`

**Global scope:**
```bash
/schedule:disable morning-standup global
```
Searches in `~/.claude/schedules.json`

## Finding Schedule IDs

Use `/schedule:list` to see all schedule IDs:

```
[GLOBAL] [ENABLED] morning-standup - 09:00 on Mon, Tue, Wed, Thu, Fri
                    ^^^^^^^^^^^^^^^
                    This is the ID
```

## Error Handling

**Schedule not found:**
```
[ERROR] Schedule not found: invalid-id (scope: project)
```

Check the ID spelling or try the other scope (global/project).

## Helper Script Reference

The helper script at `$CLAUDE_PLUGIN_ROOT/scripts/schedule-modify.sh`:

**Responsibilities:**
- Finds schedule by ID in specified scope
- Updates `enabled` field to `false`
- Preserves all other schedule configuration
- Returns success/error messages

**Parameters:**
- Operation: `disable`
- Schedule ID: Required
- Scope: `project` (default) or `global`

## Usage Examples

**Disable project schedule:**
```
User: /schedule:disable deploy-window
Claude: [OK] Disabled schedule: deploy-window (scope: project)
```

**Disable global schedule:**
```
User: /schedule:disable afternoon-break global
Claude: [OK] Disabled schedule: afternoon-break (scope: global)
```

## Tips

- Use disable (not remove) if you might want to re-enable later
- Disabled schedules still appear in `/schedule:list` with `[DISABLED]` status
- Re-enable with `/schedule:enable <id>`
- To permanently delete, use `/schedule:remove` instead
