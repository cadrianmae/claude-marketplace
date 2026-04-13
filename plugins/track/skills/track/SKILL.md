---
name: track
description: This skill should be used when the user asks to "initialize tracking", "enable/disable tracking", "toggle auto-tracking", "configure tracking verbosity", "export bibliography", "export methodology", "generate BibTeX", "create citation timeline", or anything involving the track plugin for reference and prompt tracking. Single unified interactive entry point.
version: 2.7.0
user-invocable: true
allowed-tools: Bash, Read, Write, AskUserQuestion
argument-hint: "[init|config|auto|export|help] [args...]"
---

# Track — Reference and Prompt Tracking

The track plugin records research sources and prompts to `claude_usage/` during a Claude Code session via two hooks: `capture-sources.sh` (PostToolUse, fires on Read/Grep/WebFetch/WebSearch) and `capture-prompt.sh` (Stop, fires after each assistant response). Sources are written in compact ASCII format with zero LLM cost; prompts are classified MAJOR/MINOR by a Claude Haiku call for verbosity filtering. Exports produce bibliographies, methodology sections, BibTeX, citations, or timelines from the tracked data.

This skill is the single interactive entry point for initializing, configuring, toggling, and exporting tracking data. Hooks run independently of this skill — toggling them on/off only changes a flag in `.claude/.ref-config`.

## First Step

When invoked with no arguments, the FIRST action must be a single AskUserQuestion tool call (no preamble). Use this EXACT string for the `question` field:

"What would you like to do with track?"

Set `header: "Action"` and offer these options:

- `init` — Initialize tracking files and enable hooks
- `config` — View or update verbosity and export settings
- `auto` — Toggle hook-based tracking on/off
- `export` — Export tracked data (bibliography / methodology / bibtex / citations / timeline)
- `help` — Show subcommand grammar and usage examples

If the user's message already includes a subcommand (e.g. `/track export bibliography`), skip the AUQ and jump straight into the matching workflow below. See "Subcommand Grammar" for the full argument form.

## Helper Commands

All real work is done by thin wrappers in the plugin's `bin/` directory. Claude Code puts that directory on `PATH` automatically, so invoke them as bare commands — **no path construction, no `$CLAUDE_PLUGIN_ROOT`**. (`$CLAUDE_PLUGIN_ROOT` is not substituted inside SKILL.md files; see [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354).)

- `track-init` — initialize tracking files and configuration
- `track-config [KEY=VALUE ...]` — view or update verbosity/export settings
- `track-auto [on|off]` — toggle hook-based tracking
- `track-export <format> [output]` — export tracked data

Do NOT edit `claude_usage/prompts.md`, `claude_usage/sources.md`, or `.claude/.ref-config` directly from this skill. Use the commands.

## Configuration Reference

The `.claude/.ref-config` file holds four values read by both the skill and the hooks:

| Key | Values | Default | Purpose |
|---|---|---|---|
| `TRACKING_ENABLED` | `true` / `false` | `true` | Master switch for hooks |
| `PROMPTS_VERBOSITY` | `all` / `major` / `minimal` / `off` | `major` | What gets written to `prompts.md` |
| `SOURCES_VERBOSITY` | `all` / `off` | `all` | What gets written to `sources.md` |
| `EXPORT_PATH` | path string | `exports/` | Default output directory for `track-export` |

## Workflow: INIT

1. Run `track-init` with no arguments.
2. Show the script's output verbatim in a code block.
3. On success, tell the user: tracking files are created at `claude_usage/`, the config file is at `.claude/.ref-config`, and hooks will fire automatically on the next tool call or assistant response.

Init is parameterless — no AUQ sequence needed. If `claude_usage/` already exists, the script handles that idempotently; pass the output through unchanged.

## Workflow: CONFIG

Two modes:

- **No args** → call `track-config` with no arguments. The script itself uses AskUserQuestion internally for interactive flow. Pass its output through.
- **With `KEY=VALUE` pairs** → call `track-config KEY=VALUE [KEY=VALUE ...]` directly and show the result.

Supported keys: `prompts=all|major|minimal|off`, `sources=all|off`, `export_path=<path>`.

Prerequisite: `.claude/.ref-config` must exist. If missing, advise running `track init` first.

## Workflow: AUTO

1. If the user supplied `on` or `off` as an argument, call `track-auto on` or `track-auto off` directly.
2. Otherwise, AUQ: `header: "Auto-tracking"`, question: "Enable or disable hook-based tracking?", options: `on`, `off`, `cancel`.
3. Show the script's output.

Auto only flips `TRACKING_ENABLED` in the config file. It does not delete tracked data.

## Workflow: EXPORT

1. **Format** — If not provided, AUQ: `header: "Export format"`, question: "Which export format?". Options: `bibliography`, `methodology`, `bibtex`, `citations`, `timeline`, `cancel`.
2. **Output path** — If not provided, prompt as free-text. Mention the default from `EXPORT_PATH` in `.claude/.ref-config` as a hint (e.g. "Leave blank for the default: `exports/bibliography.md`"). If the user supplies a bare filename without a directory, the script resolves it against `EXPORT_PATH`.
3. **Run** — Call `track-export <format> [output]` and show the result in a code block.

Prerequisite: `claude_usage/sources.md` and/or `claude_usage/prompts.md` must exist. If absent, advise running `track init` first.

**Format notes:**

- `bibliography` — Markdown numbered bibliography from sources.
- `methodology` — Markdown sections from prompts, organized by MAJOR classification.
- `bibtex` — BibTeX entries suitable for `\cite{}`.
- `citations` — Numbered inline citations.
- `timeline` — Chronological activity log combining sources and prompts.

## Workflow: HELP

Print a static reference. Do NOT call any helper script. Output the following verbatim (under 60 lines total):

1. The subcommand grammar block from "Subcommand Grammar" below.
2. The configuration reference table from "Configuration Reference" above.
3. The examples block from "Subcommand Grammar → Examples" below.

## Subcommand Grammar (skip the AUQs)

The first positional argument is the subcommand. **If the first argument matches a subcommand below, jump straight into that workflow** and only AUQ for what is missing.

```
/track                              → fully interactive (action AUQ first)
/track init
/track config [KEY=VALUE ...]
/track auto [on|off]
/track export <format> [output]
/track help
```

### Subcommand → helper-command mapping

| Subcommand | Helper invocation |
|---|---|
| `init` | `track-init` |
| `config [ARGS]` | `track-config [ARGS]` |
| `auto [on\|off]` | `track-auto [on\|off]` |
| `export FORMAT [OUTPUT]` | `track-export FORMAT [OUTPUT]` |
| `help` | (no helper — print static reference inline) |

### Examples

```
/track init
/track config prompts=all
/track config prompts=major sources=off export_path=paper/refs/
/track auto off
/track auto on
/track export bibliography
/track export bibtex refs.bib
/track export methodology paper/methodology.md
```

### Argument detection

If no subcommand is present and no arguments are supplied, run the fully interactive flow starting with the action AUQ.

If a known config key (`prompts=`, `sources=`, `export_path=`) is the first positional, assume `config`. If a known export format (`bibliography`, `methodology`, `bibtex`, `citations`, `timeline`) is the first positional, assume `export`. Otherwise ask.

## Important Notes

- Hooks fire based on `TRACKING_ENABLED` in `.claude/.ref-config`. Toggle via `/track auto`, not by editing the file directly.
- The Stop hook is debounced (5s) to prevent runaway haiku processes; outputs appear on the next conversation turn, not immediately.
- All file operations are CWD-relative. Invoke `/track` from the project root where `claude_usage/` should live.
- If `/track:init`, `/track:config`, etc. (colon syntax) are invoked by muscle memory, treat as the space-separated form. The old colon-separated commands no longer exist as separate skills.
- If the user asks to "migrate from v1.x" or "migrate tracking", point at `plugins/track/MIGRATION.md` — the `migrate` skill no longer exists. Current versions auto-migrate legacy files during `track-init`.
- Always show the final command before running it, so the user can spot mistakes.
- After any modification, optionally show the resulting config via `track-config` with no args — but only if the user wants to verify.
- If the user asks to "stop tracking" or "pause tracking", treat as `auto off`. If they ask to "turn tracking back on" or "resume tracking", treat as `auto on`.
- If the user asks to "delete tracking" or "remove tracking data", do NOT auto-execute. This skill does not delete data. Tell the user to remove `claude_usage/` manually if that is their intent.
