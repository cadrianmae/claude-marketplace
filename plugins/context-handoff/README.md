# context-handoff Plugin

Hierarchical parent-child session context handoff system for Claude Code.

## Commands

- `/context:fetch` - Receive context from parent or child session
- `/context:send` - Send context to parent or child session before switching

## Usage

### Sending Context

```bash
/context:send child [subject] [path]
/context:send parent [subject] [path]
```

Both subject and path are optional:
- **subject**: Claude will infer from conversation context if not provided
- **path**: Defaults to `/tmp/` if not provided

### Fetching Context

```bash
/context:fetch parent [subject] [path]
/context:fetch child [subject] [path]
```

Both subject and path are optional:
- **subject**: Uses wildcard matching if not provided
- **path**: Defaults to `/tmp/` if not provided

## File Naming Pattern

- Parent to child: `/tmp/ctx-parent-to-child-{subject}.md`
- Child to parent: `/tmp/ctx-child-to-parent-{subject}.md`

Without subject:
- Send: Claude infers subject from conversation
- Fetch: Uses wildcard `ctx-{direction}-*.md`

## Example Workflow

**In parent session:**
```bash
/context:send child database-migration
# Start child session
```

**In child session:**
```bash
/context:fetch parent
# Do focused work
/context:send parent
# Exit child session
```

**Back in parent session:**
```bash
/context:fetch child
# Continue with context from child
```

## Context File Structure

Each context file includes:
- Current situation and handoff reason
- Decisions made
- Work completed
- Blockers and issues
- Next actions
- Files modified

## License

MIT License - Copyright (c) Mae Capacite
