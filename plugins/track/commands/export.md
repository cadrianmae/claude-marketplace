---
description: This skill should be used when the user asks to export tracked data, generate bibliography, create methodology section, export to BibTeX, generate citations, create timeline, or produce formatted output from tracked sources and prompts. Supports formats: bibliography (Markdown numbered list), methodology (Markdown sections), bibtex (BibTeX entries), citations (numbered citations), and timeline (chronological activity log). Exports to configurable path from .claude/.ref-config.
argument-hint: <format> [output]
allowed-tools: Read, Write, Bash
disable-model-invocation: true
---

## Export Status (Auto-Captured)

**Sources Available**: !`wc -l < claude_usage/sources.md 2>/dev/null || echo "0"`
**Prompts Available**: !`grep -c '^Prompt:' claude_usage/prompts.md 2>/dev/null || echo "0"`
**Export Path**: !`grep EXPORT_PATH .claude/.ref-config 2>/dev/null | cut -d= -f2 || echo "exports/"`
**Last Export**: !`[ -d exports ] && ls -lt exports/ | head -2 | tail -1 | awk '{print $9, "("$6, $7, $8")"}' || echo "No exports yet"`

## Quick Example

```bash
/track:export bibliography                    # → exports/bibliography.md
/track:export bibliography -                  # Print to stdout
/track:export bibliography paper/refs.md      # → paper/refs.md
/track:export methodology                     # → exports/methodology.md
/track:export bibtex references.bib           # → references.bib
/track:export timeline                        # → exports/timeline.md
```

# export - Export Tracked Data

Generate bibliographies, methodology sections, or other export formats from tracked data.

## Usage

```bash
/track:export <format> [output]
```

**Arguments:**
- `<format>` - Required export format (see below)
- `[output]` - Optional output file path
  - If omitted, uses `$EXPORT_PATH/<format>.<ext>`
  - Use `-` to print to stdout
  - Relative paths are relative to project root
  - Absolute paths used as-is

## Export Formats

### bibliography
Generate Markdown bibliography/works cited from sources.

**Output:** Numbered list with links
```markdown
# Bibliography

1. PostgreSQL Documentation: INSERT INTO SELECT
   https://www.postgresql.org/docs/current/sql-insert.html

2. Go Documentation: embed.FS usage
   https://go.dev/doc/
   *Fetched: Use embed.FS to embed static files at compile time*

3. API Documentation (docs/api.md)
   *Documentation reference*
```

**Default output:** `exports/bibliography.md`

---

### methodology
Generate methodology section from prompts and outcomes.

**Output:** Markdown sections with prompts/outcomes
```markdown
# Methodology

## Development Process

### User Authentication Implementation
**Prompt:** "Implement user authentication with JWT"

**Outcome:** Created auth middleware, login/logout endpoints, JWT token generation and verification, integrated with database user model

**Session:** 2026-01-27 14:23:15

---

### Performance Optimization
**Prompt:** "Debug slow database queries"

**Outcome:** Added query logging, identified N+1 problem in user posts endpoint, implemented eager loading, reduced query time from 2.3s to 0.15s

**Session:** 2026-01-27 15:42:08
```

**Default output:** `exports/methodology.md`

---

### bibtex
Export sources as BibTeX entries for LaTeX papers.

**Output:** BibTeX format
```bibtex
@online{postgresql_insert_select,
  title = {PostgreSQL Documentation: INSERT INTO SELECT},
  url = {https://www.postgresql.org/docs/current/sql-insert.html},
  urldate = {2026-01-27}
}

@online{go_embed_fs,
  title = {Go Documentation: embed.FS usage},
  url = {https://go.dev/doc/},
  note = {Use embed.FS to embed static files at compile time},
  urldate = {2026-01-27}
}
```

**Default output:** `exports/bibliography.bib`

---

### citations
Export sources as numbered citations for reference.

**Output:** Numbered citation list
```markdown
# Citations

[1] PostgreSQL Documentation: INSERT INTO SELECT
    https://www.postgresql.org/docs/current/sql-insert.html

[2] Go Documentation: embed.FS usage
    https://go.dev/doc/
    Note: Use embed.FS to embed static files at compile time

[3] API Documentation (docs/api.md)
```

**Default output:** `exports/citations.md`

---

### timeline
Chronological timeline of all tracked activity (sources and prompts interleaved).

**Output:** Markdown timeline
```markdown
# Development Timeline

## 2026-01-27

### 14:15 - Research Activity
[Claude] WebSearch("PostgreSQL INSERT INTO SELECT documentation"): https://postgresql.org/docs/current/sql-insert.html

### 14:23 - Development Work
**Prompt:** "Implement user authentication with JWT"
**Outcome:** Created auth middleware, login/logout endpoints, JWT token generation and verification

### 15:30 - Research Activity
[User] WebFetch("https://go.dev/doc/", "embed.FS usage"): Use embed.FS to embed static files at compile time

### 15:42 - Development Work
**Prompt:** "Debug slow database queries"
**Outcome:** Added query logging, identified N+1 problem
```

**Default output:** `exports/timeline.md`

---

## Path Resolution

**No `[output]` argument:**
- Uses `$EXPORT_PATH/<format>.<ext>` from `.claude/.ref-config`
- Default: `exports/bibliography.md`, `exports/methodology.md`, etc.

**Relative path:**
- Relative to project root
- Example: `paper/refs.md` → `./paper/refs.md`

**Absolute path:**
- Used as-is
- Example: `/tmp/tracking/bibliography.md`

**Stdout (`-`):**
- Prints to stdout instead of file
- Useful for piping or inspection

## Prerequisites

- Run `/track:init` first to create tracking files
- At least one tracked entry (sources or prompts)

## Output

Shows export summary:
- Format used
- Number of entries exported
- Output file path
- Preview of first few lines

## Implementation

Export functionality is implemented in `scripts/export.sh`:

```bash
# Get skill directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute export script with arguments
bash "$SKILL_DIR/scripts/export.sh" "$@"
```

**Script:** `skills/export/scripts/export.sh` (204 lines)

**Features:**
- Format validation and error messages
- Path resolution (default, relative, absolute, stdout)
- File existence checking
- Multiple export formats with format-specific processing
- Entry counting and summary output
- Preview generation

See `scripts/export.sh` for full implementation details.

## Notes

- Exports respect tracked data verbosity
- Source preambles are filtered out automatically
- BibTeX keys are auto-generated (ref_1, ref_2, etc.)
- Timeline format simplified (line order, not true chronological)
- Export files can be committed to git or added to .gitignore
