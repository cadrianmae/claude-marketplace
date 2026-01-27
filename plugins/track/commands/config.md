---
description: View or update tracking verbosity configuration
argument-hint: [prompts=all|major|off] [sources=all|off]
allowed-tools: Bash, Read, Write
---

## Tracking Status (Auto-Captured)

**Auto-Track**: !`[ -f .claude/.ref-autotrack ] && echo "✓ Enabled" || echo "✗ Disabled"`
**Sources Tracked**: !`wc -l < CLAUDE_SOURCES.md 2>/dev/null || echo "0"`
**Prompts Tracked**: !`grep -c "^Prompt:" CLAUDE_PROMPTS.md 2>/dev/null || echo "0"`
**Git Status**: !`git rev-parse --is-inside-work-tree &>/dev/null && echo "✓ Git repo" || echo "✗ Not a git repo"`

## Quick Example

```bash
/track:config prompts=all sources=all
# ✓ Configuration updated
# PROMPTS_VERBOSITY: major → all (all requests tracked)
# SOURCES_VERBOSITY: all (unchanged)
```

# config - View or update verbosity settings

View or update tracking verbosity configuration.

## Usage

**View current settings:**
```bash
/track:config
```

**Update settings:**
```bash
/track:config prompts=all
/track:config sources=off
/track:config prompts=major sources=all
```

## What it does

1. **With no arguments** - Shows current configuration:
   - Reads `./.claude/.ref-config`
   - Displays PROMPTS_VERBOSITY and SOURCES_VERBOSITY
   - Explains what each setting means
   - Shows example entries for each level

2. **With arguments** - Updates configuration:
   - Parses `key=value` pairs
   - Updates `./.claude/.ref-config`
   - Validates setting values
   - Shows new configuration

## Configuration options

### PROMPTS_VERBOSITY

Controls what prompts are tracked to `CLAUDE_PROMPTS.md`:

- **`major`** (default) - Only significant multi-step academic/development work
  - Example: "Implement authentication system", "Debug complex algorithm"
  - Best for: Academic research, project documentation

- **`all`** - Track every user request
  - Example: "What is X?", "Explain Y", "Fix typo in file.txt"
  - Best for: Complete session logs, detailed auditing

- **`minimal`** - Only explicitly user-requested tracking
  - Only tracks when user says "track this" or similar
  - Best for: Selective manual curation

- **`off`** - Disable prompt tracking completely
  - No entries added to CLAUDE_PROMPTS.md
  - Best for: Source-only tracking

### SOURCES_VERBOSITY

Controls what sources are tracked to `CLAUDE_SOURCES.md`:

- **`all`** (default) - Track all WebSearch/WebFetch operations
  - Every search logged automatically
  - Best for: Complete research audit trail

- **`off`** - Disable source tracking completely
  - No entries added to CLAUDE_SOURCES.md
  - Best for: Prompt-only tracking

## Example output

**Viewing config:**
```
Current tracking configuration (./.claude/.ref-config):

PROMPTS_VERBOSITY=major
  Tracks: Only significant multi-step academic/development work
  Example: "Implement user authentication", "Debug performance issue"

SOURCES_VERBOSITY=all
  Tracks: All WebSearch/WebFetch operations
  Example: Every search for documentation, APIs, or concepts

To change settings:
  /track:config prompts=all
  /track:config sources=off
  /track:config prompts=minimal sources=all
```

**Updating config:**
```
✓ Configuration updated

PROMPTS_VERBOSITY: major → all
SOURCES_VERBOSITY: all (unchanged)

New behavior:
- Every user request will be tracked to CLAUDE_PROMPTS.md
- All searches continue to be tracked to CLAUDE_SOURCES.md
```

## Prerequisites

Run `/track:init` first to create `.claude/.ref-config`.

## Notes

- Changes take effect immediately
- Existing tracked data is not affected
- Works regardless of auto-tracking status (on/off)
- Invalid values are rejected with error message
