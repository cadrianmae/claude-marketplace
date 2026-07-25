[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# context-handoff Plugin

Hierarchical parent-child session context handoff system for Claude Code.

## Commands

- `/context:receive` - Receive context from parent or child session
- `/context:send` - Send context to parent or child session before switching

## Usage

### Sending Context

```bash
/context:send child [subject]
/context:send parent [subject]
```

Subject is optional:
- **subject**: Claude will infer from conversation context if not provided

### Receiving Context

```bash
/context:receive parent [subject]
/context:receive child [subject]
```

Subject is optional:
- **subject**: Uses the most recent handover for that direction if not provided

## `context-manage` CLI

Both slash commands are thin wrappers around `bin/context-manage`, which owns
handover naming, storage, and lifecycle. It is on `PATH` for hooks/skills (see
`plugins/CONVENTIONS.md`) and can also be called directly:

```bash
context-manage send <parent|child|sibling> <subject>    # stdin -> handover; prints path
context-manage receive <parent|child|sibling> [subject]  # outputs handover content
context-manage list                                      # age, direction, live/superseded, subject
context-manage prune                                      # remove handovers older than ttl_days (default 90)
context-manage clean                                      # remove all handovers
context-manage path                                       # print the handover directory
```

Note: the standalone `path` argument that used to follow `subject` on
`/context:send` and `/context:receive` has been removed (see Changed, below) -
use `context-manage path` to find the handover directory instead.

## Handover Storage

Handovers are now stored persistently and survive a reboot:

```
${XDG_STATE_HOME:-$HOME/.local/state}/claude-context
```

This replaces the old `/tmp/claude-ctx` location, which was cleared on
reboot. Any legacy files under `/tmp/claude-ctx` are left in place untouched -
they are not migrated automatically.

### Configuration

Override defaults via `~/.claude/.context-config` (simple `key=value` lines):

| Key | Default | Meaning |
|---|---|---|
| `dir` | `${XDG_STATE_HOME:-$HOME/.local/state}/claude-context` | Handover storage directory |
| `ttl_days` | `90` | Age (in days) after which a handover is eligible for pruning |
| `max_bytes` | `28000` | Size above which `receive` prints the file path instead of inlining content |

If the configured `dir` is not writable, `context-manage` falls back to
`/tmp/claude-context` and warns on stderr.

### Auto-Prune on Send

Every `context-manage send` (and therefore every `/context:send`) triggers a
prune pass first: handovers older than `ttl_days` (default 90 days) are
removed automatically, keeping the handover directory from growing unbounded.
Run `context-manage prune` manually at any time to prune on demand, or
`context-manage clean` to remove all handovers immediately.

## File Naming Pattern

- Parent to child: `ctx-parent-to-child-{subject}.md`
- Child to parent: `ctx-child-to-parent-{subject}.md`
- Sibling to sibling: `ctx-sibling-to-sibling-{subject}.md`

Without subject:
- Send: Claude infers subject from conversation
- Receive: Uses the newest handover for that direction

## Example Workflow

**In parent session:**
```bash
/context:send child database-migration
# Start child session
```

**In child session:**
```bash
/context:receive parent
# Do focused work
/context:send parent
# Exit child session
```

**Back in parent session:**
```bash
/context:receive child
# Continue with context from child
```

## Context File Structure

Each context file includes:
- Front-matter captured automatically: from/to, subject, created timestamp,
  git branch/commit/dirty state, cwd, and what it supersedes
- Current situation and handoff reason
- Decisions made
- Work completed
- Blockers and issues
- Next actions
- Files modified

`context-manage list` shows each handover's age, direction, LIVE/SUPERSEDED
status, subject, and a `[stale]` marker if the repo has moved on since the
handover's recorded commit.

## License

MIT License - Copyright (c) Mae Capacite
