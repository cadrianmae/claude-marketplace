# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

**Purpose:** Document methodology, implementation decisions, and project evolution for reports and retrospectives.

**Format:** Two-line entries with blank separator:
```
Prompt: "user request"
Outcome: what was accomplished
```

**Verbosity:** Controlled by PROMPTS_VERBOSITY setting
- `major` (default) - Significant multi-step work only
- `all` - Every user interaction
- `minimal` - Only when explicitly requested

**Usage:**
- Export for methodology section: `/track:export methodology`
- Review recent work: `tail claude_usage/prompts.md`
- Find specific feature: `grep "authentication" claude_usage/prompts.md`

**Configuration:** `.claude/.ref-config` (PROMPTS_VERBOSITY setting)

---

