---
name: init
description: This skill should be used when the user asks to initialize tracking, set up reference tracking, enable automatic source tracking, create tracking files, or start using the track plugin for the current project. Creates claude_usage/ directory with sources.md and prompts.md files, configures hooks-based automatic tracking with verbosity settings, and enables PostToolUse and SessionEnd hooks.
allowed-tools: Bash, Write
disable-model-invocation: true
user-invocable: false
---

## Tracking Status (Auto-Captured)

**Tracking Enabled**: !`[ -f .claude/.ref-autotrack ] && echo "✓ Active" || echo "✗ Inactive"`
**Sources File**: !`[ -f claude_usage/sources.md ] && echo "✓ Exists ($(wc -l < claude_usage/sources.md) entries)" || echo "✗ Not created"`
**Prompts File**: !`[ -f claude_usage/prompts.md ] && echo "✓ Exists ($(grep -c '^Prompt:' claude_usage/prompts.md 2>/dev/null || echo 0) entries)" || echo "✗ Not created"`
**Git Status**: !`git rev-parse --is-inside-work-tree &>/dev/null && echo "✓ Git repo" || echo "✗ Not a git repo"`

## Quick Example

```bash
/track:init
# Creates: claude_usage/sources.md (with preamble)
#          claude_usage/prompts.md (with preamble)
#          .claude/.ref-config (with default settings)
#          .claude/.ref-autotrack (enables hooks-based tracking)
```

# init - Initialize Hooks-Based Tracking

Initialize automatic reference and prompt tracking for the current project.

## What it does

1. **Create claude_usage/ directory:**
   - Creates `./claude_usage/` directory for tracked files
   - Visible (not hidden) for easy access and review

2. **Create tracking files with preambles:**
   - Creates `./claude_usage/sources.md` with explanatory preamble
   - Creates `./claude_usage/prompts.md` with explanatory preamble
   - If files exist, leaves them unchanged
   - Preambles explain format, usage, and configuration

3. **Create `.claude/` directory structure:**
   - Creates `./.claude/` directory if missing
   - Creates `./.claude/.ref-config` with default settings:
     ```
     PROMPTS_VERBOSITY=major
     SOURCES_VERBOSITY=all
     EXPORT_PATH=exports/
     ```
   - Creates `./.claude/.ref-autotrack` marker file with metadata

4. **Enable hooks-based tracking:**
   - Hooks activate automatically when `.ref-autotrack` exists
   - PostToolUse hook → tracks WebSearch/WebFetch/Read/Grep
   - UserPromptSubmit hook → captures user prompts
   - SessionEnd hook → pairs prompts with outcomes
   - **No skill activation needed** - fully automatic

5. **Migrate existing files (if present):**
   - Detects old `CLAUDE_SOURCES.md` and `CLAUDE_PROMPTS.md`
   - Offers to migrate content to new `claude_usage/` directory
   - Preserves existing tracked data

6. **Show setup summary:**
   - Files created/existing
   - Auto-tracking status (enabled by default in v2.0)
   - Config location
   - Next steps

## Default configuration

After init, tracking is **enabled by default** (changed in v2.0.0):
- **Sources**: Track all WebSearch/WebFetch operations automatically
- **Prompts**: Track major academic/development work automatically
- **Export**: Default export path is `exports/` directory

Hooks run automatically - no manual intervention needed.

## Next steps

After running `/track:init`:
- **Work normally** - hooks track automatically
- Use `/track:config` to adjust verbosity settings
- Use `/track:auto off` to temporarily disable tracking
- Use `/track:export` to generate bibliographies or methodology sections
- Use `/track:help` for detailed documentation

## Files created

```
.claude/
├── .ref-autotrack          # Marker: hooks-based tracking enabled
├── .ref-config             # Verbosity and export settings
└── .track-tmp/             # Temporary storage for prompt capture
claude_usage/
├── sources.md              # Research sources (with preamble)
└── prompts.md              # Major prompts and outcomes (with preamble)
```

## Migration from v1.x

If you have existing `CLAUDE_SOURCES.md` or `CLAUDE_PROMPTS.md` files:
- Init will detect them and offer migration
- Content is moved to `claude_usage/` directory
- Old files can be archived or removed
- No data loss during migration

## Output

Concise status report showing what was created, migration status, and current configuration.


## Implementation

Initialization functionality is implemented in `scripts/init.sh`:

```bash
# Get skill directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute init script
bash "$SKILL_DIR/scripts/init.sh"
```

**Script:** `skills/init/scripts/init.sh` (134 lines)

**Features:**
- Directory creation (claude_usage/, .claude/, .track-tmp/)
- File creation with comprehensive preambles
- Configuration file with defaults
- Autotrack marker with metadata and timestamp
- Legacy file detection and migration guidance
- Success summary with next steps

See `scripts/init.sh` for full implementation details.
