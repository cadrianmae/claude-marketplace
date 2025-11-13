# cadrianmae Claude Code Marketplace

Personal marketplace for Mae's custom Claude Code plugins.

## Available Plugins

### session-management
Flat session management system with `.current-session` tracking.

**Commands:**
- `/session-start` - Start new session
- `/session-end` - End with comprehensive summary
- `/session-update` - Add notes to current session
- `/session-current` - Show current status
- `/session-list` - List all sessions
- `/session-resume` - Resume previous session
- `/session-help` - Show help

### context-handoff
Generic hierarchical parent-child session context handoff.

**Commands:**
- `/ctx-from` - Receive context from parent/child
- `/ctx-to` - Send context before switching sessions

### doc-tracking
Documentation tracking for research sources and development prompts.

**Commands:**
- `/tracking/init` - Setup tracking files and enable
- `/tracking/update` - Retroactive scan of history
- `/tracking/autotrack` - Enable continuous tracking

**Skills:**
- `doc-tracker` - Automatic tracking when enabled

## Installation

### Local Installation
```bash
/plugin marketplace add ~/.claude/marketplaces/cadrianmae-claude-marketplace
/plugin install session-management@cadrianmae-claude-marketplace
/plugin install context-handoff@cadrianmae-claude-marketplace
/plugin install doc-tracking@cadrianmae-claude-marketplace
```

### From GitHub (when pushed)
```bash
/plugin marketplace add cadrianmae/claude-marketplace
/plugin install session-management@cadrianmae-claude-marketplace
```

## Plugin Sources

Plugins will be located in `./plugins/` subdirectories once created.

## License

Personal use - MIT License
