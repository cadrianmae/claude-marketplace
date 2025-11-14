---
description: Toggle or set automatic reference tracking on/off
argument-hint: [on|off]
allowed-tools: Bash, Write
---

# auto - Control auto-tracking on/off

Toggle or explicitly set automatic reference tracking state.

## Usage

```bash
/track:auto          # Toggle between enabled/disabled
/track:auto on       # Explicitly enable
/track:auto off      # Explicitly disable
```

## What it does

1. **Check current status:**
   - Looks for `./.claude/.ref-autotrack` marker file
   - If exists → auto-tracking is enabled
   - If missing → auto-tracking is disabled

2. **Update state:**
   - **No argument** → toggle current state
   - **Argument "on"** → enable (create marker if missing)
   - **Argument "off"** → disable (delete marker if exists)

3. **When enabling:**
   - Creates `./.claude/.ref-autotrack` with explanatory content:
     ```
     # Auto-tracking marker for ref-tracker plugin
     # Presence = enabled | Absence = disabled
     # Managed by: /track:auto command
     # See: /track:help for details
     ```

4. **When disabling:**
   - Deletes `./.claude/.ref-autotrack` marker file

5. **Show new status:**
   - Reports whether auto-tracking is now enabled or disabled
   - Shows what will be tracked based on current config
   - Explains how to change verbosity settings

## Output examples

**When enabling:**
```
✓ Auto-tracking enabled

The ref-tracker skill will now automatically track:
- Research sources (WebSearch/WebFetch) → CLAUDE_SOURCES.md
- Major prompts and outcomes → CLAUDE_PROMPTS.md

Current verbosity settings:
- Prompts: major (only significant academic/development work)
- Sources: all (every search operation)

Use /track:config to adjust verbosity settings.
```

**When disabling:**
```
✓ Auto-tracking disabled

The ref-tracker skill will no longer automatically track.

You can still manually track using:
- /track:update - Scan recent history

To re-enable: /track:auto on
```

**When toggling:**
```
✓ Auto-tracking toggled: OFF → ON

[Shows enabled message above]
```

## Prerequisites

Run `/track:init` first to create `.claude/` directory structure.

## Notes

- State changes do not affect existing tracked data
- Manual tracking via `/track:update` works regardless of state
- Configuration in `.claude/.ref-config` persists across state changes
- Marker file includes explanatory content for other Claude sessions
