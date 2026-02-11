---
name: migrate
description: "DEPRECATED in v2.5.1 - Migration from v2.0 PostToolUse to v2.1 Stop hook is no longer needed. As of v2.5.1, tracking state is stored in TRACKING_ENABLED config value instead of .ref-autotrack marker file."
argument-hint: ""
allowed-tools: [Read, Write, Bash, AskUserQuestion]
user-invocable: true
deprecated: true
---

# Track Plugin Migration: v2.0 → v2.1+

**DEPRECATED in v2.5.1** - This migration tool is no longer needed. The `.ref-autotrack` marker file system was replaced with `TRACKING_ENABLED` config in v2.5.1.

## Purpose

Migrate projects from v2.0 tracking (PostToolUse hook) to v2.1+ tracking (Stop hook only).

## When to Use

- Upgrading Track Plugin from v2.0.x to v2.4.0+
- `sources.md` has old single-line format: `[Attribution] Tool("params"): Result`
- Missing `prompts.md` or `.track-tmp/` directory
- `.ref-autotrack` marker shows "Track Plugin v2.0"

## What It Does

1. **Detects v2.0 setup** - Checks `.claude/.ref-autotrack` for version marker
2. **Backs up existing files** - Creates `.claude/.track-backup/` with dated backups
3. **Updates marker file** - Sets `.ref-autotrack` to v2.1+ format
4. **Preserves data** - Keeps all existing v2.0 entries in `sources.md`
5. **Confirms success** - Verifies migration and shows next steps

## Migration Process

Run this skill to migrate your project:

```
/track:migrate
```

### Step 1: Detection

Check if this project needs migration:

```bash
# Read current tracking marker
if [ -f .claude/.ref-autotrack ]; then
    ref_content=$(cat .claude/.ref-autotrack)

    # Check if it's v2.0 format
    if echo "$ref_content" | grep -q "Track Plugin v2.0"; then
        echo "✓ Detected v2.0 tracking setup"
        echo "  Migration needed"
    elif echo "$ref_content" | grep -q "Track Plugin v2.1"; then
        echo "! Already on v2.1+ - no migration needed"
        exit 0
    else
        echo "! Unknown tracking version"
        echo "  Please run /track:init first"
        exit 1
    fi
else
    echo "! No tracking enabled"
    echo "  Please run /track:init first"
    exit 1
fi
```

### Step 2: Backup

Create backup before making any changes:

```bash
# Create backup directory
mkdir -p .claude/.track-backup

# Get current timestamp
timestamp=$(date +%Y%m%d_%H%M%S)

# Backup existing files if they exist
if [ -f claude_usage/sources.md ]; then
    cp claude_usage/sources.md .claude/.track-backup/sources_v20_$timestamp.md
    echo "✓ Backed up sources.md"
fi

if [ -f claude_usage/prompts.md ]; then
    cp claude_usage/prompts.md .claude/.track-backup/prompts_v20_$timestamp.md
    echo "✓ Backed up prompts.md"
fi

# Backup old marker file
cp .claude/.ref-autotrack .claude/.track-backup/ref-autotrack_v20_$timestamp

echo ""
echo "Backups saved to: .claude/.track-backup/"
echo "  - sources_v20_$timestamp.md"
echo "  - prompts_v20_$timestamp.md (if exists)"
echo "  - ref-autotrack_v20_$timestamp"
```

### Step 3: Update Marker

Update `.ref-autotrack` to v2.1+ format:

```bash
cat > .claude/.ref-autotrack <<'EOF'
# Track Plugin v2.1+ - Stop Hook Tracking
#
# Hooks configured:
# - Stop: Real-time LLM-enhanced tracking (prompts + sources)
#
# Migrated from v2.0: $(date)
#
# Previous PostToolUse hook has been deprecated in v2.4.0
# All tracking now uses Stop hook for consistent multi-line format
EOF

echo "✓ Updated .ref-autotrack to v2.1+ format"
```

### Step 4: Initialize v2.1 Structure

Ensure all v2.1+ directories exist:

```bash
# Create .track-tmp/ for Stop hook temporary storage
mkdir -p .claude/.track-tmp

echo "✓ Created .track-tmp/ directory"

# Ensure prompts.md exists with proper preamble
if [ ! -f claude_usage/prompts.md ]; then
    # Will be created by /track:init or first Stop hook run
    echo "  prompts.md will be created on first Stop hook execution"
fi
```

### Step 5: Verification

Verify migration success:

```bash
echo ""
echo "========================================="
echo "Migration Complete!"
echo "========================================="
echo ""
echo "Verification:"
echo "  - Backup location: .claude/.track-backup/"
echo "  - Tracking version: v2.1+ (Stop hook only)"
echo "  - Old v2.0 entries: Preserved in sources.md"
echo "  - New entries: Will use multi-line format"
echo ""
echo "Next Steps:"
echo "  1. Continue working - Stop hook now active"
echo "  2. New entries will use v2.1+ multi-line format"
echo "  3. Old v2.0 entries remain readable by export tools"
echo "  4. Run /track:export to verify compatibility"
echo ""
echo "Changes:"
echo "  - PostToolUse hook: Removed (deprecated in v2.4.0)"
echo "  - Stop hook: Now sole source tracker"
echo "  - Format: Multi-line with Summary/Links/Files fields"
echo ""
```

## Full Migration Script

Here's the complete migration script (use via Bash tool):

```bash
#!/bin/bash
# Migration: Track Plugin v2.0 → v2.1+

set -e  # Exit on error

echo "Track Plugin Migration: v2.0 → v2.1+"
echo "======================================"
echo ""

# Step 1: Detection
if [ ! -f .claude/.ref-autotrack ]; then
    echo "ERROR: No tracking enabled"
    echo "  Please run /track:init first"
    exit 1
fi

ref_content=$(cat .claude/.ref-autotrack)

if echo "$ref_content" | grep -q "Track Plugin v2.1"; then
    echo "Already on v2.1+ - no migration needed"
    exit 0
elif ! echo "$ref_content" | grep -q "Track Plugin v2.0"; then
    echo "ERROR: Unknown tracking version"
    echo "  Please run /track:init first"
    exit 1
fi

echo "✓ Detected v2.0 tracking setup"
echo ""

# Step 2: Backup
echo "Creating backups..."
mkdir -p .claude/.track-backup
timestamp=$(date +%Y%m%d_%H%M%S)

if [ -f claude_usage/sources.md ]; then
    cp claude_usage/sources.md .claude/.track-backup/sources_v20_$timestamp.md
    echo "  ✓ Backed up sources.md"
fi

if [ -f claude_usage/prompts.md ]; then
    cp claude_usage/prompts.md .claude/.track-backup/prompts_v20_$timestamp.md
    echo "  ✓ Backed up prompts.md"
fi

cp .claude/.ref-autotrack .claude/.track-backup/ref-autotrack_v20_$timestamp
echo "  ✓ Backed up .ref-autotrack"
echo ""

# Step 3: Update marker
echo "Updating tracking marker..."
cat > .claude/.ref-autotrack <<EOF
# Track Plugin v2.1+ - Stop Hook Tracking
#
# Hooks configured:
# - Stop: Real-time LLM-enhanced tracking (prompts + sources)
#
# Migrated from v2.0: $(date)
#
# Previous PostToolUse hook has been deprecated in v2.4.0
# All tracking now uses Stop hook for consistent multi-line format
EOF

echo "  ✓ Updated .ref-autotrack to v2.1+"
echo ""

# Step 4: Initialize v2.1 structure
echo "Initializing v2.1 structure..."
mkdir -p .claude/.track-tmp
echo "  ✓ Created .track-tmp/ directory"
echo ""

# Step 5: Verification
echo "========================================="
echo "Migration Complete!"
echo "========================================="
echo ""
echo "Verification:"
echo "  - Backup location: .claude/.track-backup/"
echo "  - Tracking version: v2.1+ (Stop hook only)"
echo "  - Old v2.0 entries: Preserved in sources.md"
echo "  - New entries: Will use multi-line format"
echo ""
echo "Next Steps:"
echo "  1. Continue working - Stop hook now active"
echo "  2. New entries will use v2.1+ multi-line format"
echo "  3. Old v2.0 entries remain readable by export tools"
echo "  4. Run /track:export to verify compatibility"
echo ""
echo "Changes:"
echo "  - PostToolUse hook: Removed (deprecated in v2.4.0)"
echo "  - Stop hook: Now sole source tracker"
echo "  - Format: Multi-line with Summary/Links/Files fields"
echo ""
```

## Rollback (If Needed)

If you need to rollback the migration:

```bash
# Find latest backup
latest_backup=$(ls -t .claude/.track-backup/ref-autotrack_v20_* | head -1)

# Restore marker
cp "$latest_backup" .claude/.ref-autotrack

echo "✓ Rolled back to v2.0"
echo "  Note: v2.4.0 no longer has PostToolUse hook registered"
echo "  You may need to downgrade the plugin to v2.0.5"
```

## Important Notes

- **Backward Compatible:** Export tools read both v2.0 and v2.1 formats
- **Data Preservation:** All existing v2.0 entries remain in `sources.md`
- **No Data Loss:** Backups created before any changes
- **Hook Change:** PostToolUse removed in v2.4.0 (now Stop hook only)
- **Format Change:** New entries use multi-line format with structured metadata

## Troubleshooting

**Migration fails with "Unknown tracking version":**
- Run `/track:init` to set up tracking first
- Check `.claude/.ref-autotrack` exists

**After migration, no new entries appearing:**
- Verify Stop hook is active (check `.claude/.ref-autotrack`)
- Check `.claude/.ref-config` for verbosity settings
- Run `/track:auto on` to re-enable tracking

**Want to verify migration worked:**
- Check `.claude/.ref-autotrack` for "v2.1+" marker
- Look for `.track-tmp/` directory
- Run `/track:export bibliography -` to test parsing

**Need to undo migration:**
- Use rollback script above
- Consider downgrading plugin to v2.0.5 if needed
