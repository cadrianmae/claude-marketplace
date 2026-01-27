---
description: Get current date and time (Claude should use date command directly)
argument-hint: [format]
allowed-tools: Bash
disable-model-invocation: true
---

## Current System Time (Auto-Captured)

**Current Time**: !`date '+%Y-%m-%d %H:%M:%S %Z'`
**Day of Week**: !`date '+%A'`
**Week Number**: !`date '+%V'`
**Timezone**: !`date '+%Z (UTC%:z)'`

## Quick Example

```bash
/datetime:now
# 2026-01-27 14:30:15 (Monday)
```

# now - Get current date and time

Get the current date and time in a standardized format.

## For Claude Code

**If you are Claude**: DO NOT invoke this slash command. Use the `date` command directly via Bash tool:

```bash
date '+%Y-%m-%d %H:%M:%S (%A)'
```

See the Implementation section below for the exact command pattern.

## For Users

### Usage

```bash
/datetime:now
/datetime:now [format]
```

## What it does

1. **No arguments**: Returns current date/time in standard format
   - Format: `YYYY-MM-DD HH:MM:SS (DayName)`
   - Example: `2024-11-13 16:45:30 (Wednesday)`

2. **With format argument**: Returns current date/time in custom format
   - Uses `date` command format strings
   - Example: `/datetime:now "%B %d, %Y"` → `November 13, 2024`

## Implementation

**Standard format:**
```bash
date '+%Y-%m-%d %H:%M:%S (%A)'
```

**Custom format:**
```bash
date '+[format-string]'
```

## Common format strings

- `%Y-%m-%d` - Date only (2024-11-13)
- `%H:%M:%S` - Time only (16:45:30)
- `%A` - Full day name (Wednesday)
- `%B %d, %Y` - Formatted date (November 13, 2024)
- `%V` - Week number (45)
- `+%s` - Unix timestamp (1699896330)

## Examples

```bash
# Standard output
/datetime:now
→ 2024-11-13 16:45:30 (Wednesday)

# Custom format - date only
/datetime:now "%Y-%m-%d"
→ 2024-11-13

# Week number
/datetime:now "%V"
→ 45

# Unix timestamp
/datetime:now "+%s"
→ 1699896330
```

## When to use

- Verify current date/time before making temporal decisions
- Get current week number for academic week mapping
- Generate timestamps for logging or calculations
- When <env> context date may be outdated

## Related commands

- `/datetime:parse` - Parse natural language date expressions
- `/datetime:calc` - Calculate date differences
