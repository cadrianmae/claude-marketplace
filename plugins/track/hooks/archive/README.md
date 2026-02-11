# Archived Hook Scripts

**Status:** Historical reference only - DO NOT USE

These hooks are no longer active and are maintained for historical reference only.

## Archived Hooks

- **post-tool-use.sh** - Deprecated in v2.4.0, replaced by capture-sources.sh (PostToolUse hook)
- **stop.sh** - Replaced by capture-prompt.sh in v2.5.0 (prompts-only Stop hook)
- **session-end.sh** - Deprecated in v2.1.0, replaced by Stop hook
- **user-prompt-submit.sh** - Deprecated in v2.1.0, replaced by Stop hook

## Why Archived

**v2.4.0 Changes:**
- Removed PostToolUse hook (post-tool-use.sh) - sources tracking moved to Stop hook
- Simplified to single Stop hook for both prompts and sources

**v2.5.0 Changes:**
- Split Stop hook into prompts-only (capture-prompt.sh)
- Added dedicated PostToolUse hook for sources (capture-sources.sh)
- Old stop.sh archived as reference

**v2.1.0 Changes:**
- Replaced SessionEnd + UserPromptSubmit with real-time Stop hook
- Eliminated batch processing at session end
- Removed prompt storage in temporary files

## Current Active Hooks

See `../hooks.json` for active hook configuration:
- **capture-prompt.sh** - Stop hook for prompts tracking
- **capture-sources.sh** - PostToolUse hook for sources tracking

## Migration Notes

These archived scripts reference deprecated APIs and file structures:
- `.ref-autotrack` marker file (replaced with `TRACKING_ENABLED` config in v2.5.1)
- Session-based temporary files (replaced with real-time tracking)
- Batch processing patterns (replaced with immediate writes)

**Do not use these scripts** - they will not work with current plugin infrastructure.

For current documentation, see:
- `../README.md` - Current hooks architecture
- `../CHANGELOG.md` - Version history and migration details
- `../MIGRATION.md` - Upgrade guides
