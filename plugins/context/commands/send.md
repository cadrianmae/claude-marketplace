---
description: Send context to parent, child, or sibling session before switching
argument-hint: <direction> [subject]
allowed-tools: Bash
---

## Current Project State (Auto-Captured)

**Timestamp**: !`date '+%Y-%m-%d %H:%M:%S'`
**Working Directory**: !`pwd`
**Git Branch**: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Not in git repo"`
**Git Status**: !`git status --short 2>/dev/null | head -10 || echo "No changes"`
**Last Commit**: !`git log -1 --oneline 2>/dev/null || echo "No commits"`

**Handover Dir**: !`context-manage path`

---

## Quick Example

```bash
context-manage send child "feature-work" <<'EOF'
[handover body]
EOF
/home/user/.local/state/claude-context/ctx-parent-to-child-feature-work.md
```

---

# send - Send context to child, parent, or sibling session

Create a context handoff file for transitioning between sessions.

## Usage

```
/context:send child [subject]
/context:send parent [subject]
/context:send sibling [subject]
```

**IMPORTANT: Direction is REQUIRED.** Must be one of: `parent`, `child`, or `sibling`.

Subject is optional -- infer it from the current conversation if the user omits it. The handover location is managed by `context-manage` (see `context-manage path`).

## Steps

1. **Validate the direction** - error if it is not parent|child|sibling
2. Map the direction from the argument
3. **Auto-capture project state** (timestamp, git branch, working dir, git status)
4. If the user did not provide a subject, infer one from the current conversation
5. Assemble the handover body and pipe it to the script (it names the
   file, captures git/cwd/time, prunes stale handovers, and prints the path):

   ```bash
   context-manage send <direction> "<subject>" <<'EOF'
   <handover body>
   EOF
   ```
6. Show the user clear next steps.

**File naming pattern (handled by the script):**
- `context-manage send child <subject>` -> `ctx-parent-to-child-<subject>.md`
- `context-manage send parent <subject>` -> `ctx-child-to-parent-<subject>.md`
- `context-manage send sibling <subject>` -> `ctx-sibling-to-sibling-<subject>.md`

## Example: Sending to Child with Subject

```
/context:send child database-migration

$ context-manage send child "database-migration" <<'EOF'
[handover body]
EOF
/home/user/.local/state/claude-context/ctx-parent-to-child-database-migration.md

Next steps:
1. Start child session for focused work
2. In new session, run: /context:receive parent
```

## Example: Sending to Parent (Subject Inferred)

```
/context:send parent

$ context-manage send parent "api-implementation" <<'EOF'
[handover body]
EOF
/home/user/.local/state/claude-context/ctx-child-to-parent-api-implementation.md

Next steps:
1. Exit this session
2. Resume parent session
3. In parent session, run: /context:receive child
```

## Example: Sending to Sibling Session

```
/context:send sibling parallel-task

$ context-manage send sibling "parallel-task" <<'EOF'
[handover body]
EOF
/home/user/.local/state/claude-context/ctx-sibling-to-sibling-parallel-task.md

Next steps:
1. Start sibling session for parallel work
2. In new session, run: /context:receive sibling parallel-task
```

## Example: Missing Direction (Error)

```
/context:send database-work

✗ Error: Must specify direction: parent, child, or sibling
  Usage: /context:send <parent|child|sibling> [subject]
```

## Context File Contents

The context file should include:

### Current Situation
- What work is being done
- Why the handoff is happening
- What the next session needs to focus on

### Decisions Made
- Key technical choices
- Trade-offs considered
- Rationale for decisions

### Work Completed
- What has been implemented
- Files created/modified
- Tests written
- Commits made

### Blockers & Issues
- Problems encountered
- Questions that arose
- Things to investigate

### Next Actions
- What should happen next
- Specific tasks for the receiving session
- Dependencies or prerequisites

## Implementation Pattern

Assemble the handover body, then pipe it to `context-manage send`:

```bash
context-manage send <direction> "<subject>" <<'EOF'
# Context: Parent -> Child

[Context content here]
EOF
```

This clears any existing file for the same direction+subject, preventing
accumulation of old context.

## When to use

- Before starting a child session from parent
- Before returning to parent after completing child work
- When switching between hierarchy levels
- When starting a sibling session for parallel work
- When context needs to be passed between sessions

## Related commands

- `/context:receive` - Receive context from parent/child session
