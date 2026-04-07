# Future Enhancements

Ideas and planned features for future marketplace releases.

## Track Plugin v2.0 - Session Restart Issue

**Priority**: Medium
**Phase**: Post-2.0.0 release
**Status**: Known Issue

### Problem

Plugin skills only become available in sessions started **after** plugin installation/update. Sessions already running when the plugin is updated continue using the old cached plugin state.

**Symptoms**:
- `/track:help` visible in some sessions but not others
- New skills (`/track:init`, `/track:auto`, `/track:config`, `/track:export`) missing in old sessions
- Inconsistent skill availability across different working directories

### Root Cause

Claude Code loads plugins once at session startup. Session-level plugin state is not refreshed when:
- Plugin cache is updated
- Plugin version changes
- Skills are added/removed

**Cache location**: `/home/cadrianmae/.claude/plugins/cache/cadrianmae-claude-marketplace/track/2.0.0/`
**Session directories**: `/home/cadrianmae/.claude/projects/-home-cadrianmae-*/`

### Current Workaround

**Restart Claude sessions** in affected directories:
1. Exit the Claude session
2. Start a new session
3. Plugin state refreshes on startup

### Potential Solutions

1. **Session reload command** - `/reload:plugins` to refresh plugin state
2. **Hot reload support** - Watch plugin cache for changes
3. **Version check on command** - Detect stale plugin state and prompt reload
4. **Installation hook** - Notify running sessions of plugin updates
5. **Documentation update** - Clearly document restart requirement in README

### Implementation Priority

Low priority - workaround is simple and issue only affects development/testing scenarios. Most users install plugins once and don't update frequently during active sessions.

---

## Semantic Search - Alternative Tools

**Priority**: Medium
**Phase**: Post-modernization (2.0.0)

Current implementation uses `odino` but better alternatives exist:

### Evaluation Criteria

- **Performance** - Fast indexing and search
- **Ease of use** - Simple CLI interface
- **Language support** - Multi-language code understanding
- **Maintenance** - Active development, reliable updates
- **Integration** - Works well with Claude Code workflows

### Alternative Tools to Evaluate

1. **Sourcegraph's `src`** - Enterprise-grade code search
2. **Zoekt** - Fast indexed search (used by Sourcegraph)
3. **ripgrep + semantic layer** - Hybrid approach
4. **Codebase context engines** - LLM-native indexing
5. **Custom solution** - SQLite FTS5 + embeddings

### Migration Strategy

- Maintain backward compatibility with odino
- Add tool selection in plugin config
- Support multiple backends simultaneously
- Provide migration utilities

---

## Version 2.0 Features

### Dynamic Injection v2
- Real-time data refresh in command output
- Interactive status displays
- Performance metrics

### Skills Migration
- Complete command → skill migration for all plugins
- Progressive disclosure for complex plugins
- Enhanced reference materials

### Validation Suite
- Automated marketplace validation
- Plugin health checks
- Integration testing framework

---

*Last Updated: 2026-01-27 17:40 UTC*
