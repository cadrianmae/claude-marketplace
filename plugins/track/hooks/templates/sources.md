# Research Sources

This file automatically tracks tool calls discovered during development.

**Purpose:** Track what files were read, searches performed, and content accessed.

**Format:** ASCII compact format with timestamps:
```
[HH:MM:SS] ToolName(params) -> summary
  |> optional details
```

**Examples:**
- `[14:23:15] Read(auth.py:42-108) -> 66 lines`
- `[14:23:16] Grep(*.js, "API_KEY") -> 3 matches`
- `[14:23:17] WebFetch(docs.python.org) -> 12KB`
- `[14:23:18] WebSearch("rust async await") -> 8 results`

**Usage:**
- View recent activity: `tail claude_usage/sources.md`
- Search for file: `grep "filename" claude_usage/sources.md`
- Count tool calls: `grep -c "^\[" claude_usage/sources.md`

**Configuration:** `.claude/.ref-config` (SOURCES_VERBOSITY setting)

---

