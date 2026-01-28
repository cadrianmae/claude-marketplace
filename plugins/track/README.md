[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Track Plugin v2.0

Automatic reference and prompt tracking via Claude Code hooks for academic work and project documentation.

## Overview

Track Plugin v2.0 uses **hooks-based architecture** for fully automatic tracking of research sources and development work. No skill activation required - hooks capture everything in real-time.

**Two tracking files:**
- `claude_usage/sources.md` - Research sources (WebSearch, WebFetch, documentation)
- `claude_usage/prompts.md` - Major prompts and outcomes

**Key features:**
- **Fully automatic** via PostToolUse, UserPromptSubmit, SessionEnd hooks
- **Real-time capture** - no manual tracking needed
- **Export support** - bibliography, methodology, BibTeX, timeline
- **Configurable verbosity** for academic vs development needs
- **Per-project activation** - enable only where needed
- **Attribution system** - [User] vs [Claude] initiated sources

## v2.0 Architecture

### Hooks-Based Tracking

**PostToolUse hook** → Automatic source tracking
- Triggers after WebSearch, WebFetch, Read, Grep
- Appends to `claude_usage/sources.md`
- Filters documentation reads (docs/, README, man/)

**UserPromptSubmit hook** → Prompt capture
- Captures user messages to temporary storage
- Stores for later pairing with outcomes

**SessionEnd hook** → Prompt-outcome pairing
- Reads transcript for assistant responses
- Pairs prompts with outcomes
- Writes to `claude_usage/prompts.md` (based on verbosity)

**No skill activation needed** - hooks run automatically when `.claude/.ref-autotrack` exists.

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

- **`major`** (default) - Significant multi-step work (response >100 words)
- **`all`** - Every user request
- **`minimal`** - Only when user says "track this"
- **`off`** - Disable prompt tracking

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

Pure KV format with preamble:

```markdown
# Research Sources

This file automatically tracks research sources discovered during development.

[Preamble explaining format, usage, configuration...]

---

[User] WebSearch("PostgreSQL JSONB tutorial"): https://postgresql.org/docs/current/datatype-json.html
[Claude] WebFetch("https://go.dev/doc/", "embed.FS usage"): Use embed.FS to embed static files at compile time
[Claude] Read("docs/api.md"): Documentation reference
[Claude] Grep("middleware", pattern="CORS"): Documentation reference
```

**Attribution:**
- `[User]` - User explicitly requested search
- `[Claude]` - Claude autonomously searched

### claude_usage/prompts.md

Three-line format with preamble:

```markdown
# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

[Preamble explaining format, usage, configuration...]

---

Prompt: "Implement JWT authentication"
Outcome: Created auth middleware, login/logout endpoints, JWT token generation and verification
Session: 2026-01-27 14:23:15

Prompt: "Debug slow database queries"
Outcome: Added query logging, identified N+1 problem, implemented eager loading, reduced query time
Session: 2026-01-27 15:42:08

```

**Session timestamps** help correlate work with specific development sessions.

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

**UserPromptSubmit** (hooks/user-prompt-submit.sh):
- Checks `.claude/.ref-autotrack` exists
- Stores prompt to `.claude/.track-tmp/`
- Timestamp for attribution logic

**SessionEnd** (hooks/session-end.sh):
- Checks `.claude/.ref-autotrack` exists
- Reads `PROMPTS_VERBOSITY` from `.claude/.ref-config`
- Pairs prompts with outcomes from transcript
- Writes to `claude_usage/prompts.md` if verbosity criteria met

**All hooks** respect per-project activation and verbosity settings.

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
