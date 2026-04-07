---
name: cron:add
description: This skill should be used when the user asks to "add a schedule", "create a reminder", "add a cron job", "set up notification", "schedule a standup", or wants to configure scheduled notifications using cron syntax.
version: 2.0.0
user-invocable: true
allowed-tools: [Bash, AskUserQuestion]
argument-hint: "[message] [--cron 'EXPR' | --time HH:MM --days Days] [--command CMD] [--catchup true|false] [global]"
---

# Add Scheduled Notification

Add a new scheduled notification using either crontab(5) syntax (preferred) or the legacy time/days form.

## When to Use

- Create a new recurring reminder
- Set up time-based notifications (hourly, daily, weekly, etc.)
- Schedule standups, breaks, deploy windows, reviews
- Add project-specific or global reminders

## Helper Script

All real work is done by `$CLAUDE_PLUGIN_ROOT/scripts/schedule-add.sh`. Pass arguments through:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/schedule-add.sh" $ARGUMENTS
```

## Argument Forms

### Cron form (preferred)

```
"<message>" --cron "MIN HOUR DOM MONTH DOW" [--catchup true|false] [global]
```

Or with a dynamic command instead of a static message:

```
--command "<shell>" --cron "MIN HOUR DOM MONTH DOW" [--catchup true|false] [global]
```

### Legacy time/days form

```
"<message>" --time HH:MM --days <weekdays|weekends|daily|Mon,Tue,...> [global]
```

## Cron Syntax (5 fields)

| Field | Range | Notes |
|---|---|---|
| Minute | 0-59 | |
| Hour | 0-23 | |
| Day of month | 1-31 | |
| Month | 1-12 | or `jan`-`dec` |
| Day of week | 0-7 | 0 or 7 = Sunday; or `sun`-`sat` |

Operators: `*`, `a-b`, `a,b`, `*/n`, `a-b/n`. If both day-of-month and day-of-week are restricted, the match is **OR** (per crontab(5)).

## message vs command

- **`message`** (positional) — static text, displayed verbatim.
- **`--command`** — shell command run via `bash -c`; stdout becomes the notification text. Use this for dynamic content (date, weather, git status, etc.). If the command exits non-zero, an error notice is shown instead.

Mutually exclusive — pick one.

## catchup

- **`--catchup true`** (default) — anacron-style: if a tick was missed (you weren't prompting), it still fires on the next prompt.
- **`--catchup false`** — strict cron: only fires if the matching tick is in the current wall-clock minute. Missed ticks are lost.

Both modes dedupe per-tick: a single tick fires exactly once.

## Examples

```bash
# Hourly chime with live timestamp
/cron:add --command "date '+Chime: %H:%M %A'" --cron "0 * * * *" global

# Every 15 minutes during work hours, weekdays
/cron:add "Stretch break" --cron "*/15 9-17 * * 1-5" global

# Standup, only fire if currently active (no catchup)
/cron:add "Standup time!" --cron "0 9 * * 1-5" --catchup false global

# Legacy form (still works)
/cron:add "Deploy window" --time 16:00 --days Mon,Wed,Fri

# 1st and 15th of every month at 9:00 (OR with Friday — see crontab(5))
/cron:add "Pay day reminder" --cron "0 9 1,15 * 5" global
```

## Interactive Mode

If `$ARGUMENTS` is empty, use AskUserQuestion to collect:

1. **Text source** — static message or shell command?
2. **Schedule** — cron expression, or HH:MM + days?
3. **Catchup** — fire missed ticks? (default yes)
4. **Scope** — global or project?

Then call the helper script with the collected values.

## Validation

The helper script validates:
- Cron expressions are parsed via `cron-match.py` before saving
- `--time` must be HH:MM 24-hour
- `--catchup` must be `true` or `false`
- Cannot mix `--cron` with `--time`/`--days`
- Cannot provide both a positional message and `--command`

## Scope

| Scope | File | Behavior |
|---|---|---|
| `project` (default) | `.claude/schedules.json` | Merges with global by default; set `mode: "replace"` to override |
| `global` | `~/.claude/schedules.json` | Applies everywhere |

## ID Generation

Auto-slugified from the message (or command, if no message). Override with `--id <name>`.

## Tips

- Cron form is more powerful (sub-daily intervals, ranges, steps)
- Use `--command` with `date`, `git`, `curl`, etc. for live content
- Use `--catchup false` for time-sensitive pings (standup, meeting starts)
- Notifications appear on the next user prompt after the scheduled tick
