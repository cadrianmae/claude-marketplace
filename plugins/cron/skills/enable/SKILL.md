---
name: cron:enable
description: This skill should be used when the user asks to "enable a schedule", "turn on reminder", "activate notification", "resume schedule", "re-enable notification", or wants to reactivate a previously disabled scheduled notification.
version: 1.0.0
user-invocable: true
allowed-tools: [Bash]
argument-hint: "<schedule-id> [global|project]"
---

# Enable Scheduled Notification

Re-enable a previously disabled scheduled notification. The schedule will start triggering notifications again according to its configured time and days.

## When to Use

Use this skill when the user wants to:
- Reactivate a disabled reminder
- Resume a paused notification
- Turn a schedule back on
- Re-enable a temporarily stopped task

## Arguments

**Required:**
- `<schedule-id>` - The ID of the schedule to enable

**Optional:**
- `global` or `project` - Scope to search (default: project)

## Implementation

Call the helper script with the enable operation:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-modify.sh" enable $ARGUMENTS
```

## Behavior

The helper script:
1. Finds the schedule by ID in the specified scope
2. Sets `"enabled": true` in the JSON configuration
3. Confirms the schedule was enabled

**Important:** The schedule must already exist in configuration. To add a new schedule, use `/cron:add`.

## Scope Selection

**Project scope (default):**
```bash
/cron:enable morning-standup
```
Searches in `.claude/schedules.json`

**Global scope:**
```bash
/cron:enable morning-standup global
```
Searches in `~/.claude/schedules.json`

## Finding Disabled Schedules

Use `/cron:list` to see all schedules including disabled ones:

```
[GLOBAL] [DISABLED] afternoon-break - 15:00 on Mon, Tue, Wed, Thu, Fri
         ^^^^^^^^^^
         This schedule is currently disabled
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
- Updates `enabled` field to `true`
- Preserves all other schedule configuration
- Returns success/error messages

**Parameters:**
- Operation: `enable`
- Schedule ID: Required
- Scope: `project` (default) or `global`

## Usage Examples

**Enable project schedule:**
```
User: /cron:enable deploy-window
Claude: [OK] Enabled schedule: deploy-window (scope: project)
```

**Enable global schedule:**
```
User: /cron:enable afternoon-break global
Claude: [OK] Enabled schedule: afternoon-break (scope: global)
```

## Tips

- Use `/cron:list` to find disabled schedules
- Enabled schedules start triggering immediately if current time matches
- No need to recreate the schedule - all configuration is preserved
- Pair with `/cron:disable` for temporary on/off control
