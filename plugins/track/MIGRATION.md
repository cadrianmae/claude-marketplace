# Migration Guide: Track Plugin v1.x → v2.0

This guide helps you migrate from Track Plugin v1.2.1 (skill-based) to v2.0.0 (hooks-based).

## Overview of Changes

### v1.x Architecture (Skill-Based)
- Relied on `ref-tracker` skill activation
- Claude decided when to invoke skill for tracking
- Manual `/track:update` for retroactive scanning
- Tracked to `CLAUDE_SOURCES.md` and `CLAUDE_PROMPTS.md` in project root

### v2.0 Architecture (Hooks-Based)
- Automatic tracking via Claude Code hooks
- PostToolUse, UserPromptSubmit, SessionEnd hooks
- Real-time capture - no manual scanning needed
- Tracked to `claude_usage/sources.md` and `claude_usage/prompts.md`
- Export support via `/track:export` command

## Breaking Changes

### 1. File Locations Changed

**v1.x:**
```
project-root/
├── CLAUDE_SOURCES.md
└── CLAUDE_PROMPTS.md
```

**v2.0:**
```
project-root/
└── claude_usage/
    ├── sources.md
    └── prompts.md
```

**Migration:**
```bash
# Option 1: Run /track:init (auto-detects old files)
/track:init

# Option 2: Manual migration
mkdir -p claude_usage
cat CLAUDE_SOURCES.md >> claude_usage/sources.md
cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md
# Optionally remove old files
rm CLAUDE_SOURCES.md CLAUDE_PROMPTS.md
```

### 2. Tracking Mechanism Changed

**v1.x:** Skill-based (Claude invokes `ref-tracker` skill)
```
User searches → Claude decides to track → Skill runs → Entry added
```

**v2.0:** Hooks-based (automatic)
```
User searches → PostToolUse hook fires → Entry added automatically
```

**No action needed** - hooks activate automatically when `.ref-autotrack` exists.

### 3. Commands Deprecated

**Deprecated in v2.0:**
- `/track:update` - No longer needed (real-time tracking via hooks)

**Still available:**
- `/track:init` - Enhanced for hooks
- `/track:auto` - Updated for hooks
- `/track:config` - Enhanced with interactive mode
- `/track:help` - Updated documentation

**New in v2.0:**
- `/track:export` - Generate bibliographies, methodology sections, BibTeX

### 4. Default Behavior Changed

**v1.x:** Tracking disabled by default after `/track:init`
- Required explicit `/track:auto on` to enable

**v2.0:** Tracking enabled by default after `/track:init`
- Automatically creates `.ref-autotrack` marker
- Hooks activate immediately

**Migration:** No action needed. Existing `.ref-autotrack` files work unchanged.

## Step-by-Step Migration

### For Existing Projects with Tracking Enabled

**Current state:**
- `.claude/.ref-autotrack` exists
- `.claude/.ref-config` exists
- `CLAUDE_SOURCES.md` and `CLAUDE_PROMPTS.md` exist

**Migration steps:**

1. **Update plugin to v2.0.0**
   - Plugin updates automatically via marketplace
   - Hooks configuration loads automatically

2. **Run `/track:init` to migrate files**
   ```bash
   /track:init
   ```
   This will:
   - Detect old `CLAUDE_*.md` files
   - Create `claude_usage/` directory
   - Create new files with preambles
   - Show migration instructions

3. **Manually migrate existing data**
   ```bash
   cat CLAUDE_SOURCES.md >> claude_usage/sources.md
   cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md
   ```

4. **Remove old files (optional)**
   ```bash
   rm CLAUDE_SOURCES.md CLAUDE_PROMPTS.md
   ```

5. **Remove `/track:update` calls from workflows**
   - Search for `/track:update` in documentation
   - Remove these calls (no longer needed)

6. **Test hooks are working**
   - Perform a search
   - Check `claude_usage/sources.md` for new entry
   - Hooks are working!

### For New Projects

Simply run:
```bash
/track:init
```

Hooks activate automatically. No additional configuration needed.

## Configuration Migration

### .claude/.ref-config

**v1.x format:**
```
PROMPTS_VERBOSITY=major
SOURCES_VERBOSITY=all
```

**v2.0 format (enhanced):**
```
PROMPTS_VERBOSITY=major
SOURCES_VERBOSITY=all
EXPORT_PATH=exports/
```

**Migration:** Add `EXPORT_PATH=exports/` to your `.claude/.ref-config` or run `/track:config` to update.

### .claude/.ref-autotrack

**v1.x:** Simple marker file
```
# Auto-tracking enabled
```

**v2.0:** Enhanced with metadata
```
# Track Plugin v2.0 - Automatic Tracking Enabled
#
# Hooks configured:
# - PostToolUse: Tracks WebSearch, WebFetch, Read, Grep
# - UserPromptSubmit: Captures user prompts
# - SessionEnd: Pairs prompts with outcomes
#
# Last enabled: 2026-01-27 14:23:15
```

**Migration:** Existing marker files work unchanged. Hooks will update the format on next toggle.

## Feature Comparison

| Feature | v1.x | v2.0 |
|---------|------|------|
| **Tracking Method** | Skill-based | Hooks-based |
| **Activation** | Manual (skill invocation) | Automatic (hooks) |
| **Reliability** | Depends on skill invocation | 100% capture rate |
| **Retroactive Scan** | `/track:update` | Not needed |
| **File Location** | Root (`CLAUDE_*.md`) | `claude_usage/` directory |
| **File Preambles** | No | Yes (explains format) |
| **Export Support** | No | Yes (5 formats) |
| **Interactive Config** | No | Yes (AskUserQuestion) |
| **Session Timestamps** | No | Yes (in prompts.md) |

## Common Migration Issues

### Issue 1: Old files not found

**Symptom:** `/track:init` doesn't detect old `CLAUDE_*.md` files

**Solution:**
```bash
# Check if files exist
ls -la CLAUDE_*.md

# If they exist but not detected, manually migrate
mkdir -p claude_usage
cat CLAUDE_SOURCES.md >> claude_usage/sources.md 2>/dev/null || echo "No CLAUDE_SOURCES.md"
cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md 2>/dev/null || echo "No CLAUDE_PROMPTS.md"
```

### Issue 2: Tracking not working after upgrade

**Symptom:** No new entries in `claude_usage/sources.md`

**Diagnosis:**
```bash
# Check if marker exists
ls -la .claude/.ref-autotrack

# Check config
cat .claude/.ref-config
```

**Solution:**
```bash
# Re-enable tracking
/track:auto on
```

### Issue 3: Old files still being used

**Symptom:** New entries going to old `CLAUDE_*.md` files

**Solution:**
- This shouldn't happen in v2.0 (hooks use new paths)
- If it does, remove old files:
  ```bash
  rm CLAUDE_SOURCES.md CLAUDE_PROMPTS.md
  ```

### Issue 4: Export command not found

**Symptom:** `/track:export` command doesn't work

**Solution:**
- Ensure plugin updated to v2.0.0:
  ```bash
  # Check plugin version
  cat .claude-plugin/plugin.json | grep version
  ```
- Should show `"version": "2.0.0"`

## Rollback (If Needed)

If you need to rollback to v1.x:

1. **Downgrade plugin to v1.2.1**
   ```bash
   # Via marketplace or manual version pin
   ```

2. **Restore old file structure**
   ```bash
   # Copy data back to root
   cp claude_usage/sources.md CLAUDE_SOURCES.md
   cp claude_usage/prompts.md CLAUDE_PROMPTS.md
   ```

3. **Remove v2.0 files**
   ```bash
   rm -rf claude_usage/
   ```

**Note:** Hooks will be inactive in v1.x (skill-based tracking will resume).

## New Features in v2.0

### 1. Export Functionality

Generate outputs for academic papers:

```bash
# Bibliography for works cited
/track:export bibliography

# Methodology section
/track:export methodology

# BibTeX for LaTeX
/track:export bibtex references.bib

# Numbered citations
/track:export citations

# Chronological timeline
/track:export timeline
```

### 2. Interactive Configuration

```bash
# Interactive mode with AskUserQuestion
/track:config

# Direct mode (v1.x style)
/track:config prompts=all sources=off
```

### 3. File Preambles

All tracked files now include explanatory preambles:
- Format explanation
- Usage examples
- Configuration reference
- Command documentation

### 4. Session Timestamps

Prompts now include session timestamps:
```
Prompt: "Implement authentication"
Outcome: Created auth middleware...
Session: 2026-01-27 14:23:15
```

## Testing Your Migration

After migration, test that hooks are working:

1. **Test source tracking:**
   ```bash
   # Ask Claude to search for something
   "Search for PostgreSQL JSONB documentation"

   # Check file
   tail claude_usage/sources.md
   # Should show new WebSearch entry
   ```

2. **Test prompt tracking:**
   ```bash
   # Make a substantial request
   "Implement a simple function to validate email addresses"

   # After completion, check file
   tail claude_usage/prompts.md
   # Should show new prompt-outcome pair
   ```

3. **Test export:**
   ```bash
   /track:export bibliography
   # Should create exports/bibliography.md
   ```

## Getting Help

If you encounter issues during migration:

1. **Check documentation:**
   ```bash
   /track:help
   ```

2. **Review configuration:**
   ```bash
   /track:config
   ```

3. **Verify tracking status:**
   ```bash
   /track:auto
   ```

4. **Check plugin version:**
   ```bash
   cat .claude-plugin/plugin.json | grep version
   # Should show "2.0.0"
   ```

5. **Report issues:**
   - Use `/feedback:bug` command
   - Or open issue at https://github.com/cadrianmae/claude-marketplace

## Summary

**Key takeaways:**
- v2.0 uses hooks for automatic tracking (more reliable)
- Files moved to `claude_usage/` directory (better organization)
- `/track:update` no longer needed (real-time capture)
- Export support added for academic papers
- Migration is backward compatible (existing config works)
- Most changes are automatic (minimal manual intervention)

**Migration checklist:**
- [ ] Update plugin to v2.0.0
- [ ] Run `/track:init`
- [ ] Migrate old file content manually
- [ ] Remove old files (optional)
- [ ] Remove `/track:update` from workflows
- [ ] Test source tracking works
- [ ] Test prompt tracking works
- [ ] Test export functionality

Welcome to Track Plugin v2.0! 🎉
