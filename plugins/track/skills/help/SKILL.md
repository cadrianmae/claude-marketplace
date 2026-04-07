---
name: help
description: "This skill should be used when the user asks for help with tracking, how to use the track plugin, tracking documentation, what tracking commands are available, how hooks-based tracking works, track plugin overview, or explanation of verbosity settings. Displays comprehensive documentation covering commands, file formats, verbosity settings, academic workflow examples, v2.0 architecture, and migration from v1.x."
allowed-tools: [Read]
disable-model-invocation: true
user-invocable: true
---

## Quick Example

```bash
/track:help
# Displays comprehensive hooks-based tracking documentation
# Commands, file formats, verbosity settings, and workflow examples
```

# help - Hooks-Based Tracking System Help

Comprehensive help for the Track Plugin v2.1 hooks-based automatic tracking system with LLM-enhanced summaries.

## Overview

The Track Plugin v2.1 uses Claude Code hooks for **fully automatic** reference and prompt tracking with **natural language summaries** for academic work and project documentation.

**Two tracking files:**
- `claude_usage/sources.md` - Research sources (WebSearch, WebFetch, documentation)
- `claude_usage/prompts.md` - Major prompts and outcomes with rich context

**Key features:**
- **Real-time tracking via Stop hook** - tracks after each Claude response
- **LLM-enhanced summaries** - natural language documentation using Claude Haiku
- **Multi-line rich format** - no truncation, structured metadata
- **No skill activation needed** - hooks run automatically
- **Per-project activation** - only tracks when enabled
- **Configurable verbosity** - control what gets tracked (with LLM classification)
- **Export support** - generate bibliographies and methodology sections
- **Attribution system** - tracks [User] vs [Claude] initiated sources

## v2.1 Architecture (NEW)

**Real-time hooks-based tracking**:
- **Stop hook** → Fires after each complete Claude response (real-time!)
  - Extracts latest interaction from transcript
  - Calls Claude Haiku for natural language summaries
  - Writes to both sources.md and prompts.md in one pass
  - Runs asynchronously (non-blocking)
- **LLM classification** → Determines MAJOR vs MINOR work automatically
- **Multi-line format** → Rich summaries with Files: metadata

**Fully automatic** - no manual intervention:
- Hooks check `TRACKING_ENABLED` in `.claude/.ref-config`
- If `true`, hooks track automatically after each turn
- No skill activation needed (unlike v1.x)
- No data loss if session crashes (real-time writes)

**v2.1 Improvements over v2.0:**
- ✅ Real-time tracking (not batch at session end)
- ✅ LLM-powered significance classification (not word count)
- ✅ Multi-line summaries (not 200-char truncation)
- ✅ File tracking in metadata
- ✅ Single hook for both sources and prompts
- ✅ Async execution (non-blocking)

## Commands (Skills)

### `/track:init` - Initialize tracking
Set up hooks-based tracking files and configuration for the current project.

Creates:
- `claude_usage/sources.md` (with preamble)
- `claude_usage/prompts.md` (with preamble)
- `.claude/.ref-config` (tracking state and verbosity settings)

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

**Format (v2.1):** Multi-line entries with structured metadata

**Pattern:**
```
Prompt: "user request"
Outcome: first line overview
additional context and details
decisions made and rationale
Files: file1.py, file2.js
Session: timestamp

```

**Example:**
```markdown
# Development Prompts and Outcomes

This file automatically tracks significant development work with LLM-enhanced summaries.

---

Prompt: "Implement user authentication with JWT"
Outcome: Created auth middleware, login/logout endpoints, JWT token generation and verification.
Integrated with database user model using bcrypt for password hashing.
Implemented refresh token rotation for enhanced security.
Added comprehensive error handling for token expiration cases.
Files: auth/middleware.py, routes/auth.py, models/user.py, utils/jwt.py
Session: 2026-01-27 14:23:15

Prompt: "Debug slow database queries"
Outcome: Added query logging and profiling to identify performance bottlenecks.
Discovered N+1 query problem in user posts endpoint causing 2.3s load times.
Implemented eager loading with proper join strategies.
Reduced query time from 2.3s to 0.15s (93% improvement).
Files: routes/posts.py, models/post.py
Session: 2026-01-27 15:42:08

```

**Key features (v2.1):**
- **Multi-line summaries** - Natural language, no truncation
- **Files metadata** - Tracks modified files automatically
- **LLM-generated** - Claude Haiku summarizes work naturally
- **Rich context** - Explains decisions and outcomes in detail

**Preamble:** Explains format, usage, and configuration

---

## Verbosity Settings

Located in `./.claude/.ref-config`:

### PROMPTS_VERBOSITY

- **`major`** (default) - Significant multi-step academic/development work
  - **v2.1:** LLM classifies work as MAJOR or MINOR automatically
  - Tracks: Feature implementation, bug fixes, architectural decisions, multi-file changes
  - Best for project documentation
- **`all`** - Every user request
  - Tracks everything including simple questions and clarifications
  - Best for complete session logs
- **`minimal`** - Only explicit user requests to track
  - Only tracks when user says "track this" or "log this"
  - Best for selective curation
- **`off`** - Disable prompt tracking

**v2.1 Classification:** Claude Haiku determines MAJOR vs MINOR based on:
- Concrete implementation work (MAJOR)
- Multi-step problem solving (MAJOR)
- Modified multiple files (MAJOR)
- Architectural decisions (MAJOR)
- Simple questions/lookups (MINOR)

### SOURCES_VERBOSITY

- **`all`** (default) - Track all WebSearch/WebFetch/Read/Grep operations
  - Best for complete research audit trail
- **`off`** - Disable source tracking

### EXPORT_PATH

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
- Configuration: `./.claude/.ref-config` (includes `TRACKING_ENABLED`)
- Temporary storage: `./.claude/.track-tmp/` (automatic cleanup)

## Debugging (v2.1)

**Verify hook is firing:**
- Stop hook outputs debug systemMessage on **next turn** (async)
- Look for: `[Track v2.1 Debug] Hook fired | ...`
- Shows: prompts tracked, sources, verbosity, LLM status

**Check for LLM errors:**
```bash
cat /tmp/track-llm-error.log
```

**Test with debug mode:**
```bash
claude --debug   # Shows hook execution details
```

**Important:** Async hooks deliver systemMessage on the **next conversation turn**. Don't close session immediately after work - send another message to see debug output!

See `plugins/track/TESTING.md` for comprehensive debugging guide.

## Common Issues

**"No tracking files found"**
→ Run `/track:init` first

**"Hook not firing / No entries captured"**
→ Check `/tmp/track-llm-error.log` for LLM failures
→ Verify Claude CLI authenticated: `claude --model haiku "test"`
→ Keep session alive for next turn (async output delay)
→ Don't interrupt responses with Ctrl+C

**"Too verbose"**
→ Use `/track:config prompts=minimal`
→ LLM classifies work - 'major' only tracks significant work

**"Want to pause tracking"**
→ Use `/track:auto off`

**"Need to export for paper"**
→ Use `/track:export bibliography`

**"LLM call failing"**
→ Check Claude CLI: `which claude`
→ Test authentication: `claude --model haiku "summarize this"`
→ Check system prompt files exist: `ls plugins/track/hooks/prompts/`

**"Where are my old files?"**
→ v2.0+ uses `claude_usage/` directory instead of root-level files
→ Run `/track:init` to migrate from `CLAUDE_*.md` files

## Version History

### v2.1 Changes from v2.0

**Major improvements:**
- **Real-time tracking** - Stop hook fires after each response (not batch at session end)
- **LLM-enhanced summaries** - Claude Haiku generates natural language documentation
- **Multi-line format** - Rich context without 200-char truncation
- **File tracking** - Metadata shows which files were modified
- **Intelligent classification** - LLM determines MAJOR vs MINOR (not word count)
- **Single hook** - Stop hook handles both sources and prompts
- **Async execution** - Non-blocking, runs in background
- **Better debugging** - systemMessage output and error logging

**Technical changes:**
- Replaced SessionEnd + UserPromptSubmit with single Stop hook
- Added LLM summarization functions in `hooks/common/llm.sh`
- System prompts in `hooks/prompts/` directory
- Preamble templates in `hooks/templates/` directory
- Error logging to `/tmp/track-llm-error.log`

**Migration from v2.0:**
- Existing tracked files work unchanged (backward compatible)
- Export tools handle both v2.0 and v2.1 formats
- No action needed - Stop hook auto-activates on next `/track:init`

### v2.0 Changes from v1.x

**Major changes:**
- **Hooks-based architecture** - Fully automatic, no skill activation
- **New directory:** `claude_usage/` instead of root-level files
- **File preambles:** Explanatory headers in tracked files
- **Export support:** `/track:export` command for output generation
- **Enhanced config:** EXPORT_PATH setting added
- **Deprecated:** `ref-tracker` skill, `/track:update` command

**Migration from v1.x:**
- Existing `.ref-autotrack` and `.ref-config` work unchanged
- Run `/track:init` to migrate old `CLAUDE_*.md` files
- Remove manual `/track:update` calls (automatic now)

## Related

- **Plugin hooks** - Stop hook (v2.1), PostToolUse (archived)
- **Global CLAUDE.md** - Documents the system in detail
- **Project CLAUDE.md** - Can contain project-specific notes
- **TESTING.md** - Comprehensive debugging guide (v2.1)

---

For more help, consult plugin README, TESTING.md for debugging, or CHANGELOG.md for version details.
