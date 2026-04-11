[![Version](https://img.shields.io/badge/version-2.7.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Track Plugin v2.7

Automatic reference and prompt tracking via Claude Code hooks for academic work and project documentation.

## Overview

Track Plugin v2.6 uses a **split hooks architecture** for fully automatic tracking of research sources and development work.

**Two tracking files:**
- `claude_usage/prompts.md` - Major prompts and outcomes (LLM-enhanced)
- `claude_usage/sources.md` - Tool calls in ASCII compact format

**Key features:**
- **Split hook architecture** - prompts (Stop hook) and sources (PostToolUse hook)
- **LLM-enhanced prompts** using Claude Haiku for outcome summaries
- **ASCII sources format** - compact `[YYYY-MM-DDTHH:MM±HH:MM] Tool(params) -> summary` entries (ISO-8601, minute precision)
- **Immediate source tracking** - tool calls written as they happen
- **Intelligent classification** - LLM determines MAJOR vs MINOR work
- **Export support** - bibliography, methodology, BibTeX, timeline
- **Mostly deterministic sources tracking** - pure bash for Read/Grep/WebSearch; only `WebFetch` invokes Claude Haiku to summarize fetched content

## Hooks Architecture

### capture-prompt.sh (Stop hook)

Tracks conversation outcomes to `prompts.md`:
- Fires after each complete Claude response (once per turn)
- Extracts latest user prompt and assistant response from transcript
- Uses Claude Haiku for natural language outcome summaries
- MAJOR/MINOR classification for verbosity filtering
- Smart summarization for long prompts (>500 chars)
- Async execution with 30s timeout
- Critical loop prevention via `stop_hook_active` flag

### capture-sources.sh (PostToolUse hook)

Tracks tool calls to `sources.md` in ASCII format:
- Fires immediately after each Read/Grep/WebFetch/WebSearch call
- Writes compact ASCII entries with per-tool timestamps
- Smart summaries without LLM calls (zero API cost)
- Tool-specific formatting with optional detail lines
- Async execution (doesn't block workflow)

**No skill activation needed** - hooks run automatically when `TRACKING_ENABLED=true` in `.claude/.ref-config`.

### Sources Format (v2.5)

```
[HH:MM:SS] ToolName(params) -> summary
  |> optional details
```

**Tool-specific examples:**
- `[14:23:15] Read(auth.py:42-108) -> 66 lines`
  `  |> authenticate, verify_token`
- `[14:23:16] Grep(*.js, "API_KEY") -> 3 matches`
  `  |> config.js:12, utils.js:45`
- `[14:23:17] WebFetch(docs.python.org/tutorial) -> 12KB`
  `  |> Introduction, Quickstart, API Reference`
- `[14:23:18] WebSearch("rust async await") -> 8 results`
  `  |> rust-lang.org/async, tokio.rs/tutorial`

**Cost:** ~$0.0001 per Claude turn (1 Haiku call for prompts only, zero for sources)

## Command

A single unified interactive command:

- `/track` — Interactive entry point for init / config / auto / export / help. Uses AskUserQuestion to walk through each workflow. Accepts arguments to skip prompts (e.g. `/track config prompts=all`, `/track export bibliography`).

See the subcommand grammar below for the full argument form.

## Quick Start

```bash
# 1. Initialize tracking
/track init
# Creates claude_usage/ directory with preambles and enables hooks

# 2. Work normally — hooks track everything
# - Search for docs     → logged to claude_usage/sources.md
# - Implement features  → logged to claude_usage/prompts.md

# 3. Export for paper
/track export bibliography          # → exports/bibliography.md
/track export methodology           # → exports/methodology.md
/track export bibtex refs.bib       # → refs.bib

# 4. Adjust verbosity if needed
/track config prompts=all           # Track everything
/track config prompts=minimal       # Track less

# 5. Toggle tracking as needed
/track auto off                     # Pause hooks
/track auto on                      # Resume hooks
```

## File Structure

After `/track init`:

```
.claude/
├── .ref-config             # Tracking state and verbosity settings
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
- Used by `/track export` when no output specified

**Configure interactively:**
```bash
/track config
# Uses AskUserQuestion for easy setup
```

**Configure directly:**
```bash
/track config prompts=all sources=off
/track config export_path=paper/references/
```

## File Formats

### claude_usage/sources.md

ASCII compact format with timestamps (v2.5+):

```markdown
# Research Sources

[Preamble explaining format...]

---

[14:23:15] Read(auth.py:42-108) -> 66 lines
  |> authenticate, verify_token
[14:23:16] Grep(*.js, "API_KEY") -> 3 matches
  |> config.js:12, utils.js:45, env.example:8
[14:23:17] WebFetch(docs.python.org/tutorial) -> 12KB
  |> Introduction, Quickstart, API Reference, Examples
[14:23:18] WebSearch("rust async await") -> 8 results
  |> rust-lang.org/async, tokio.rs/tutorial, stackoverflow.com/...
```

**Backward compatibility:** Export tools read v2.0, v2.1, and v2.5 formats.

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
/track export bibliography
# → exports/bibliography.md
```
Numbered list with links for works cited section.

### Methodology
```bash
/track export methodology
# → exports/methodology.md
```
Structured methodology section from prompts and outcomes.

### BibTeX
```bash
/track export bibtex references.bib
# → references.bib
```
BibTeX entries for LaTeX papers.

### Citations
```bash
/track export citations
# → exports/citations.md
```
Numbered citation list for references.

### Timeline
```bash
/track export timeline
# → exports/timeline.md
```
Chronological timeline of all tracked activity.

**Custom output paths:**
```bash
/track export bibliography -                    # Print to stdout
/track export methodology paper/methodology.md  # Custom path
```

## Academic Workflow Example

**1. Setup project:**
```bash
cd ~/research/thesis-project
/track init
```

**2. Research and develop:**
- Search for papers → automatically logged to `claude_usage/sources.md`
- Implement features → major work logged to `claude_usage/prompts.md`
- Ask questions → research logged with attribution
- **All automatic** - no manual tracking needed

**3. Export for paper:**
```bash
/track export bibliography paper/bibliography.md
/track export methodology paper/methodology.md
/track export bibtex paper/references.bib
```

**4. Review and refine:**
- Open exported files
- Edit as needed for paper
- Clear audit trail maintained

**5. Adjust verbosity:**
```bash
/track config prompts=minimal    # Less verbose
/track auto off                  # Pause during cleanup
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

**capture-prompt.sh** (Stop hook):
- Checks `TRACKING_ENABLED=true` in `.claude/.ref-config`
- Fires once per Claude turn (after complete response)
- Checks `stop_hook_active` flag (prevents infinite loops)
- Extracts latest user prompt and assistant response from transcript
- Uses Claude Haiku for LLM summarization
- Writes entries to `prompts.md`
- Async execution with 30-second timeout

**capture-sources.sh** (PostToolUse hook):
- Matcher: `Read|Grep|WebFetch|WebSearch`
- Fires immediately after each matched tool call
- Writes ASCII compact entries to `sources.md`
- Pure bash parsing (no LLM calls, zero API cost)
- Async execution

**All hooks** respect per-project activation and verbosity settings.

## What's New in v2.5

**Split hook architecture** for clean separation:
- Prompts tracking via Stop hook (conversation outcomes)
- Sources tracking via PostToolUse hook (tool calls)
- Each hook focused on one responsibility

**ASCII sources format** replacing LLM multi-line:
- `[HH:MM:SS] Tool(params) -> summary` compact format
- Per-tool timestamps (not per-turn)
- Zero LLM cost for sources tracking
- Immediate writes as tool calls happen

**Backward compatible:**
- Export tools read v2.0, v2.1, and v2.5 formats
- Existing entries preserved
- No configuration changes required

## Migration from v1.x

See [MIGRATION.md](./MIGRATION.md) for detailed migration guide.

**Quick migration:**
1. Update plugin to v2.0.0
2. Run `/track init` (auto-detects old files)
3. Manually migrate content:
   ```bash
   cat CLAUDE_SOURCES.md >> claude_usage/sources.md
   cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md
   ```
4. Remove old files (optional):
   ```bash
   rm CLAUDE_SOURCES.md CLAUDE_PROMPTS.md
   ```
5. Remove any `/track:update` calls from workflows (the `update` skill was removed in v2.7.0)

**Breaking changes:**
- File locations changed (root → `claude_usage/`)
- Tracking mechanism changed (skill → hooks)
- `update` skill removed (was deprecated in v2.0; fully removed in v2.7.0 — tracking is automatic now)
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
- Toggle `/track auto off` during exploration
- Use interactive `/track config` for setup
- Export to stdout with `-` for quick review

## Troubleshooting

**Tracking not working:**
```bash
# Check if enabled
grep TRACKING_ENABLED .claude/.ref-config

# Re-enable if needed
/track auto on
```

**Files not created:**
```bash
# Run init again
/track init
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
│   ├── common.sh               # Shared utilities loader
│   ├── common/                 # Utility modules
│   │   ├── config.sh           # Configuration helpers
│   │   ├── files.sh            # File management
│   │   ├── utils.sh            # General utilities
│   │   └── llm.sh              # LLM summarization
│   ├── capture-prompt.sh       # Stop hook (prompts.md)
│   ├── capture-sources.sh      # PostToolUse hook (sources.md)
│   └── templates/              # File preamble templates
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
- `/track help` - Comprehensive in-app documentation
