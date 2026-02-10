# Research Sources

This file automatically tracks research sources discovered during development.

**Purpose:** Generate bibliographies, works cited, and maintain citation trail for academic work.

**Format:** Each line is a key-value entry:
```
[Attribution] Tool("Query"): Result
```

**Attribution:**
- `[User]` - Explicitly requested by user
- `[Claude]` - Autonomously discovered by Claude

**Tools tracked:** WebSearch, WebFetch, Read (documentation), Grep (documentation)

**Usage:**
- Export for academic papers: `/track:export bibliography`
- View recent sources: `tail claude_usage/sources.md`
- Search specific topic: `grep "topic" claude_usage/sources.md`

**Configuration:** `.claude/.ref-config` (SOURCES_VERBOSITY setting)

---

