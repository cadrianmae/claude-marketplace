# fetch - Receive context from parent or child session

Read and integrate context from a parent or child session handoff file.

## Usage

```
/context:fetch parent [subject] [path]
/context:fetch child [subject] [path]
```

Both subject and path are optional:
- **subject**: Claude will infer from context if not provided
- **path**: Defaults to `/tmp/` if not provided

## What it does

1. Determines direction: parent-to-child or child-to-parent
2. If subject provided, looks for `{path}/ctx-{direction}-{subject}.md`
3. If no subject, uses wildcard: `{path}/ctx-{direction}-*.md` (finds any matching file)
4. Path defaults to `/tmp/` but can be customized
5. Reads and displays context file
6. Integrates context into current session understanding

## Example: Receiving from Parent (Wildcard)

```
/context:fetch parent

✓ Searching for context files: /tmp/ctx-parent-to-child-*.md
✓ Found: /tmp/ctx-parent-to-child-database-migration.md

[Context displayed with parent session details]

Ready to begin focused work based on parent's context!
```

## Example: Receiving from Child with Subject

```
/context:fetch child api-implementation

✓ Context received from child session
  File: /tmp/ctx-child-to-parent-api-implementation.md

[Context displayed with completed work summary]

Child session completed. Integrating results back.
```

## Example: Custom Path

```
/context:fetch parent database-work ~/Documents/context/

✓ Context received from parent session
  File: ~/Documents/context/ctx-parent-to-child-database-work.md

[Context displayed]
```

## What gets loaded

- **Context file content**: Decisions, work done, blockers, next actions
- **Handoff metadata**: Why the handoff occurred, what was planned
- **Related context**: Key information needed to continue

## When to use

- Immediately after starting a new child session from parent
- After resuming parent session when child is complete
- When receiving context from any parent/child session
- To understand what happened in related session

## Related commands

- `/context:send` - Send context to parent/child before switching
