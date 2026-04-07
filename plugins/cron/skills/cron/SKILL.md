---
name: cron
description: This skill should be used when the user asks to manage scheduled notifications - "add a cron job", "schedule a reminder", "list schedules", "enable/disable/remove a schedule", "set up a notification", or anything involving the cron plugin. Single unified interactive entry point.
version: 2.1.0
user-invocable: true
allowed-tools: [Bash, AskUserQuestion]
argument-hint: "[add|list|enable|disable|remove] [args...]"
---

# Cron — Scheduled Notifications

You are helping the user manage scheduled notifications via the cron plugin. These are LOCAL schedules: each fires as a `systemMessage` injected into the user's next prompt by a `UserPromptSubmit` hook. Schedules use crontab(5) syntax. There is no daemon — evaluation happens per-prompt with anacron-style catch-up.

## First Step

Your FIRST action must be a single AskUserQuestion tool call (no preamble). Use this EXACT string for the `question` field — do not paraphrase:

"What would you like to do with cron schedules?"

Set `header: "Action"` and offer these options:

- `add` — Create a new schedule
- `list` — Show existing schedules
- `edit` — Modify fields of an existing schedule in place
- `enable` — Enable a disabled schedule
- `disable` — Disable a schedule (without deleting it)
- `remove` — Delete a schedule permanently
- `help` — Show subcommand grammar and cron syntax reference

After the user picks, follow the matching workflow below.

## Helper Commands

All real work is done by thin wrappers that live in the plugin's `bin/` directory. Claude Code puts that directory on `PATH` automatically, so you invoke them as bare commands — **no path construction, no `$CLAUDE_PLUGIN_ROOT`**. (`$CLAUDE_PLUGIN_ROOT` is not substituted inside SKILL.md files; see [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354).)

- `cron-add ...` — add a schedule
- `cron-list [global|project|all]` — list schedules
- `cron-edit <id> [global|project] [flags...]` — edit fields in place
- `cron-modify enable|disable|remove <id> [global|project]` — enable/disable/remove
- `cron-match "<expr>" <now-epoch>` — validate a cron expression (parse-only check when `now-epoch` is `0`)

You do NOT manipulate `~/.claude/schedules.json` or `.claude/schedules.json` directly. Use the commands.

## Schedule Schema (reference)

Each schedule entry has these fields:

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Auto-slugified from message/command if not provided |
| `enabled` | yes | Boolean |
| `cron` | one of | crontab(5) 5-field expression |
| `time` + `days` | one of | Legacy form: `HH:MM` + `["Mon","Tue",...]` or `["*"]` |
| `message` | one of | Static notification text |
| `command` | one of | Shell command run via `bash -c`, stdout becomes the text |
| `catchup` | optional | Boolean, default `true` |

## Cron Syntax (5 fields)

```
MIN  HOUR  DOM  MONTH  DOW
0-59 0-23  1-31 1-12   0-7  (0 or 7 = Sunday; sun-sat or jan-dec also work)
```

Operators: `*`, `a-b`, `a,b`, `*/n`, `a-b/n`.

**OR rule** (per crontab(5)): if both day-of-month and day-of-week are restricted (neither is `*`), the match is **OR**, not AND. Example: `0 9 1,15 * 5` fires on the 1st, the 15th, **and** every Friday at 9:00. Mention this if the user writes a cron expression that triggers the rule unintentionally.

### Common cron examples

| Expression | Meaning |
|---|---|
| `0 * * * *` | Every hour, on the hour |
| `*/15 * * * *` | Every 15 minutes |
| `0 9 * * 1-5` | 9:00 every weekday |
| `30 14 * * *` | 14:30 every day |
| `0 9 1 * *` | 9:00 on the 1st of every month |
| `0 0 * * 0` | Midnight every Sunday |

## Workflow: ADD

Gather inputs via a sequence of AskUserQuestion calls. Skip steps the user has already answered in their initial message.

1. **Schedule form** — `header: "Schedule form"`, question: "How would you like to specify the schedule?"
   - `cron` — crontab(5) expression (recommended)
   - `simple` — HH:MM time + days

2. **If cron**: ask for the cron expression as a free-text answer. Validate it before proceeding by running:
   ```bash
   cron-match "<expr>" 0 >/dev/null && echo OK || echo INVALID
   ```
   If invalid, show the error and re-ask. If the expression triggers the OR rule (both DOM and DOW restricted), flag it explicitly: "Heads-up: this fires on DAY-OF-MONTH X **or** DAY-OF-WEEK Y, not both — that's standard cron behavior. OK?"

3. **If simple**: two AUQs.
   - Time: free-text `HH:MM` (24-hour). Validate `^([01][0-9]|2[0-3]):[0-5][0-9]$`.
   - Days: options `weekdays`, `weekends`, `daily`, `custom`. If `custom`, ask for a comma-separated list of `Mon,Tue,Wed,Thu,Fri,Sat,Sun`.

4. **Text source** — `header: "Notification text"`, question: "Should the notification show static text or run a shell command?"
   - `message` — static text
   - `command` — shell command, stdout becomes the text (good for `date`, `git`, etc.)

5. **Text content** — Free-text answer. For `command`, remind the user it runs with their shell privileges and suggest wrapping in single quotes.

6. **Catchup** — `header: "Catchup mode"`, question: "If a tick is missed (no prompt during the matching minute), should it still fire on the next prompt?"
   - `yes` — anacron-style catch-up (default, recommended for reminders)
   - `no` — strict cron, only fires if the matching tick is in the current wall-clock minute

7. **Scope** — `header: "Scope"`, question: "Where should this schedule be saved?"
   - `global` — `~/.claude/schedules.json`, applies everywhere
   - `project` — `.claude/schedules.json` in the current directory

8. **Review and confirm** — Show the resolved arguments back to the user as a single AUQ with options `confirm` / `edit` / `cancel`. If `edit`, ask which step to redo.

9. **Create it** — Call the helper script with the assembled arguments:
   ```bash
   cron-add \
     [<message> | --command "<cmd>"] \
     [--cron "<expr>" | --time HH:MM --days <days>] \
     --catchup <true|false> \
     [global]
   ```
   Show the script's output. If it fails, explain the error.

## Workflow: LIST

Run the list script and present results. Ask scope if not obvious from context:

```bash
cron-list all
```

(or `global` / `project` if the user specified). The script's output is already formatted; pass it through as a code block.

## Workflow: EDIT

1. **List first** — Run `cron-list all` so the user can see what exists.
2. **Pick a schedule** — AUQ with each schedule id as an option (with the message/command in `description`), plus `cancel`.
3. **Show current state** — Display the picked entry's full JSON so the user can see all fields.
4. **Pick fields to change** — AUQ `header: "Field"`, question: "Which field do you want to change?". Options: `cron`, `time + days`, `message`, `command`, `catchup`, `done`. Allow multi-select if the user wants to change several at once; otherwise loop one-at-a-time until they pick `done`.
5. **For each field**, gather the new value via free-text or AUQ as appropriate (validate the same way as `add`).
6. **Confirm** — Show the resolved diff (old → new) and ask `apply` / `cancel`.
7. **Execute**:
   ```bash
   cron-edit <id> <global|project> \
     [--cron "EXPR" | --time HH:MM --days DAYS] \
     [--message "TEXT" | --command "CMD"] \
     [--catchup true|false]
   ```
   Only the flags the user actually changed should be passed. The script leaves untouched fields alone, and clears mutually-exclusive ones (e.g. `--cron` clears `time`/`days`, `--message` clears `command`).

## Workflow: HELP

Print a static reference. Do not call any helper script. Output the subcommand grammar (from the section below), the cron syntax table, and one or two examples per subcommand. Keep it under 60 lines.

## Workflow: ENABLE / DISABLE / REMOVE

1. **List first** — Always run `cron-list all` so the user can see what exists.
2. **Pick a schedule** — Use AskUserQuestion with each schedule id as an option, plus `cancel`. Include the schedule's message/command in the option `description` so the user can identify it.
3. **Determine scope** — From the list output, you know whether the picked id is global or project. If ambiguous (same id in both), ask.
4. **For `remove`**: confirm destructively first. AUQ with `header: "Confirm delete"`, options `delete` / `cancel`.
5. **Execute**:
   ```bash
   cron-modify <enable|disable|remove> <id> <global|project>
   ```
   Show the result.

## Subcommand Grammar (skip the AUQs)

The user can pass arguments to skip prompts. The first positional argument is the subcommand. **If the first argument matches a subcommand below, jump straight into that workflow** and only AUQ for what is missing.

```
/cron                                       → fully interactive
/cron add [<message>] [--cron EXPR | --time HH:MM --days DAYS]
         [--command CMD] [--catchup true|false] [--id ID] [global]
/cron list [global|project|all]
/cron edit <id> [global|project]
         [--cron EXPR | --time HH:MM --days DAYS]
         [--message TEXT | --command CMD]
         [--catchup true|false]
/cron enable  <id> [global|project]
/cron disable <id> [global|project]
/cron remove  <id> [global|project]
/cron help
```

### Subcommand → helper-script mapping

| Subcommand | Helper script invocation |
|---|---|
| `add ARGS...` | `cron-add ARGS...` |
| `list [SCOPE]` | `cron-list ${SCOPE:-all}` |
| `edit ID [SCOPE] FLAGS...` | `cron-edit ID ${SCOPE:-project} FLAGS...` |
| `help` | (no helper script — print static reference inline) |
| `enable ID [SCOPE]` | `cron-modify enable ID ${SCOPE:-project}` |
| `disable ID [SCOPE]` | `cron-modify disable ID ${SCOPE:-project}` |
| `remove ID [SCOPE]` | `cron-modify remove ID ${SCOPE:-project}` |

### Examples

```bash
/cron list global
/cron add "Standup" --cron "0 9 * * 1-5" global
/cron add --command "date '+%H:%M %A'" --cron "0 * * * *" global
/cron disable hourly-chime global
/cron remove deploy-window
```

### Argument detection

If the first positional looks like an `--option` or a quoted message but no subcommand is present, **assume `add`** for backwards compatibility (e.g. `/cron "Standup" --time 09:00 --days weekdays` is treated as `/cron add "Standup" --time 09:00 --days weekdays`).

If the user provides only `/cron` with no arguments, run the fully interactive flow starting with the action AUQ.

## Important Notes

- These are LOCAL schedules — they fire only when the user submits a prompt to Claude Code. The plugin does not run a daemon. Make sure the user understands this if they expect background firing.
- Notifications appear in the next user prompt's context as a `systemMessage`.
- The hook only evaluates schedules on `UserPromptSubmit`. If the user is away from the keyboard for a tick, anacron-style catch-up will still fire it on their next prompt (only the most recent tick, not every missed one).
- Always show the full final command before running it, so the user can spot mistakes.
- After any modification, optionally run `cron-list` again to confirm the new state — but only if the user wants to verify.
- If the user asks to "delete" a schedule, treat it as `remove`.
- If the user asks to "pause" or "stop" a schedule without deleting, treat it as `disable`.
