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

[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/hooks/templates/sources.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/CHANGELOG.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/export/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/export/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/export/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/CHANGELOG.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/hooks/templates/sources.md"): Documentation reference

# Test entries for export verification (v2.4.0)

[Claude] WebFetch("https://example.com", "test prompt"): Retrieved test content for verification
[Claude] Grep("test.js", pattern="function.*test"): Found test function definitions
[Claude] Read("/home/cadrianmae/.claude/plans/moonlit-brewing-clover.md"): Documentation reference
[Claude] WebFetch("https://code.claude.com/docs/en/claude_code_docs_map.md"): Fetched content
[Claude] WebFetch("https://code.claude.com/docs/en/hooks.md"): Fetched content
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/hooks/templates/sources.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/CHANGELOG.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/init/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/auto/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/config/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/.claude/plans/moonlit-brewing-clover.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/CHANGELOG.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/auto/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/init/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/config/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/help/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/ref-tracker/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/MIGRATION.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/TESTING.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/migrate/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/README.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/CHANGELOG.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/init/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/auto/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/export/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/config/SKILL.md"): Documentation reference
[Claude] Read("/home/cadrianmae/git/github.com/cadrianmae/claude-marketplace/plugins/track/skills/help/SKILL.md"): Documentation reference
[13:28:26] Read(capture-prompt.sh:44-59) -> 10 lines
[13:29:54] Read(capture-prompt.sh:63-83) -> 10 lines
[13:33:54] Read(capture-prompt.sh:75-85) -> 10 lines
[13:35:12] Read(prompts.md) -> 10 lines
[13:38:02] Read(plugin.json) -> 10 lines
[13:38:03] Read(marketplace.json:40-55) -> 10 lines
[13:38:10] Read(CHANGELOG.md) -> 10 lines
