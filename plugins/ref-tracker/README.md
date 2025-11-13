# ref-tracker Plugin

Reference and research tracking system for academic work and project documentation.

## Overview

Automatically tracks research sources and major prompts to structured markdown files for academic citations, bibliographies, and project documentation.

**Two tracking files:**
- `CLAUDE_SOURCES.md` - Research sources (WebSearch, WebFetch, documentation)
- `CLAUDE_PROMPTS.md` - Major prompts and outcomes

**Key features:**
- Automatic tracking when enabled
- Configurable verbosity for academic vs development needs
- Manual retroactive scanning
- Attribution system ([User] vs [Claude])
- Silent operation (never announces tracking)

## Commands

- `/track:init` - Initialize tracking (must run first)
- `/track:update` - Retroactive scan of last 20 messages
- `/track:auto` - Toggle auto-tracking on/off
- `/track:config` - View or update verbosity settings
- `/track:help` - Show comprehensive help

## Quick Start

```bash
# 1. Initialize tracking
/track:init

# 2. Work normally - sources and prompts tracked automatically

# 3. Adjust verbosity if needed
/track:config prompts=minimal    # Less verbose
/track:config sources=off         # Disable source tracking

# 4. Toggle auto-tracking as needed
/track:auto                       # Pause/resume tracking
```

## File Structure

After `/track:init`:

```
.claude/
├── .ref-autotrack          # Marker: auto-tracking enabled
└── .ref-config             # Verbosity settings
CLAUDE_SOURCES.md           # Research sources (KV format)
CLAUDE_PROMPTS.md           # Major prompts and outcomes
```

## Verbosity Configuration

Located in `./.claude/.ref-config`:

### PROMPTS_VERBOSITY

- **`major`** (default) - Only significant multi-step academic/development work
- **`all`** - Track every user request
- **`minimal`** - Only explicit user requests to track
- **`off`** - Disable prompt tracking

### SOURCES_VERBOSITY

- **`all`** (default) - Track all WebSearch/WebFetch operations
- **`off`** - Disable source tracking

## File Formats

### CLAUDE_SOURCES.md

Pure KV format (no headers):

```
[User] WebSearch("PostgreSQL foreign keys"): https://postgresql.org/docs/current/ddl-constraints.html
[Claude] WebFetch("https://go.dev/doc/", "embed.FS"): Use embed.FS to embed static files at compile time
[Claude] Grep("CORS middleware", "*.go"): Found in api/routes.go:23-45
```

**Attribution:**
- `[User]` - User explicitly requested ("search the web for...")
- `[Claude]` - Claude autonomously searched for missing info

### CLAUDE_PROMPTS.md

Two-line format with blank separator:

```markdown
# CLAUDE_PROMPTS.md

This file tracks significant prompts and development decisions.

---

Prompt: "Implement JWT authentication"
Outcome: Created auth middleware, login/logout endpoints, JWT token generation and verification, integrated with user model

Prompt: "Debug slow database queries"
Outcome: Added query logging, identified N+1 problem, implemented eager loading, reduced query time from 2.3s to 0.15s

```

## Academic Workflow Example

**1. Setup project:**
```bash
cd ~/research/thesis-project
/track:init
```

**2. Research session:**
- Search for papers → automatically logged to CLAUDE_SOURCES.md
- Implement features → major work logged to CLAUDE_PROMPTS.md
- Ask questions → research logged with attribution

**3. Export for paper:**
- CLAUDE_SOURCES.md → Bibliography/Works Cited
- CLAUDE_PROMPTS.md → Methodology/Implementation section
- Clear audit trail of research process

**4. Adjust as needed:**
```bash
/track:config prompts=minimal    # Less verbose prompts
/track:auto                       # Pause during exploration
```

## Use Cases

**Research papers:**
- Track all sources for bibliography
- Document methodology in prompts
- Clear citation trail

**Development projects:**
- Track all searches for reference
- Document major decisions
- Project retrospectives

**Learning/study:**
- Track resources discovered
- Document problem-solving process
- Review learning path

## Skill Integration

The **ref-tracker skill** automatically tracks when enabled:
- Activates when tracking files detected
- Checks `./.claude/.ref-autotrack` for activation
- Respects `./.claude/.ref-config` verbosity
- Silent operation (never announces)

## Tips

- Use `prompts=major` for academic work (less verbose)
- Use `prompts=all` for complete audit trail
- Toggle `/track:auto` to pause during exploration
- Run `/track:update` to capture recent work retroactively
- Sources useful for citations and bibliography

## License

MIT License - Copyright (c) Mae Capacite
