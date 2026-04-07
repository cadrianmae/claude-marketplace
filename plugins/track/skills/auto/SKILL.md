---
name: auto
description: "This skill should be used when the user asks to enable tracking, disable tracking, toggle auto-tracking, turn on/off automatic tracking, pause tracking, resume tracking, or control hooks-based tracking state. Manages TRACKING_ENABLED config value in .claude/.ref-config to activate/deactivate hooks for real-time automatic source and prompt tracking with LLM-enhanced summaries (v2.5+)."
argument-hint: "[on|off]"
allowed-tools: [Bash, Write]
disable-model-invocation: true
user-invocable: true
---

## Tracking Status (Auto-Captured)

**Auto-Track**: !`grep "^TRACKING_ENABLED=" .claude/.ref-config 2>/dev/null | cut -d= -f2 | sed 's/true/✓ Enabled/;s/false/✗ Disabled/' || echo "✗ Disabled"`
**Sources Tracked**: !`wc -l < claude_usage/sources.md 2>/dev/null || echo "0"`
**Prompts Tracked**: !`grep -c '^Prompt:' claude_usage/prompts.md 2>/dev/null || echo "0"`
**Git Status**: !`git rev-parse --is-inside-work-tree &>/dev/null && echo "✓ Git repo" || echo "✗ Not a git repo"`

## Quick Example

```bash
/track:auto on
# ✓ Real-time hooks-based tracking enabled (v2.1)
# Stop hook: LLM-enhanced summaries after each response
# Sources: WebSearch/WebFetch/Read/Grep → claude_usage/sources.md
# Prompts: Major work (LLM-classified) → claude_usage/prompts.md
```

# auto - Control Hooks-Based Auto-Tracking (v2.1)

Toggle or explicitly set automatic hooks-based tracking with LLM-enhanced summaries.

## Usage

```bash
/track:auto          # Toggle between enabled/disabled
/track:auto on       # Explicitly enable
/track:auto off      # Explicitly disable
```

## What it does

1. **Check current status:**
   - Reads `TRACKING_ENABLED` from `./.claude/.ref-config`
   - If `true` → hooks-based tracking is enabled
   - If `false` → hooks are inactive

2. **Update state:**
   - **No argument** → toggle current state
   - **Argument "on"** → enable (set `TRACKING_ENABLED=true`)
   - **Argument "off"** → disable (set `TRACKING_ENABLED=false`)

3. **When enabling:**
   - Sets `TRACKING_ENABLED=true` in `./.claude/.ref-config`
   - Hooks activate automatically
   - No skill invocation needed

4. **When disabling:**
   - Sets `TRACKING_ENABLED=false` in `./.claude/.ref-config`
   - Hooks stop running
   - Temporary files cleaned up

5. **Show new status:**
   - Reports whether hooks-based tracking is now enabled or disabled
   - Shows what will be tracked based on current config
   - Explains how to change verbosity settings

## Output examples

**When enabling:**
```
✓ Hooks-based tracking enabled

Automatic tracking via hooks:
- PostToolUse: Research sources (WebSearch/WebFetch/Read/Grep) → claude_usage/sources.md
- SessionEnd: Major prompts and outcomes → claude_usage/prompts.md

Current verbosity settings:
- Prompts: major (only significant academic/development work)
- Sources: all (every search operation)

Hooks run automatically - no manual intervention needed.

Use /track:config to adjust verbosity settings.
```

**When disabling:**
```
✓ Hooks-based tracking disabled

Hooks will no longer run automatically.

Tracked files remain intact:
- claude_usage/sources.md
- claude_usage/prompts.md

To re-enable: /track:auto on
```

**When toggling:**
```
✓ Hooks-based tracking toggled: OFF → ON

[Shows enabled message above]
```

## Prerequisites

Run `/track:init` first to create `.claude/` directory structure.

## Notes

- State changes do not affect existing tracked data
- Configuration in `.claude/.ref-config` persists across state changes
- Hooks activate/deactivate instantly based on `TRACKING_ENABLED` value
- Temporary files in `.claude/.track-tmp/` are cleaned on disable

## Implementation

Auto-tracking toggle functionality is implemented in `scripts/auto.sh`:

```bash
# Get skill directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute auto script with arguments
bash "$SKILL_DIR/scripts/auto.sh" "$@"
```

**Script:** `skills/auto/scripts/auto.sh` (102 lines)

**Features:**
- Argument parsing (on/off/toggle)
- State detection via marker file
- Marker creation with metadata
- Temporary file cleanup on disable
- Status reporting with verbosity settings
- Toggle state tracking

See `scripts/auto.sh` for full implementation details.
