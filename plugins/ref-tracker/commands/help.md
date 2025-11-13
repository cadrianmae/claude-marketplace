# help - Reference tracking system help

Comprehensive help for the ref-tracker system.

## Overview

The ref-tracker system automatically tracks research sources and major prompts for academic work and project documentation.

**Two tracking files:**
- `CLAUDE_SOURCES.md` - Research sources (WebSearch, WebFetch, documentation)
- `CLAUDE_PROMPTS.md` - Major prompts and outcomes

**Key features:**
- Automatic tracking when enabled
- Configurable verbosity
- Manual retroactive scanning
- Attribution system ([User] vs [Claude])

## Commands

### `/track:init` - Initialize tracking
Set up tracking files and configuration for the current project.

Creates:
- `CLAUDE_SOURCES.md` (empty)
- `CLAUDE_PROMPTS.md` (with header)
- `.claude/.ref-autotrack` (enables auto-tracking)
- `.claude/.ref-config` (verbosity settings)

**Run this first** before using other tracking commands.

---

### `/track:update` - Retroactive scan
Scan last 20 messages and add missing tracking entries.

Works even when auto-tracking is disabled (manual override).
Respects verbosity configuration.

**Use when:** You want to capture recent work retroactively.

---

### `/track:auto` - Toggle auto-tracking
Enable or disable automatic tracking.

**Enabled:** ref-tracker skill automatically logs sources and prompts
**Disabled:** Manual tracking only via `/track:update`

**Use when:** You want to pause/resume automatic tracking.

---

### `/track:config` - Manage verbosity
View or update tracking verbosity settings.

**View:** `/track:config`
**Update:** `/track:config prompts=all sources=off`

**Use when:** You want to control what gets tracked.

---

### `/track:help` - Show this help
Display comprehensive documentation.

## File Formats

### CLAUDE_SOURCES.md

**Format:** Pure KV file (no headers, one line per entry)

**Pattern:** `[Attribution] Tool("query"): result`

**Examples:**
```
[User] WebSearch("PostgreSQL foreign keys tutorial"): https://postgresql.org/docs/current/ddl-constraints.html
[Claude] WebFetch("https://go.dev/doc/", "embed.FS usage"): Use embed.FS to embed static files at compile time
[Claude] Grep("CORS middleware", "*.go"): Found in api/routes.go:23-45
```

**Attribution:**
- **[User]** - User explicitly requested ("search the web for...")
- **[Claude]** - Claude autonomously searched for missing information

---

### CLAUDE_PROMPTS.md

**Format:** Two-line entries with blank separator

**Pattern:**
```
Prompt: "user request"
Outcome: what was accomplished

```

**Example:**
```markdown
# CLAUDE_PROMPTS.md

This file tracks significant prompts and development decisions.

---

Prompt: "Implement user authentication with JWT"
Outcome: Created auth middleware, login/logout endpoints, JWT token generation and verification, integrated with database user model

Prompt: "Debug slow database queries"
Outcome: Added query logging, identified N+1 problem in user posts endpoint, implemented eager loading, reduced query time from 2.3s to 0.15s

```

---

## Verbosity Settings

Located in `./.claude/.ref-config`:

### PROMPTS_VERBOSITY

- **`major`** (default) - Significant multi-step academic/development work
- **`all`** - Every user request
- **`minimal`** - Only explicit user requests to track
- **`off`** - Disable prompt tracking

### SOURCES_VERBOSITY

- **`all`** (default) - Track all WebSearch/WebFetch operations
- **`off`** - Disable source tracking

## Academic Workflow Example

**1. Setup (once per project):**
```bash
/track:init
```

**2. Work session:**
- Auto-tracking captures all searches and major work
- Sources logged to CLAUDE_SOURCES.md
- Prompts logged to CLAUDE_PROMPTS.md

**3. Review tracked data:**
- Open CLAUDE_SOURCES.md - see all research sources
- Open CLAUDE_PROMPTS.md - see work completed
- Use for citations, bibliography, project documentation

**4. Adjust if needed:**
```bash
/track:config prompts=minimal    # Less verbose
/track:auto                       # Pause tracking
```

**5. Export for paper:**
- CLAUDE_SOURCES.md entries become citations
- CLAUDE_PROMPTS.md becomes methodology section
- Clear audit trail of research process

## Tips

**For research papers:**
- Keep `prompts=major` and `sources=all`
- Review CLAUDE_SOURCES.md for bibliography
- Use prompts for methodology section

**For development projects:**
- Use `prompts=all` for complete audit
- CLAUDE_PROMPTS.md documents decisions
- Useful for project retrospectives

**For focused work:**
- Use `/track:auto` to toggle off
- Manual `/track:update` when needed
- Reduces noise during exploration

## File Locations

- Tracking files: Project root (`./CLAUDE_SOURCES.md`, `./CLAUDE_PROMPTS.md`)
- Configuration: `./.claude/.ref-config`
- Auto-tracking marker: `./.claude/.ref-autotrack`

## Common Issues

**"No tracking files found"**
→ Run `/track:init` first

**"Too verbose"**
→ Use `/track:config prompts=minimal`

**"Missing recent searches"**
→ Run `/track:update` to scan history

**"Want to pause tracking"**
→ Use `/track:auto` to toggle off

## Related

- **ref-tracker skill** - Automatic tracking when enabled
- **Global CLAUDE.md** - Documents the system in detail
- **Project CLAUDE.md** - Can contain project-specific notes

---

For more help, consult plugin README or global ~/.claude/CLAUDE.md documentation.
