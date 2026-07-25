# Context Plugin — Handover File Management Design Spec

**Date:** 2026-07-24
**Plugin:** `plugins/context`
**Issue:** #31 (context plugin: manage handover files — TTL + persistent temp location)
**Status:** Design approved; ready for implementation plan.

## Problem

The `context` plugin passes session handoffs as `ctx-{direction}-{subject}.md` files.
The directory is hardcoded to `/tmp/claude-ctx/` in every command/skill markdown
file, and all the filename/direction logic lives in prose instructions. Two problems:

1. **Not persistent.** `/tmp` is tmpfs on most systems and is wiped on reboot.
   Handovers are lost between sessions across a reboot — this has already cost a
   fully-prepared handoff on a multi-day project.
2. **No pruning story.** Handover files accumulate across sessions with no way to
   see or clean them up.

Additionally, filename construction and direction mapping currently live in
markdown, which is fragile and untestable.

## Goals

- **Persistent default location** for handovers (survives reboot).
- **TTL-based pruning** so old handovers do not accumulate forever.
- Move handover **naming, direction mapping, dir resolution, filtering, and
  pruning into one tested script** (`context-manage`), so the slash commands are
  thin.
- `/context:send` and `/context:receive` keep the same user-facing interface.

Non-goal: changing the handoff file naming scheme (`ctx-{direction}-{subject}.md`)
or the slash-command arguments users type.

## Decisions

- **Directory name: `claude-context`.**
- **Handover dir** default: `${XDG_STATE_HOME:-$HOME/.local/state}/claude-context`
  (persistent). Overridable by config `dir=`. Fallback `/tmp/claude-context`
  (+ `[WARN]` to stderr) if the target cannot be created/written.
- **Config file: `~/.claude/.context-config`** (plugin convention, cf.
  `~/.claude/.audio-feedback-config`). KV format. Keys: `dir` (override handover
  dir), `ttl_days` (override retention; default **90**), `max_bytes` (inline-cat
  size cap for `receive`; default **28000**).
- **TTL: on, 90-day default.** `/context:send` auto-prunes on each invocation.
- **Legacy `/tmp/claude-ctx` files**: left untouched (unreferenced). No migration.
- **Structure: `scripts/lib.sh` + `bin/context-manage`** (matches audio-feedback /
  tts). Shared resolution + all handover logic in `lib.sh`; `bin/context-manage`
  is a thin CLI wrapper resolving the plugin root via `readlink -f "$0"`.
- **`send` writes the file from stdin** (body piped in); **`receive` outputs the
  matching handover's content** to stdout (cats it), so it lands directly in the
  command output — no separate read step. The source filename is printed to stderr
  as an `[INFO]` line for provenance (keeps stdout pure content).
- **Subject is required on `send`** (the slash command has Claude infer one when
  the user omits it); **optional on `receive`** (newest matching handover for that
  direction if omitted).

## Direction mapping

`send <target>` = who the handoff is TO; `receive <source>` = who it is FROM.

| Command | Filename |
|---------|----------|
| `send child <subj>` | `ctx-parent-to-child-<subj>.md` |
| `send parent <subj>` | `ctx-child-to-parent-<subj>.md` |
| `send sibling <subj>` | `ctx-sibling-to-sibling-<subj>.md` |
| `receive parent <subj>` | reads `ctx-parent-to-child-<subj>.md` |
| `receive child <subj>` | reads `ctx-child-to-parent-<subj>.md` |
| `receive sibling <subj>` | reads `ctx-sibling-to-sibling-<subj>.md` |

Flow: `parent: send child X` -> `child: receive parent X` -> `child: send parent X`
-> `parent: receive child X`.

## Architecture / components

### `plugins/context/scripts/lib.sh` (shared library, sourced)
No side effects at source time. Functions:
- `ctx_config_file` -> prints `~/.claude/.context-config`.
- `ctx_ttl_days` -> effective TTL (config `ttl_days`, else 90; malformed -> 90 + `[WARN]`).
- `ctx_dir` -> resolve + ensure the handover dir: config `dir` else XDG state
  default; `mkdir -p`; if unwritable use `/tmp/claude-context` (+ `[WARN]`); create
  a `README.md` on first use; print the resolved path.
- `ctx_filename <mode> <role> <subject>` -> `ctx-{direction}-{subject}.md`
  basename. `mode` is `send` or `receive`; `role` is parent|child|sibling (validated).
  Mapping: `send <role>` -> `{opposite(role)}-to-{role}`; `receive <role>` ->
  `{role}-to-{opposite(role)}`; where opposite is child<->parent and
  sibling<->sibling. (So `send child` and `receive child` resolve to different
  files — this is why mode is required.) Slugifies subject; send/receive slugify
  identically so a subject round-trips.
- `ctx_send <target> <subject>` -> ensure dir, prune, compute path, write stdin to
  it, print the path.
- `ctx_receive <source> <subject>` -> resolve dir, find the matching file (exact
  subject; if omitted, newest match for that direction), print an `[INFO]` line
  naming the file to stderr, then cat its content to stdout; error to stderr +
  exit 1 if none. **Size guard:** if the file exceeds a threshold (default
  ~28000 bytes, configurable `max_bytes` in config), skip cat-ing and instead
  print the path with a `[WARN]` that it is too large to inline (avoids Bash
  tool-output truncation, which is ~30000 chars) — Claude reads it directly then.
- `ctx_list` -> for each `ctx-*.md`: age (days from mtime), direction, subject.
- `ctx_prune` -> delete `ctx-*.md` older than `ttl_days`; report removed. Never
  touches non-`ctx-*.md` files.
- `ctx_clean` -> delete all `ctx-*.md` (keep README); report count.

Config parsing mirrors audio-feedback's `lib.sh`: `key=value` lines, ignore
blanks/`#`, whitelist known keys.

### `plugins/context/bin/context-manage` (CLI wrapper)
```
context-manage send <target> <subject>     # stdin -> handover file; prints path
context-manage receive <source> [subject]  # outputs matching handover content
context-manage list                        # age + direction + subject
context-manage prune                       # remove handovers older than ttl_days
context-manage clean                       # remove all handovers
context-manage path                        # print (+ensure) the handover dir
context-manage help
```
Resolves the plugin root from its own location (`readlink -f "$0"`), sources
`../scripts/lib.sh`, dispatches. Unknown subcommand or bad direction -> usage + exit 2.

### Markdown integration
`commands/send.md`, `commands/receive.md`, `skills/send/SKILL.md`,
`skills/receive/SKILL.md`:
- Drop all hardcoded `/tmp/claude-ctx` and the inline filename/direction logic.
- **send**: Claude assembles the handover body (including the auto-captured project
  state), then pipes it to `context-manage send <target> <subject>`, which prunes,
  names, writes, and returns the path.
- **receive**: call `context-manage receive <source> [subject]`; the handover
  content is emitted to the command output for Claude to consume directly (or the
  path, for oversized files). `context-manage list` can show available handoffs.

## Data flow

- **send**: `body | context-manage send <target> <subject>` -> ctx_dir (ensure) ->
  ctx_prune -> write file -> print path.
- **receive**: `context-manage receive <source> [subject]` -> ctx_dir -> filter ->
  cat content to stdout (or path if oversized) -> Claude consumes it.
- **manage**: `context-manage list|prune|clean|path`.

## Error handling

- Handover dir uncreatable/unwritable -> `/tmp/claude-context` + `[WARN]`.
- `receive` with no matching file -> stderr message + exit 1.
- `send`/`receive` with a bad direction, or unknown subcommand -> usage + exit 2.
- Missing subject on `send` -> usage + exit 2 (the slash command supplies an
  inferred subject).
- `prune`/`clean`/`list` on an empty or missing dir -> no-op, exit 0.
- Malformed `ttl_days` in config -> use 90 + `[WARN]`.

## Testing

Bash tests (`tests/test_context_manage.sh`) with an isolated environment (temp
`HOME`, `XDG_STATE_HOME`, `XDG_CONFIG_HOME` under a `mktemp -d`):
- `ctx_dir` returns the XDG state default and creates it + README.
- Config `dir=` override honoured; `~/.claude/.context-config` is the config path.
- Fallback to `/tmp/claude-context` when the target is unwritable.
- `ttl_days` parsed from config; malformed -> 90.
- Direction mapping: `send child X` -> `ctx-parent-to-child-X.md`; `send parent X`
  -> `ctx-child-to-parent-X.md`; sibling -> `ctx-sibling-to-sibling-X.md`.
- `send` writes stdin to the correct file and prints its path; content matches.
- `receive parent X` outputs to stdout the content `send child X` wrote (matches);
  `receive` with no subject outputs the newest matching handover; no match -> exit 1.
- Size guard: a handover larger than `max_bytes` is not cat-ed; `receive` prints
  its path with a `[WARN]` instead (exit 0).
- `prune`: a `ctx-*.md` with an old mtime (`touch -d`) is removed; a fresh one is
  kept; a non-`ctx-*.md` (README) is never removed.
- `clean`: removes all `ctx-*.md`, keeps README.
- `list`: shows age/direction/subject for a known file.
- CLI dispatch: each subcommand routes; unknown/bad direction -> exit 2.

## Deliverables

- `plugins/context/scripts/lib.sh`
- `plugins/context/bin/context-manage`
- `plugins/context/tests/test_context_manage.sh`
- Updated `commands/send.md`, `commands/receive.md`, `skills/send/SKILL.md`,
  `skills/receive/SKILL.md` (call `context-manage`; drop `/tmp/claude-ctx` + inline
  naming).
- Updated `plugins/context/README.md` (persistent location, TTL, `context-manage`)
  and `CHANGELOG.md`; version bump in `.claude-plugin/plugin.json`.

## Verification

- `bash tests/test_context_manage.sh` passes.
- `context-manage path` prints a writable persistent dir under `$HOME`.
- Round trip: `echo body | context-manage send child demo` writes the file;
  `context-manage receive parent demo` outputs that body to stdout; content matches.
- `send` auto-prunes: a >90-day handover is gone after a send; a recent one remains.
- No markdown file still references `/tmp/claude-ctx`.
