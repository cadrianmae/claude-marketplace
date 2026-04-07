# Research Sources

This file automatically tracks tool calls discovered during development.

**Purpose:** Track what files were read, searches performed, and content accessed.

**Format:** ASCII compact format with ISO-8601 timestamps (minute precision):
```
[YYYY-MM-DDTHH:MM±HH:MM] ToolName(params) -> summary
  |> optional details
```

**Examples:**
- `[2026-04-07T14:23+01:00] Read(auth.py:42-108) -> 66 lines`
- `[2026-04-07T14:23+01:00] Grep(*.js, "API_KEY") -> 3 matches`
- `[2026-04-07T14:23+01:00] WebFetch(docs.python.org) -> Summary`
- `[2026-04-07T14:23+01:00] WebSearch("rust async await") -> 8 results`

**Usage:**
- View recent activity: `tail claude_usage/sources.md`
- Search for file: `grep "filename" claude_usage/sources.md`
- Count tool calls: `grep -c "^\[" claude_usage/sources.md`

**Configuration:** `.claude/.ref-config` (SOURCES_VERBOSITY setting)

---

