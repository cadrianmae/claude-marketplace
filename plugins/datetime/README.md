# datetime Plugin

Natural language date/time parsing and calculations using native GNU date command.

## Overview

Parse natural language date/time expressions, get current date/time, and calculate date differences with zero external dependencies.

**Key features:**
- Natural language parsing ("tomorrow", "next week", "3 days")
- Current date/time retrieval with custom formatting
- Date arithmetic and difference calculations
- Auto-invoked skill for proactive temporal awareness
- Zero dependencies (native `date` command)

## Commands

- `/datetime:now` - Get current date/time
- `/datetime:parse` - Parse natural language date expressions
- `/datetime:calc` - Calculate date differences

## Quick Start

```bash
# Get current date/time
/datetime:now
→ 2024-11-13 16:45:30 (Wednesday)

# Parse natural language
/datetime:parse "tomorrow at 3pm"
→ 2024-11-14 15:00:00 (Thursday)

# Calculate date difference
/datetime:calc
→ (Interactive: asks for two dates, shows difference)
```

## Installation

```bash
# From within Claude Code
/mcp install datetime@cadrianmae-claude-marketplace
```

## Features

### Supported Date Expressions

**Relative dates:**
- `today`, `tomorrow`, `yesterday`
- `3 days`, `2 weeks`, `5 months`
- `3 days ago`, `last week`

**Named days:**
- `next monday`, `this wednesday`, `last friday`
- `next monday at 9am`

**Specific dates:**
- `Nov 13`, `November 13, 2024`
- `2024-11-13`

**Complex expressions:**
- `tomorrow 3pm`, `next monday at 9am`
- `in 2 weeks` (note: date command needs "2 weeks", not "in 2 weeks")

### Auto-Invoked Skill

The datetime skill automatically activates when:
- User mentions temporal expressions
- Need to verify current date/time
- User references deadlines or time-sensitive tasks
- Environment context shows incorrect dates

Claude will proactively use the native `date` command to verify temporal information.

## Usage Examples

### /datetime:now

```bash
# Standard format
/datetime:now
→ 2024-11-13 16:45:30 (Wednesday)

# Custom format
/datetime:now "%Y-%m-%d"
→ 2024-11-13

# Week number
/datetime:now "%V"
→ 45

# Unix timestamp
/datetime:now "+%s"
→ 1699896330
```

### /datetime:parse

```bash
# Relative dates
/datetime:parse "tomorrow"
→ 2024-11-14 00:00:00 (Thursday)

# Named days with time
/datetime:parse "next monday at 9am"
→ 2024-11-18 09:00:00 (Monday)

# Offsets
/datetime:parse "3 days"
→ 2024-11-16 16:45:30 (Saturday)

# Past dates
/datetime:parse "last friday"
→ 2024-11-08 00:00:00 (Friday)
```

### /datetime:calc

```bash
# Calculate days until deadline
/datetime:calc
→ First date: today
→ Second date: Dec 15
→ Difference: 32 days, 0 hours, 0 minutes (2,764,800 seconds)

# Time since event
/datetime:calc
→ First date: Oct 1
→ Second date: today
→ Difference: 43 days, 0 hours, 0 minutes (3,715,200 seconds)
```

## Technical Details

### Implementation

Uses native GNU `date` command available on all Linux/Unix systems:

```bash
# Current time
date '+%Y-%m-%d %H:%M:%S (%A)'

# Parse expression
date -d "tomorrow" '+%Y-%m-%d %H:%M:%S (%A)'

# Unix timestamp for calculations
date -d "expression" +%s
```

### Output Format

Standard format: `YYYY-MM-DD HH:MM:SS (DayName)`

Example: `2024-11-13 16:45:30 (Wednesday)`

## Troubleshooting

### "in" Prefix Issue

**Problem:** User says "in 3 days" but `date` command fails

**Solution:** Remove "in" prefix - use `date -d "3 days"` instead of `date -d "in 3 days"`

### Invalid Date Expression

If `date -d` fails:
1. Try alternative phrasing ("next week" instead of "in one week")
2. Use specific date format ("Nov 13" or "2024-11-13")
3. Check the skill's references for advanced syntax

### Week Number Confusion

For academic week mapping, use:
```bash
# Get current calendar week
/datetime:now "%V"

# Then map to academic week in project's week-mapping.sh
```

## Platform Compatibility

- **Linux**: ✓ Full support (GNU date)
- **macOS**: ✓ Full support (BSD date with similar syntax)
- **Windows**: ⚠️ Requires WSL or Git Bash

## Files Created

The skill operates without creating any files - it directly uses the system `date` command.

## Author

Created by cadrianmae for academic and productivity use.

## License

MIT License - see LICENSE file for details.

## Related Resources

- Skill reference: `skills/datetime/references/reference.md`
- GNU date documentation: `man date`
- Format strings: `man date` (search for FORMAT)
