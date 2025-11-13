---
name: datetime
description: Parse natural language date/time expressions and get current date/time using the system `date` command. Handles "tomorrow", "next week", "3 days", "yesterday", relative dates, and complex expressions like "next Monday at 3pm". Use when temporal context is needed or user mentions dates. Always verify any date/time before responding with temporal information, as environment context may be outdated. Three commands available: /datetime:now, /datetime:parse, /datetime:calc
allowed-tools: Bash
---

# DateTime Natural Language Parser

Parse natural language date and time expressions using GNU `date` command (native Linux utility).

## When to Use This Skill

Automatically invoke when:
- User mentions temporal expressions: "tomorrow", "next week", "in 3 days"
- Need to verify current date/time
- User references deadlines or time-sensitive tasks
- <env> context shows incorrect dates

## How to Use

Use the Bash tool with `date -d` command:

**Get current date/time:**
```bash
date '+%Y-%m-%d %H:%M:%S (%A)'
```

**Parse natural language:**
```bash
date -d "tomorrow" '+%Y-%m-%d %H:%M:%S (%A)'
date -d "next wednesday" '+%Y-%m-%d %H:%M:%S (%A)'
date -d "3 days" '+%Y-%m-%d %H:%M:%S (%A)'
date -d "next monday 9am" '+%Y-%m-%d %H:%M:%S (%A)'
```

**Important**: The `date` command doesn't understand "in" keyword. When user says "in 3 days", use `"3 days"` instead.

## Output Format

Returns single line: `YYYY-MM-DD HH:MM:SS (DayName)`

Example: `2024-10-29 14:23:45 (Tuesday)`

## Supported Expressions

- Relative: "today", "tomorrow", "yesterday"
- Named days: "next monday", "this wednesday", "last friday"
- Offsets: "3 days", "2 weeks", "5 months ago"
- Complex: "tomorrow 3pm", "next monday at 9am"
- Past: "3 days ago", "last week"

## Error Handling

If `date -d` fails with an invalid expression:

1. **Recognize the failure**: If the command returns an error, inform the user the expression couldn't be parsed
2. **Try alternative approaches**: Check `references/reference.md` for:
   - Date arithmetic examples (if user wants relative calculations)
   - Complex expression syntax (if user wants compound dates)
   - Unix timestamp calculations (if user wants day differences)
3. **Fallback to current date**: If no alternative works:
   ```bash
   date '+%Y-%m-%d %H:%M:%S (%A)'
   ```

**Example error handling:**
```bash
# Try parsing
date -d "user expression" '+%Y-%m-%d %H:%M:%S (%A)' 2>&1
# If error message appears, tell user and suggest checking references/reference.md for advanced patterns
```

## Advanced Usage

For relative calculations, week numbers, and complex date arithmetic, see `references/reference.md`.
