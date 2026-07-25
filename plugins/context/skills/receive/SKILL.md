---
name: receive
description: Receive context from parent, child, or sibling session
argument-hint: <direction> [subject]
allowed-tools: Bash, Read
disable-model-invocation: true
---

## Receiving Context

**Received At**: !`date '+%Y-%m-%d %H:%M:%S'`
**Handover Dir**: !`context-manage path`

---

## Quick Example

```bash
context-manage receive child api-implementation
# prints the handover content directly (or a path + [WARN] if oversized)
```

---

# receive - Receive context from parent, child, or sibling session

Read and integrate context from session handoff file.

## Usage

```
/context:receive parent [subject]
/context:receive child [subject]
/context:receive sibling [subject]
```

**IMPORTANT: Direction is REQUIRED.** Must be one of: `parent`, `child`, or `sibling`.

Subject is optional -- infer it from context if the user omits it; without a subject the script falls back to the newest handover for that direction. The handover location is managed by `context-manage` (see `context-manage path`).

## Steps

1. **Validate the direction** - error if it is not parent|child|sibling
2. Map the direction from the argument
3. **Record the received timestamp** (auto-captured)
4. Call the script; its output is the handover content itself:

   ```bash
   context-manage receive <direction> [subject]
   ```
5. Print the content directly, or - for an oversized handover - a path with a
   `[WARN]`, in which case read that path
6. If the user provided a subject, the script looks up that exact handover; if
   omitted, it uses the newest handover for that direction
7. Integrate the context into your understanding of the current session.

**Important:** Without a subject, the script picks the newest handover for that direction, ensuring you get the most recent context.

## Example: Receiving from Parent (No Subject)

```
/context:receive parent

$ context-manage receive parent
[INFO] ctx-parent-to-child-database-migration.md
[Context displayed with parent session details]

Ready to begin focused work based on parent's context!
```

## Example: Receiving from Child with Subject

```
/context:receive child api-implementation

$ context-manage receive child api-implementation
[INFO] ctx-child-to-parent-api-implementation.md
[Context displayed with completed work summary]

Child session completed. Integrating results back.
```

## Example: Receiving from Sibling

```
/context:receive sibling parallel-task

$ context-manage receive sibling parallel-task
[INFO] ctx-sibling-to-sibling-parallel-task.md
[Context displayed with parallel work details]

Sibling session completed. Integrating parallel work.
```

## Example: Oversized Handover

```
/context:receive parent

$ context-manage receive parent
[INFO] ctx-parent-to-child-large-refactor.md
[WARN] handover too large to inline (41230 bytes); read it directly:
/home/user/.local/state/claude-context/ctx-parent-to-child-large-refactor.md

[Read the file at the printed path instead of relying on stdout]
```

## Example: Missing Direction (Error)

```
/context:receive database-work

✗ Error: Must specify direction: parent, child, or sibling
  Usage: /context:receive <parent|child|sibling> [subject]
```

## What gets loaded

- **Context file content**: Decisions, work done, blockers, next actions
- **Handoff metadata**: Why the handoff occurred, what was planned
- **Related context**: Key information needed to continue

## When to use

- Immediately after starting a new child session from parent
- After resuming parent session when child is complete
- When starting a sibling session and receiving context from another sibling
- When receiving context from any parent/child/sibling session
- To understand what happened in related session

## Related commands

- `/context:send` - Send context to parent/child before switching
