---
description: Parse natural language date/time expressions (Claude should use date command directly)
argument-hint: <expression> [format]
allowed-tools: Bash
disable-model-invocation: true
---

## Current System Time (Auto-Captured)

**Current Time**: !`date '+%Y-%m-%d %H:%M:%S %Z'`
**Week Number**: !`date '+%V'`
**Timezone**: !`date '+%Z (UTC%:z)'`

## Quick Example

```bash
/datetime:parse "next Friday"
# 2026-02-06 00:00:00 (Friday)
```

# parse - Parse natural language date/time expressions

Parse natural language date and time expressions into standardized format.

## For Claude Code

**If you are Claude**: DO NOT invoke this slash command. Use the `date` command directly via Bash tool:

```bash
date -d "expression" '+%Y-%m-%d %H:%M:%S (%A)'
```

See the Implementation section below for the exact command pattern.

## For Users

### Usage

```bash
/datetime:parse <expression>
/datetime:parse <expression> [format]
```

## What it does

1. **Standard format**: Parses natural language and returns standardized date/time
   - Format: `YYYY-MM-DD HH:MM:SS (DayName)`
   - Example: `/datetime:parse "tomorrow"` → `2025-11-14 00:00:00 (Friday)`

2. **Custom format**: Parse and return in custom format
   - Uses `date` command format strings
   - Example: `/datetime:parse "next Monday" "%Y-%m-%d"` → `2025-11-17`

## Implementation

**Standard format:**
```bash
date -d "<expression>" '+%Y-%m-%d %H:%M:%S (%A)'
```

**Custom format:**
```bash
date -d "<expression>" '+[format-string]'
```

**Important: "in" prefix handling**
- User says: "in 3 days"
- Command needs: `date -d "3 days"`
- Strip "in" prefix before passing to `date -d`

## Natural language expressions

**Relative dates:**
- `tomorrow`, `yesterday`
- `3 days`, `2 weeks`, `1 month`, `6 months`
- `next Monday`, `last Friday`
- `next week`, `last month`

**Specific dates:**
- `Nov 13`, `November 13`, `13 Nov 2025`
- `2025-11-13`, `13/11/2025`

**Combined expressions:**
- `tomorrow at 3pm` → `2025-11-14 15:00:00 (Friday)`
- `next Monday at 14:30` → `2025-11-17 14:30:00 (Monday)`
- `3 days at noon` → `2025-11-16 12:00:00 (Sunday)`

**Week navigation:**
- `monday`, `tuesday` (next occurrence)
- `next monday`, `last tuesday`

## Examples

```bash
# Tomorrow
/datetime:parse "tomorrow"
→ 2025-11-14 00:00:00 (Friday)

# Relative days (strip "in" if present)
/datetime:parse "3 days"
→ 2025-11-16 00:00:00 (Sunday)

# Next week day
/datetime:parse "next Monday"
→ 2025-11-17 00:00:00 (Monday)

# With time
/datetime:parse "tomorrow at 3pm"
→ 2025-11-14 15:00:00 (Friday)

# Specific date
/datetime:parse "Nov 15"
→ 2025-11-15 00:00:00 (Saturday)

# Custom format - date only
/datetime:parse "next week" "%Y-%m-%d"
→ 2025-11-20

# Unix timestamp for calculations
/datetime:parse "3 days" "+%s"
→ 1731715200
```

## Error handling

If the expression is invalid, `date` will return an error:
```bash
date -d "invalid expression"
→ date: invalid date 'invalid expression'
```

Common mistakes:
- `in 3 days` → Remove "in", use `3 days`
- `3d` → Use full words: `3 days`
- `next week monday` → Use `next monday` or `monday next week`

## When to use

- ANY time user mentions dates, times, or temporal concepts
- Converting user's natural language into concrete dates
- Calculating deadlines from relative expressions
- Validating date inputs before processing
- Don't guess dates - always verify with this command

## Related commands

- `/datetime:now` - Get current date and time
- `/datetime:calc` - Calculate date differences
