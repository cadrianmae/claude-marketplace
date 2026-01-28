---
name: config
description: This skill should be used when the user asks to view tracking configuration, adjust tracking settings, configure what gets tracked, change tracking verbosity, set export path, customize prompt tracking, customize source tracking, or modify .claude/.ref-config settings. Supports interactive mode with AskUserQuestion or direct key=value updates for PROMPTS_VERBOSITY, SOURCES_VERBOSITY, and EXPORT_PATH.
argument-hint: [prompts=all|major|minimal|off] [sources=all|off] [export_path=path/]
allowed-tools: Bash, Read, Write, AskUserQuestion
disable-model-invocation: true
user-invocable: false
---

## Current Configuration (Auto-Captured)

**Prompts Verbosity**: !`grep PROMPTS_VERBOSITY .claude/.ref-config 2>/dev/null | cut -d= -f2 || echo "major (default)"`
**Sources Verbosity**: !`grep SOURCES_VERBOSITY .claude/.ref-config 2>/dev/null | cut -d= -f2 || echo "all (default)"`
**Export Path**: !`grep EXPORT_PATH .claude/.ref-config 2>/dev/null | cut -d= -f2 || echo "exports/ (default)"`
**Config File**: !`[ -f .claude/.ref-config ] && echo "✓ Exists" || echo "✗ Not found"`

## Quick Example

```bash
/track:config prompts=all sources=all
# ✓ Configuration updated
# PROMPTS_VERBOSITY: major → all (all requests tracked)
# SOURCES_VERBOSITY: all (unchanged)

/track:config
# Interactive mode - uses AskUserQuestion
```

# config - View or Update Tracking Configuration

View or update tracking verbosity and export configuration.

## Usage

**Interactive mode (uses AskUserQuestion):**
```bash
/track:config
```

**Direct mode (update immediately):**
```bash
/track:config prompts=all
/track:config sources=off
/track:config prompts=major sources=all
/track:config export_path=paper/references/
/track:config prompts=all export_path=exports/
```

## What it does

1. **With no arguments** - Interactive configuration:
   - Uses AskUserQuestion to present configuration options
   - Shows current settings
   - Allows selection of new values
   - Updates `./.claude/.ref-config`
   - Shows new configuration

2. **With arguments** - Direct update:
   - Parses `key=value` pairs
   - Updates `./.claude/.ref-config`
   - Validates setting values
   - Shows new configuration

## Configuration options

### PROMPTS_VERBOSITY

Controls what prompts are tracked to `claude_usage/prompts.md`:

- **`major`** (default) - Only significant multi-step academic/development work
  - Example: "Implement authentication system", "Debug complex algorithm"
  - Heuristic: Response >100 words or multiple tool uses
  - Best for: Academic research, project documentation

- **`all`** - Track every user request
  - Example: "What is X?", "Explain Y", "Fix typo in file.txt"
  - Best for: Complete session logs, detailed auditing

- **`minimal`** - Only explicitly user-requested tracking
  - Only tracks when user says "track this" or similar
  - Best for: Selective manual curation

- **`off`** - Disable prompt tracking completely
  - No entries added to claude_usage/prompts.md
  - Best for: Source-only tracking

### SOURCES_VERBOSITY

Controls what sources are tracked to `claude_usage/sources.md`:

- **`all`** (default) - Track all WebSearch/WebFetch/Read/Grep operations
  - Every search logged automatically
  - Documentation reads included
  - Best for: Complete research audit trail

- **`off`** - Disable source tracking completely
  - No entries added to claude_usage/sources.md
  - Best for: Prompt-only tracking

### EXPORT_PATH (new in v2.0)

Default directory for `/track:export` command output:

- **`exports/`** (default) - Standard export directory
- Can be absolute or relative path
- Used when no output path specified in export command
- Examples: `exports/`, `paper/references/`, `/tmp/tracking/`

## Example output

**Viewing config (interactive mode):**

Uses AskUserQuestion with three questions:
1. **Prompts verbosity:** major (default) | all | minimal | off
2. **Sources verbosity:** all (default) | off
3. **Export path:** exports/ (default) | paper/ | custom path

**Updating config (direct mode):**
```
✓ Configuration updated

PROMPTS_VERBOSITY: major → all
SOURCES_VERBOSITY: all (unchanged)
EXPORT_PATH: exports/ (unchanged)

New behavior:
- Every user request will be tracked to claude_usage/prompts.md
- All searches continue to be tracked to claude_usage/sources.md
- Exports default to exports/ directory
```

## Prerequisites

Run `/track:init` first to create `.claude/.ref-config`.

## Notes

- Changes take effect immediately
- Existing tracked data is not affected
- Works regardless of auto-tracking status (on/off)
- Invalid values are rejected with error message
- Interactive mode recommended for first-time configuration

## v2.0 Changes

**New in v2.0:**
- Added EXPORT_PATH configuration
- Interactive mode with AskUserQuestion
- Direct mode for scripting/automation
- File paths updated to claude_usage/

## Implementation

Configuration functionality is implemented in `scripts/config.sh`:

```bash
# Get skill directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute config script with arguments
bash "$SKILL_DIR/scripts/config.sh" "$@"
```

**Script:** `skills/config/scripts/config.sh` (150 lines)

**Features:**
- Interactive mode detection (no arguments)
- Direct mode with key=value parsing
- Configuration file validation
- Value validation with error messages
- Change detection and reporting
- Behavior explanation for each setting

See `scripts/config.sh` for full implementation details.
