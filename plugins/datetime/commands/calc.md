---
description: Calculate date/time differences (Claude should use date command directly)
allowed-tools: Bash
disable-model-invocation: true
---

# calc - Calculate date/time differences

Calculate the difference between two dates or times using natural language expressions.

## For Claude Code

**If you are Claude**: DO NOT invoke this slash command. Use unix timestamp arithmetic via Bash tool:

```bash
date1=$(date -d "first date" +%s)
date2=$(date -d "second date" +%s)
diff=$((date2 - date1))
echo "Difference: $diff seconds"
```

See the Implementation section below for the full calculation pattern.

## For Users

### Usage

```bash
/datetime:calc
```

The command will interactively ask for two date/time expressions, then calculate the difference.

## What it does

1. **Asks for first date/time**: Accepts natural language expression (e.g., "tomorrow", "2024-12-01", "next Monday")
2. **Asks for second date/time**: Accepts natural language expression
3. **Calculates difference**: Shows the time between the two dates in multiple units
4. **Human-readable output**: Displays results as days, hours, minutes, and seconds

The calculation uses unix timestamps internally for accuracy across timezones and DST boundaries.

## Implementation

**Convert dates to unix timestamps:**
```bash
date1_ts=$(date -d "first expression" +%s)
date2_ts=$(date -d "second expression" +%s)
```

**Calculate difference:**
```bash
diff_seconds=$((date2_ts - date1_ts))
diff_days=$((diff_seconds / 86400))
diff_hours=$(((diff_seconds % 86400) / 3600))
diff_minutes=$(((diff_seconds % 3600) / 60))
diff_secs=$((diff_seconds % 60))
```

**Display result:**
```bash
echo "Difference: ${diff_days}d ${diff_hours}h ${diff_minutes}m ${diff_secs}s"
echo "Total: ${diff_seconds} seconds"
```

## Examples

```bash
# Days until deadline
/datetime:calc
→ First date/time: today
→ Second date/time: 2024-12-15
→ Difference: 32d 0h 0m 0s (32 days)
→ Total: 2764800 seconds

# Time since event
/datetime:calc
→ First date/time: 2024-11-01
→ Second date/time: today
→ Difference: 12d 0h 0m 0s (12 days)
→ Total: 1036800 seconds

# Hours between meetings
/datetime:calc
→ First date/time: today 14:00
→ Second date/time: tomorrow 10:30
→ Difference: 0d 20h 30m 0s
→ Total: 73800 seconds

# Working days remaining
/datetime:calc
→ First date/time: today
→ Second date/time: next Friday
→ Difference: 2d 0h 0m 0s (2 days)
→ Total: 172800 seconds
```

## Common calculations

**Academic deadlines:**
- "today" to "2024-12-20" - Days until assignment due
- "today" to "next Friday 23:59" - Time to weekly submission

**Project milestones:**
- "2024-11-13" to "2024-12-01" - Sprint duration
- "last Monday" to "today" - Week progress

**Event planning:**
- "today" to "25 Dec" - Days until event
- "9:00" to "17:00" - Meeting duration (same day)

**Time tracking:**
- "yesterday" to "today" - Daily intervals
- "1 week ago" to "today" - Weekly reviews

## When to use

- Calculate days remaining until assignment deadlines
- Track time elapsed on projects or sprints
- Plan event schedules and milestones
- Verify working time between meetings
- Calculate age or duration of events
- Estimate remaining time for deliverables
- Academic semester/week planning

## Related commands

- `/datetime:now` - Get current date/time
- `/datetime:parse` - Parse natural language date expressions
