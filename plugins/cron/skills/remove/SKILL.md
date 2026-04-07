---
name: cron:remove
description: This skill should be used when the user asks to "remove a schedule", "delete reminder", "delete notification", "remove schedule permanently", "unschedule task", or wants to permanently delete a scheduled notification.
version: 1.0.0
user-invocable: true
allowed-tools: [Bash]
argument-hint: "<schedule-id> [global|project]"
---

# Remove Scheduled Notification

Permanently delete a scheduled notification from configuration. This action cannot be undone.

## When to Use

Use this skill when the user wants to:
- Permanently delete a reminder
- Remove a schedule completely
- Clean up old notifications
- Delete a recurring task permanently

## Arguments

**Required:**
- `<schedule-id>` - The ID of the schedule to remove

**Optional:**
- `global` or `project` - Scope to search (default: project)

## Implementation

Call the helper script with the remove operation:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-modify.sh" remove $ARGUMENTS
```

## Behavior

The helper script:
1. Finds the schedule by ID in the specified scope
2. Deletes the schedule entry from the JSON configuration
3. Confirms the schedule was removed

**Warning:** This action is permanent. The schedule configuration is completely removed and cannot be recovered unless manually recreated.

## Disable vs Remove

**Use `/cron:disable` if:**
- You might want to re-enable later
- You want to keep the configuration
- You're temporarily stopping notifications

**Use `/cron:remove` if:**
- You no longer need the schedule
- You're cleaning up old reminders
- You want to permanently delete

## Scope Selection

**Project scope (default):**
```bash
/cron:remove morning-standup
```
Removes from `.claude/schedules.json`

**Global scope:**
```bash
/cron:remove morning-standup global
```
Removes from `~/.claude/schedules.json`

## Finding Schedule IDs

Use `/cron:list` to see all schedule IDs:

```
[GLOBAL] [ENABLED] morning-standup - 09:00 on Mon, Tue, Wed, Thu, Fri
                    ^^^^^^^^^^^^^^^
                    This is the ID to remove
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
- Deletes the schedule object from JSON array
- Preserves other schedules in the file
- Returns success/error messages

**Parameters:**
- Operation: `remove`
- Schedule ID: Required
- Scope: `project` (default) or `global`

## Usage Examples

**Remove project schedule:**
```
User: /cron:remove deploy-window
Claude: [OK] Removed schedule: deploy-window (scope: project)
```

**Remove global schedule:**
```
User: /cron:remove afternoon-break global
Claude: [OK] Removed schedule: afternoon-break (scope: global)
```

## Tips

- Use `/cron:list` to verify which schedules exist before removing
- Consider `/cron:disable` for temporary deactivation instead
- Removed schedules must be manually recreated with `/cron:add`
- Double-check the scope (global vs project) before removing
- No confirmation prompt - removal is immediate
