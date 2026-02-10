[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Track Plugin v2.1

Automatic reference and prompt tracking via Claude Code hooks for academic work and project documentation.

## Overview

Track Plugin v2.1 uses **hooks-based architecture** with **LLM-enhanced summaries** for fully automatic tracking of research sources and development work. Real-time tracking with natural language documentation.

**Two tracking files:**
- `claude_usage/sources.md` - Research sources (WebSearch, WebFetch, documentation)
- `claude_usage/prompts.md` - Major prompts and outcomes

**Key features:**
- **Real-time tracking** via Stop hook (after each Claude response)
- **LLM-enhanced summaries** using Claude Haiku for natural language documentation
- **Multi-line rich context** with structured metadata (Files, Links, Significance)
- **Intelligent classification** - LLM determines MAJOR vs MINOR work
- **Export support** - bibliography, methodology, BibTeX, timeline
- **Graceful fallback** - works even if Claude CLI unavailable
- **Backward compatible** - reads both v2.0 and v2.1 formats
- **Attribution system** - [User] vs [Claude] initiated sources

## v2.1 Architecture

### Real-Time Hooks-Based Tracking

**PostToolUse hook** → Automatic source tracking
- Triggers after WebSearch, WebFetch, Read, Grep
- Appends to `claude_usage/sources.md`
- Filters documentation reads (docs/, README, man/)

**Stop hook** → Real-time LLM-enhanced tracking (v2.1+)
- Fires after each complete Claude response (once per turn)
- Extracts latest user prompt and assistant response from transcript
- Uses Claude Haiku to generate natural language summaries
- Writes multi-line entries to both `prompts.md` and `sources.md`
- Async execution (doesn't block workflow)
- Critical loop prevention via `stop_hook_active` flag
- Falls back to v2.0 format if Claude CLI unavailable

**No skill activation needed** - hooks run automatically when `.claude/.ref-autotrack` exists.

### LLM-Enhanced Documentation (v2.1+)

Stop hook uses Claude Haiku for intelligent summarization:

**For prompts:**
- Natural language outcome descriptions (no truncation)
- Lists modified files automatically
- Classifies MAJOR vs MINOR based on substance, not length
- Multi-line format with structured metadata

**For tool calls:**
- Explains what prompted the tool (User request or Claude initiative)
- Summarizes what was accessed and how it was used
- Extracts URLs from WebSearch/WebFetch automatically
- Attributes as [USER] or [CLAUDE] based on context

**Cost:** ~$0.0002 per Claude turn (2 Haiku calls @ ~$0.0001 each)

## Skills

All functionality is provided via user-invocable skills:

- **`/track:init`** - Initialize hooks-based tracking (run first)
- **`/track:auto [on|off]`** - Toggle hooks on/off
- **`/track:config [key=value]`** - Configure verbosity and export settings
- **`/track:export <format> [output]`** - Export tracked data
- **`/track:help`** - Comprehensive documentation

**Deprecated in v2.0:**
- `/track:update` - No longer needed (real-time tracking via hooks)

## Quick Start

```bash
# 1. Initialize tracking
/track:init
# Creates claude_usage/ directory with preambles
# Enables hooks automatically

# 2. Work normally - hooks track everything
# - Search for docs → logged to claude_usage/sources.md
# - Implement features → logged to claude_usage/prompts.md

# 3. Export for paper
/track:export bibliography          # → exports/bibliography.md
/track:export methodology           # → exports/methodology.md
/track:export bibtex refs.bib       # → refs.bib

# 4. Adjust verbosity if needed
/track:config prompts=all           # Track everything
/track:config prompts=minimal       # Track less

# 5. Toggle tracking as needed
/track:auto off                     # Pause hooks
/track:auto on                      # Resume hooks
```

## File Structure

After `/track:init`:

```
.claude/
├── .ref-autotrack          # Marker: hooks enabled (with metadata)
├── .ref-config             # Verbosity and export settings
└── .track-tmp/             # Temporary prompt storage (auto-cleanup)
claude_usage/
├── sources.md              # Research sources (with preamble)
└── prompts.md              # Major prompts (with preamble)
exports/                    # Export output directory (default)
```

## Verbosity Configuration

Located in `./.claude/.ref-config`:

### PROMPTS_VERBOSITY

- **`major`** (default) - Significant multi-step work (LLM-classified as MAJOR)
- **`all`** - Every user request
- **`minimal`** - Only when user says "track this"
- **`off`** - Disable prompt tracking

**v2.1 Classification:** LLM determines MAJOR vs MINOR based on:
- **MAJOR:** Implemented features, bug fixes, multi-step problem solving, multi-file changes, architectural decisions
- **MINOR:** Simple questions, single file reads, documentation lookups, basic validation

### SOURCES_VERBOSITY

- **`all`** (default) - All WebSearch/WebFetch/Read/Grep operations
- **`off`** - Disable source tracking

### EXPORT_PATH (new in v2.0)

- **`exports/`** (default) - Default export directory
- Can be absolute or relative path
- Used by `/track:export` when no output specified

**Configure interactively:**
```bash
/track:config
# Uses AskUserQuestion for easy setup
```

**Configure directly:**
```bash
/track:config prompts=all sources=off
/track:config export_path=paper/references/
```

## File Formats

### claude_usage/sources.md

Multi-line format with structured metadata (v2.1+):

```markdown
# Research Sources

This file automatically tracks research sources discovered during development.

[Preamble explaining format, usage, configuration...]

---

[USER] WebSearch({"query":"PostgreSQL JSONB tutorial"})
Summary: User requested search for PostgreSQL JSONB documentation.
Found official PostgreSQL documentation explaining JSONB data type usage and indexing strategies.
Used to understand best practices for storing flexible data structures.
Links: https://postgresql.org/docs/current/datatype-json.html

[CLAUDE] WebFetch({"url":"https://go.dev/doc/"})
Summary: Autonomously fetched Go documentation to understand embed.FS usage for static file embedding.
Retrieved information about embedding files at compile time for self-contained binaries.
Applied to project static asset handling.
Links: https://go.dev/doc/
```

**Attribution:**
- `[USER]` - User explicitly requested search/fetch
- `[CLAUDE]` - Claude autonomously decided to look something up

**Backward compatibility:** Export tools read both v2.0 (single-line) and v2.1 (multi-line) formats.

### claude_usage/prompts.md

Multi-line format with structured metadata (v2.1+):

```markdown
# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

[Preamble explaining format, usage, configuration...]

---

Prompt: "Implement JWT authentication"
Outcome: Created auth middleware package with token generation and verification functions.
Implemented login and logout endpoints with secure cookie handling.
Added JWT secret configuration and expiration time settings.
Tested authentication flow with user registration and protected routes.
Files: auth/middleware.go, auth/jwt.go, api/handlers.go
Session: 2026-01-27 14:23:15

Prompt: "Debug slow database queries"
Outcome: Added query logging middleware to identify slow queries.
Discovered N+1 query problem in user relationship loading.
Implemented eager loading with preload directives.
Query time reduced from 2.3s to 150ms average.
Files: db/queries.go, models/user.go
Session: 2026-01-27 15:42:08

```

**Multi-line outcomes** provide complete context without truncation. **Files field** lists modified files. **Session timestamps** correlate work with development sessions.

**Backward compatibility:** Export tools read both v2.0 (single-line truncated) and v2.1 (multi-line) formats.

## Export Functionality

Generate outputs for academic papers and reports:

### Bibliography
```bash
/track:export bibliography
# → exports/bibliography.md
```
Numbered list with links for works cited section.

### Methodology
```bash
/track:export methodology
# → exports/methodology.md
```
Structured methodology section from prompts and outcomes.

### BibTeX
```bash
/track:export bibtex references.bib
# → references.bib
```
BibTeX entries for LaTeX papers.

### Citations
```bash
/track:export citations
# → exports/citations.md
```
Numbered citation list for references.

### Timeline
```bash
/track:export timeline
# → exports/timeline.md
```
Chronological timeline of all tracked activity.

**Custom output paths:**
```bash
/track:export bibliography -                    # Print to stdout
/track:export methodology paper/methodology.md  # Custom path
```

## Academic Workflow Example

**1. Setup project:**
```bash
cd ~/research/thesis-project
/track:init
```

**2. Research and develop:**
- Search for papers → automatically logged to `claude_usage/sources.md`
- Implement features → major work logged to `claude_usage/prompts.md`
- Ask questions → research logged with attribution
- **All automatic** - no manual tracking needed

**3. Export for paper:**
```bash
/track:export bibliography paper/bibliography.md
/track:export methodology paper/methodology.md
/track:export bibtex paper/references.bib
```

**4. Review and refine:**
- Open exported files
- Edit as needed for paper
- Clear audit trail maintained

**5. Adjust verbosity:**
```bash
/track:config prompts=minimal    # Less verbose
/track:auto off                  # Pause during cleanup
```

## Use Cases

**Research papers:**
- Track all sources for bibliography ✓
- Document methodology automatically ✓
- Export BibTeX for LaTeX ✓
- Clear citation trail ✓

**Development projects:**
- Track all searches for reference ✓
- Document major decisions automatically ✓
- Export timeline for retrospectives ✓
- Audit trail for progress reports ✓

**Learning/study:**
- Track resources discovered ✓
- Document problem-solving process ✓
- Export timeline to review learning path ✓

## Hooks Integration

The hooks run automatically when tracking is enabled:

**PostToolUse** (hooks/post-tool-use.sh):
- Checks `.claude/.ref-autotrack` exists
- Reads `SOURCES_VERBOSITY` from `.claude/.ref-config`
- Tracks WebSearch/WebFetch/Read/Grep to `claude_usage/sources.md`

**Stop** (hooks/stop.sh) **[v2.1+]**:
- Checks `.claude/.ref-autotrack` exists
- Fires once per Claude turn (after complete response)
- Checks `stop_hook_active` flag (prevents infinite loops)
- Extracts latest user prompt and assistant response from transcript
- Uses Claude Haiku for LLM summarization
- Writes multi-line entries to both `prompts.md` and `sources.md`
- Async execution with 30-second timeout
- Falls back to v2.0 format if Claude CLI unavailable

**All hooks** respect per-project activation and verbosity settings.

## What's New in v2.1

**Real-time Stop hook** replaces SessionEnd batch processing:
- ✓ No data loss if session crashes (tracks after each response)
- ✓ See documentation build as you work
- ✓ Richer context with full interaction visibility

**LLM-enhanced summaries** using Claude Haiku:
- ✓ Natural language documentation (not truncated verbatim quotes)
- ✓ Intelligent MAJOR/MINOR classification
- ✓ Automatic file tracking
- ✓ Context-aware attribution (USER vs CLAUDE)

**Multi-line format** with structured fields:
- ✓ Complete outcomes without truncation
- ✓ Separate Files, Links, Summary fields
- ✓ Natural paragraph flow

**Backward compatible:**
- ✓ Export tools read both v2.0 and v2.1 formats
- ✓ Graceful fallback if Claude CLI unavailable
- ✓ No configuration changes required

## Migration from v1.x

See [MIGRATION.md](./MIGRATION.md) for detailed migration guide.

**Quick migration:**
1. Update plugin to v2.0.0
2. Run `/track:init` (auto-detects old files)
3. Manually migrate content:
   ```bash
   cat CLAUDE_SOURCES.md >> claude_usage/sources.md
   cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md
   ```
4. Remove old files (optional):
   ```bash
   rm CLAUDE_SOURCES.md CLAUDE_PROMPTS.md
   ```
5. Remove `/track:update` from workflows

**Breaking changes:**
- File locations changed (root → `claude_usage/`)
- Tracking mechanism changed (skill → hooks)
- `/track:update` deprecated (automatic now)
- Default behavior changed (tracking enabled by default)

## Tips

**For academic work:**
- Keep `prompts=major` and `sources=all`
- Export bibliography for citations
- Export methodology for papers
- Use BibTeX export for LaTeX

**For development:**
- Use `prompts=all` for complete audit
- Export timeline for retrospectives
- Track decisions for documentation

**For efficiency:**
- Toggle `/track:auto off` during exploration
- Use interactive `/track:config` for setup
- Export to stdout with `-` for quick review

## Troubleshooting

**Tracking not working:**
```bash
# Check if enabled
ls -la .claude/.ref-autotrack

# Re-enable if needed
/track:auto on
```

**Files not created:**
```bash
# Run init again
/track:init
```

**Old files still present:**
```bash
# Migrate manually
cat CLAUDE_SOURCES.md >> claude_usage/sources.md
cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md
rm CLAUDE_*.md
```

**Export not working:**
```bash
# Check version
cat .claude-plugin/plugin.json | grep version
# Should show "2.0.0"
```

## Development

**Plugin structure:**
```
track/
├── hooks/
│   ├── hooks.json              # Hook configuration
│   ├── common.sh               # Shared utilities
│   ├── post-tool-use.sh        # Source tracking
│   ├── user-prompt-submit.sh   # Prompt capture
│   └── session-end.sh          # Prompt-outcome pairing
├── skills/
│   ├── init/SKILL.md
│   ├── auto/SKILL.md
│   ├── config/SKILL.md
│   ├── export/SKILL.md
│   ├── help/SKILL.md
│   ├── update/SKILL.md         # Deprecated
│   └── ref-tracker/SKILL.md    # Deprecated
├── commands/                   # Deprecated (use skills/)
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── CHANGELOG.md
├── MIGRATION.md
└── LICENSE
```

## License

MIT License - Copyright (c) Mae Capacite

## See Also

- [CHANGELOG.md](./CHANGELOG.md) - Version history and changes
- [MIGRATION.md](./MIGRATION.md) - v1.x → v2.0 migration guide
- `/track:help` - Comprehensive in-app documentation
