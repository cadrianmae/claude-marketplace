# auto - Toggle auto-tracking on/off

Toggle automatic reference tracking on or off.

## What it does

1. **Check current status:**
   - Looks for `./.claude/.ref-autotrack` marker file
   - If exists → auto-tracking is enabled
   - If missing → auto-tracking is disabled

2. **Toggle state:**
   - If **enabled** → deletes `./.claude/.ref-autotrack` (disables)
   - If **disabled** → creates `./.claude/.ref-autotrack` (enables)

3. **Show new status:**
   - Reports whether auto-tracking is now enabled or disabled
   - Shows what will be tracked based on current config
   - Explains how to change verbosity settings

## Usage

```bash
/track:auto    # Toggle between enabled/disabled
```

## Output examples

**When toggling ON:**
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

**When toggling OFF:**
```
✓ Auto-tracking disabled

The ref-tracker skill will no longer automatically track.

You can still manually track using:
- /track:update - Scan recent history
- /track:init - Re-enable auto-tracking

To re-enable: /track:auto
```

## Prerequisites

Run `/track:init` first to create `.claude/` directory structure.

## Notes

- Toggling does not affect existing tracked data
- Manual tracking via `/track:update` still works when disabled
- Configuration in `.claude/.ref-config` persists across toggles
