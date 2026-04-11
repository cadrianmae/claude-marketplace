# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

**Purpose:** Document methodology, implementation decisions, and project evolution for reports and retrospectives.

**Format:** Multi-line structured entries with blank separator. The Stop hook
writes `Prompt:` and `Outcome:` always, plus `Files:` (when files were modified)
and `Session:` (timestamp). `Outcome:` may span multiple lines.
```
Prompt: "user request"
Outcome: what was accomplished (may be multi-line)
Files: file1.py, file2.md         (optional, omitted if none)
Session: 2026-04-07T14:23+01:00   (timestamp from get_timestamp)
```

**Verbosity:** Controlled by PROMPTS_VERBOSITY setting
- `major` (default) - Significant multi-step work only
- `all` - Every user interaction
- `minimal` - Only when explicitly requested

**Usage:**
- Export for methodology section: `/track export methodology`
- Review recent work: `tail claude_usage/prompts.md`
- Find specific feature: `grep "authentication" claude_usage/prompts.md`

**Configuration:** `.claude/.ref-config` (PROMPTS_VERBOSITY setting)

---

