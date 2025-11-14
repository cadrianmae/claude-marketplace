# cadrianmae Claude Code Marketplace

Personal marketplace for Mae's custom Claude Code plugins.

## Platform Compatibility

**Supported:** Linux, macOS, Windows (via Git Bash)

**Note for Windows users:** Context files default to `/tmp/claude-ctx/` which maps to your Git Bash temp directory. You can specify a custom path using the optional path parameter if needed (e.g., `/context:send child subject /c/Temp/`).

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
- `/context:receive` - Receive context from parent/child session
- `/context:send` - Send context before switching sessions

**File pattern:**
- Parent to child: `/tmp/claude-ctx/ctx-parent-to-child-{subject}.md`
- Child to parent: `/tmp/claude-ctx/ctx-child-to-parent-{subject}.md`

**Features:**
- Auto-creates `/tmp/claude-ctx/` directory with minimal README
- Ephemeral storage (cleared on reboot)
- Wildcard matching for context discovery

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

### datetime
Natural language date/time parsing and calculations using native GNU date command.

**Commands:**
- `/datetime:now` - Get current date/time
- `/datetime:parse` - Parse natural language expressions
- `/datetime:calc` - Calculate date differences

**Features:**
- Zero dependencies (native `date` command)
- Parse expressions: "tomorrow", "next week", "3 days", "next monday at 9am"
- Date arithmetic and difference calculations
- Custom output formatting

**Skills:**
- `datetime` - Auto-invoked for proactive temporal awareness

### code-pointer
Claude-only skill that opens files in VSCode at specific line and column positions.

**Auto-invoked when:**
- Explaining code at specific lines
- Debugging errors at particular locations
- Pointing to TODO sections or task markers
- Guiding through code reviews
- Referencing config files or documentation sections

**Features:**
- Precise line and column positioning
- Automatic path validation and conversion
- Window control options
- Progressive disclosure with focused reference files

**Skills:**
- `code-pointer` - Auto-invoked when Claude needs to show exact file locations

**Requirements:**
- VSCode with `code` CLI installed in PATH

## Scripts

### claude-session

Session management wrapper for Claude CLI with AI-powered summaries and accurate timestamp tracking.

**Features**:
- **AI Summary Generation** - Use Haiku to create concise 1-sentence summaries
- **Timestamp Tracking** - Track both created and last-modified times from session events
- **Smart Ordering** - Sessions sorted by last activity (most recent first)
- **Enhanced Display** - Show created/modified dates in list and picker
- **Project-specific Metadata** - Tags, notes, and summaries per project
- **Activity Warnings** - Alerts when summarizing recently active sessions
- **Robust Discovery** - Handles paths with dots (e.g., `github.com`) and list-type content
- **Non-invasive** - Doesn't modify Claude's native files

**Installation**:
```bash
cp scripts/claude-session ~/.local/bin/
chmod +x ~/.local/bin/claude-session
```

**Usage**:
```bash
# Session management
claude-session              # Start new session
claude-session -r           # Resume with enhanced picker (shows tags/summaries)
claude-session list         # List sessions with created/modified dates
claude-session stats        # Show statistics

# Metadata management
claude-session tag <ID> <tags...>              # Add tags
claude-session note <ID> <text>                # Add note
claude-session summary <ID> <text>             # Manual summary

# AI-powered summaries
claude-session summary --generate              # Generate for current session
claude-session summary --generate <ID>         # Generate for specific session
claude-session summary --generate <ID> --force # Overwrite existing summary

claude-session --help       # Show complete help
```

**Display Format**:
```
a3c7d3cb-6f04-47bf-8f82-c8acc9a5cef8
  Created:  2025-11-13 14:45
  Modified: 2025-11-13 19:15
  Summary: Fixed fzf picker and added AI summaries
  Tags: enhancement debugging
```

**Documentation**: See `scripts/claude-session-visual-guide.md` for complete architecture and workflow diagrams including:
- AI Summary Generation Flow
- Timestamp Tracking & Auto-Sync
- Session Discovery Process
- Enhanced Picker Flow

**Dependencies**:
- `jq` - JSON manipulation (required)
- `python3` - Session discovery (required)
- `timeout` - Command timeout handling (required)
- `fzf` - Enhanced picker (optional, falls back to select menu)

**Storage**:
- Metadata: `$PROJECT/.claude/sessions.json` (project-specific)
- Sessions: `~/.claude/projects/` (read-only, managed by Claude)

## Installation

### Local Installation
```bash
/plugin marketplace add ~/.claude/marketplaces/cadrianmae-claude-marketplace
/plugin install session-management@cadrianmae-claude-marketplace
/plugin install context-handoff@cadrianmae-claude-marketplace
/plugin install ref-tracker@cadrianmae-claude-marketplace
/plugin install datetime@cadrianmae-claude-marketplace
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
