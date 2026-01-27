[![Version](https://img.shields.io/badge/version-1.3.3-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# context-handoff Plugin

Hierarchical parent-child session context handoff system for Claude Code.

## Commands

- `/context:receive` - Receive context from parent or child session
- `/context:send` - Send context to parent or child session before switching

## Usage

### Sending Context

```bash
/context:send child [subject] [path]
/context:send parent [subject] [path]
```

Both subject and path are optional:
- **subject**: Claude will infer from conversation context if not provided
- **path**: Defaults to `/tmp/claude-ctx/` if not provided

### Receiving Context

```bash
/context:receive parent [subject] [path]
/context:receive child [subject] [path]
```

Both subject and path are optional:
- **subject**: Uses wildcard matching if not provided
- **path**: Defaults to `/tmp/claude-ctx/` if not provided

## File Naming Pattern

- Parent to child: `/tmp/claude-ctx/ctx-parent-to-child-{subject}.md`
- Child to parent: `/tmp/claude-ctx/ctx-child-to-parent-{subject}.md`

Without subject:
- Send: Claude infers subject from conversation
- Receive: Uses wildcard `ctx-{direction}-*.md`

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
- Current situation and handoff reason
- Decisions made
- Work completed
- Blockers and issues
- Next actions
- Files modified

## License

MIT License - Copyright (c) Mae Capacite
