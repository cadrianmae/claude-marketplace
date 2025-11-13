# cadrianmae Claude Code Marketplace

Personal marketplace for Mae's custom Claude Code plugins.

## Platform Compatibility

**Supported:** Linux, macOS, Windows (via Git Bash)

**Note for Windows users:** Context files default to `/tmp/` which maps to your Git Bash temp directory. You can specify a custom path using the optional path parameter if needed (e.g., `/context:send child subject /c/Temp/`).

## Available Plugins

### session
Flat session management system with `.current-session` tracking.

**Commands:**
- `/session:start` - Start new session
- `/session:end` - End with comprehensive summary
- `/session:update` - Add notes to current session
- `/session:current` - Show current status
- `/session:list` - List all sessions
- `/session:resume` - Resume previous session
- `/session:help` - Show help

### context-handoff
Generic hierarchical parent-child session context handoff.

**Commands:**
- `/context:fetch` - Receive context from parent/child session
- `/context:send` - Send context before switching sessions

**File pattern:**
- Parent to child: `/tmp/ctx-parent-to-child-{subject}.md`
- Child to parent: `/tmp/ctx-child-to-parent-{subject}.md`

### ref-tracker
Reference and research tracking for academic work and project documentation.

**Commands:**
- `/track:init` - Initialize tracking (run first)
- `/track:update` - Retroactive scan of history
- `/track:auto` - Toggle auto-tracking on/off
- `/track:config` - View or update verbosity settings
- `/track:help` - Show comprehensive help

**Files created:**
- `CLAUDE_SOURCES.md` - Research sources (KV format)
- `CLAUDE_PROMPTS.md` - Major prompts and outcomes
- `.claude/.ref-autotrack` - Auto-tracking marker
- `.claude/.ref-config` - Verbosity configuration

**Skills:**
- `ref-tracker` - Automatic tracking when enabled

## Installation

### Local Installation
```bash
/plugin marketplace add ~/.claude/marketplaces/cadrianmae-claude-marketplace
/plugin install session-management@cadrianmae-claude-marketplace
/plugin install context-handoff@cadrianmae-claude-marketplace
/plugin install ref-tracker@cadrianmae-claude-marketplace
```

### From GitHub
```bash
/plugin marketplace add cadrianmae/claude-marketplace
/plugin install session-management@cadrianmae-claude-marketplace
```

## Plugin Sources

Plugins are located in `./plugins/` subdirectories. See individual plugin READMEs for detailed documentation.

## External Integrations

This marketplace includes adapted code from third-party open source projects:

### session-management Plugin
**Original:** [claude-sessions](https://github.com/iannuttall/claude-sessions) by Ian Nuttall
**License:** MIT License
**Modifications:** Adapted for user-level installation, added session-resume command, updated command namespaces

See [THIRD-PARTY-NOTICES.md](./THIRD-PARTY-NOTICES.md) for complete attribution and license information.

## License

MIT License

- Original claude-sessions code: Copyright (c) Ian Nuttall
- Modifications and marketplace: Copyright (c) Mae Capacite
