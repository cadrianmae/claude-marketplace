---
name: help
description: This skill should be used when the user asks for help with tracking, how to use the track plugin, tracking documentation, what tracking commands are available, how hooks-based tracking works, track plugin overview, or explanation of verbosity settings. Displays comprehensive documentation covering commands, file formats, verbosity settings, academic workflow examples, v2.0 architecture, and migration from v1.x.
allowed-tools: Read
disable-model-invocation: true
user-invocable: false
---

## Quick Example

```bash
/track:help
# Displays comprehensive hooks-based tracking documentation
# Commands, file formats, verbosity settings, and workflow examples
```

# help - Hooks-Based Tracking System Help

Comprehensive help for the Track Plugin v2.0 hooks-based automatic tracking system.

## Overview

The Track Plugin v2.0 uses Claude Code hooks for **fully automatic** reference and prompt tracking for academic work and project documentation.

**Two tracking files:**
- `claude_usage/sources.md` - Research sources (WebSearch, WebFetch, documentation)
- `claude_usage/prompts.md` - Major prompts and outcomes

**Key features:**
- **Automatic tracking via hooks** (PostToolUse, UserPromptSubmit, SessionEnd)
- **No skill activation needed** - hooks run automatically
- **Per-project activation** - only tracks when enabled
- **Configurable verbosity** - control what gets tracked
- **Export support** - generate bibliographies and methodology sections
- **Attribution system** - tracks [User] vs [Claude] initiated sources

## v2.0 Architecture

**Hooks-based tracking** (NEW):
- **PostToolUse hook** → Automatically tracks WebSearch/WebFetch/Read/Grep to `claude_usage/sources.md`
- **UserPromptSubmit hook** → Captures user prompts to temporary storage
- **SessionEnd hook** → Pairs prompts with outcomes, writes to `claude_usage/prompts.md`

**Fully automatic** - no manual intervention:
- Hooks check for `.claude/.ref-autotrack` marker
- If present, hooks track automatically
- No skill activation needed (unlike v1.x)

## Commands (Skills)

### `/track:init` - Initialize tracking
Set up hooks-based tracking files and configuration for the current project.

Creates:
- `claude_usage/sources.md` (with preamble)
- `claude_usage/prompts.md` (with preamble)
- `.claude/.ref-autotrack` (enables hooks)
- `.claude/.ref-config` (verbosity settings)

**Run this first** before using other tracking commands.

---

### `/track:auto` - Toggle hooks-based tracking
Enable or disable automatic hooks-based tracking.

```bash
/track:auto          # Toggle
/track:auto on       # Enable
/track:auto off      # Disable
```

**Enabled:** Hooks run automatically
**Disabled:** Hooks are inactive

**Use when:** You want to pause/resume automatic tracking.

---

### `/track:config` - Manage verbosity and export
View or update tracking verbosity and export configuration.

```bash
/track:config                            # Interactive mode (AskUserQuestion)
/track:config prompts=all sources=off    # Direct mode
/track:config export_path=paper/refs/    # Set export path
```

**Use when:** You want to control what gets tracked or where exports go.

---

### `/track:export` - Export tracked data
Generate bibliographies, methodology sections, or other export formats.

```bash
/track:export bibliography              # → exports/bibliography.md
/track:export methodology               # → exports/methodology.md
/track:export bibtex references.bib     # → references.bib
/track:export timeline                  # → exports/timeline.md
```

**Use when:** You need to generate output for academic papers or reports.

---

### `/track:help` - Show this help
Display comprehensive documentation.

---

## File Formats

### claude_usage/sources.md

**Format:** Pure KV file with preamble

**Pattern:** `[Attribution] Tool("query"): result`

**Examples:**
```
[User] WebSearch("PostgreSQL foreign keys tutorial"): https://postgresql.org/docs/current/ddl-constraints.html
[Claude] WebFetch("https://go.dev/doc/", "embed.FS usage"): Use embed.FS to embed static files at compile time
[Claude] Read("docs/api.md"): Documentation reference
[Claude] Grep("middleware", pattern="CORS"): Documentation reference
```

**Attribution:**
- **[User]** - User explicitly requested ("search the web for...")
- **[Claude]** - Claude autonomously searched for missing information

**Preamble:** Explains format, usage, and configuration

---

### claude_usage/prompts.md

**Format:** Three-line entries with blank separator

**Pattern:**
```
Prompt: "user request"
Outcome: what was accomplished
Session: timestamp

```

**Example:**
```markdown
# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

---

Prompt: "Implement user authentication with JWT"
Outcome: Created auth middleware, login/logout endpoints, JWT token generation and verification, integrated with database user model
Session: 2026-01-27 14:23:15

Prompt: "Debug slow database queries"
Outcome: Added query logging, identified N+1 problem in user posts endpoint, implemented eager loading, reduced query time from 2.3s to 0.15s
Session: 2026-01-27 15:42:08

```

**Preamble:** Explains format, usage, and configuration

---

## Verbosity Settings

Located in `./.claude/.ref-config`:

### PROMPTS_VERBOSITY

- **`major`** (default) - Significant multi-step academic/development work
  - Heuristic: Response >100 words
  - Best for project documentation
- **`all`** - Every user request
  - Best for complete session logs
- **`minimal`** - Only explicit user requests to track
  - Best for selective curation
- **`off`** - Disable prompt tracking

### SOURCES_VERBOSITY

- **`all`** (default) - Track all WebSearch/WebFetch/Read/Grep operations
  - Best for complete research audit trail
- **`off`** - Disable source tracking

### EXPORT_PATH (new in v2.0)

- Default directory for `/track:export` output
- Examples: `exports/`, `paper/references/`, `/tmp/tracking/`
- Can be absolute or relative path

## Academic Workflow Example

**1. Setup (once per project):**
```bash
/track:init
```

**2. Work session:**
- Hooks capture all searches and major work automatically
- Sources logged to `claude_usage/sources.md`
- Prompts logged to `claude_usage/prompts.md`
- **No manual intervention needed**

**3. Review tracked data:**
```bash
tail claude_usage/sources.md    # Recent sources
tail claude_usage/prompts.md    # Recent work
grep "authentication" claude_usage/prompts.md
```

**4. Adjust if needed:**
```bash
/track:config prompts=minimal    # Less verbose
/track:auto off                  # Pause tracking
```

**5. Export for paper:**
```bash
/track:export bibliography       # Generate bibliography
/track:export methodology        # Generate methodology section
/track:export bibtex refs.bib    # Generate BibTeX file
```

## Tips

**For research papers:**
- Keep `prompts=major` and `sources=all`
- Review `claude_usage/sources.md` for bibliography
- Use prompts for methodology section
- Export to BibTeX for LaTeX papers

**For development projects:**
- Use `prompts=all` for complete audit
- `claude_usage/prompts.md` documents decisions
- Useful for project retrospectives
- Export timeline for progress reports

**For focused work:**
- Use `/track:auto off` to pause tracking
- Manual `/track:export` when needed
- Reduces noise during exploration

## File Locations

- Tracking files: `./claude_usage/` directory
  - `claude_usage/sources.md`
  - `claude_usage/prompts.md`
- Configuration: `./.claude/.ref-config`
- Auto-tracking marker: `./.claude/.ref-autotrack`
- Temporary storage: `./.claude/.track-tmp/` (automatic cleanup)

## Common Issues

**"No tracking files found"**
→ Run `/track:init` first

**"Too verbose"**
→ Use `/track:config prompts=minimal`

**"Want to pause tracking"**
→ Use `/track:auto off`

**"Need to export for paper"**
→ Use `/track:export bibliography`

**"Where are my old files?"**
→ v2.0 uses `claude_usage/` directory instead of root-level files
→ Run `/track:init` to migrate from `CLAUDE_*.md` files

## v2.0 Changes from v1.x

**Major changes:**
- **Hooks-based architecture** - Fully automatic, no skill activation
- **New directory:** `claude_usage/` instead of root-level files
- **File preambles:** Explanatory headers in tracked files
- **Export support:** `/track:export` command for output generation
- **Enhanced config:** EXPORT_PATH setting added
- **Deprecated:** `ref-tracker` skill, `/track:update` command

**Migration:**
- Existing `.ref-autotrack` and `.ref-config` work unchanged
- Run `/track:init` to migrate old `CLAUDE_*.md` files
- Remove manual `/track:update` calls (automatic now)

## Related

- **Plugin hooks** - PostToolUse, UserPromptSubmit, SessionEnd
- **Global CLAUDE.md** - Documents the system in detail
- **Project CLAUDE.md** - Can contain project-specific notes

---

For more help, consult plugin README or MIGRATION.md for v1.x → v2.0 upgrade guide.
