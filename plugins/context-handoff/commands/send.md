---
description: Send context to parent or child session before switching
argument-hint: <direction> [subject] [path]
allowed-tools: Bash, Write
---

# send - Send context to child or parent session

Create a context handoff file for transitioning between parent and child sessions.

## Usage

```
/context:send child [subject] [path]
/context:send parent [subject] [path]
```

Both subject and path are optional:
- **subject**: Claude will infer from current conversation context if not provided
- **path**: Defaults to `/tmp/claude-ctx/` if not provided

## What it does

1. Checks if `/tmp/claude-ctx/` directory exists using test command
2. Creates directory only if it doesn't exist
3. If creating directory, generates minimal README.md:
   ```markdown
   # Claude Context Handoff Directory

   This is an **ephemeral directory** for Claude Code session context handoff. Created by claude slash commands. '/context:send' and '/context:receive'.
   ```
3. Determines direction: parent-to-child or child-to-parent
4. If subject provided, creates `{path}/ctx-{direction}-{subject}.md`
5. If no subject, infers from current conversation context and creates file with inferred name
6. Path defaults to `/tmp/claude-ctx/` but can be customized
7. Uses `cat > filename.md << 'EOF'` to clear file and write context
8. Includes:
   - Current situation and context
   - Decisions made and work completed
   - Blockers and next actions
   - Files modified
9. Shows clear "next steps" for user

**File naming pattern:**
- `/context:send child` → `/tmp/claude-ctx/ctx-parent-to-child-{inferred-subject}.md`
- `/context:send parent` → `/tmp/claude-ctx/ctx-child-to-parent-{inferred-subject}.md`

## Example: Sending to Child with Subject

```
/context:send child database-migration

✓ Context prepared for child session
  File: /tmp/claude-ctx/ctx-parent-to-child-database-migration.md

Next steps:
1. Start child session for focused work
2. In new session, run: /context:receive parent
```

## Example: Sending to Parent (Subject Inferred)

```
/context:send parent

✓ Context prepared for parent session
  File: /tmp/claude-ctx/ctx-child-to-parent-api-implementation.md

Next steps:
1. Exit this session
2. Resume parent session
3. In parent session, run: /context:receive child
```

## Example: Custom Path

```
/context:send child feature-work ~/Documents/context/

✓ Context prepared for child session
  File: ~/Documents/context/ctx-parent-to-child-feature-work.md

Next steps:
1. Start child session
2. In new session, run: /context:receive parent feature-work ~/Documents/context/
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

**Create directory if needed:**

```bash
# Check if directory exists, create only if needed
[[ -d /tmp/claude-ctx ]] || {
    mkdir -p /tmp/claude-ctx
    cat > /tmp/claude-ctx/README.md << 'EOF'
# Claude Context Handoff Directory

This is an **ephemeral directory** for Claude Code session context handoff. Created by claude slash commands. '/context:send' and '/context:receive'.
EOF
}
```

**Write context file:**

Use heredoc to write context file:

```bash
cat > /tmp/claude-ctx/ctx-parent-to-child-{subject}.md << 'EOF'
# Context: Parent → Child

[Context content here]
EOF
```

This pattern clears the file first, preventing accumulation of old context.

## When to use

- Before starting a child session from parent
- Before returning to parent after completing child work
- When switching between hierarchy levels
- When context needs to be passed between sessions

## Related commands

- `/context:receive` - Receive context from parent/child session
