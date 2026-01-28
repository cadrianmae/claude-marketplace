#!/bin/bash
# Toggle or set hooks-based auto-tracking state
# Part of Track Plugin v2.0 - called by /track:auto skill

# Parse argument if provided
ARG="${1:-}"

# Determine current state
if [ -f .claude/.ref-autotrack ]; then
    CURRENT_STATE="enabled"
else
    CURRENT_STATE="disabled"
fi

# Determine new state
case "$ARG" in
    on)
        NEW_STATE="enabled"
        ;;
    off)
        NEW_STATE="disabled"
        ;;
    "")
        # Toggle
        if [ "$CURRENT_STATE" = "enabled" ]; then
            NEW_STATE="disabled"
        else
            NEW_STATE="enabled"
        fi
        ;;
    *)
        echo "Error: Invalid argument '$ARG'. Use 'on', 'off', or no argument to toggle."
        exit 1
        ;;
esac

# Apply new state
if [ "$NEW_STATE" = "enabled" ]; then
    # Ensure .claude directory exists
    mkdir -p .claude

    # Create marker with metadata
    cat > .claude/.ref-autotrack << EOF
# Track Plugin v2.0 - Automatic Tracking Enabled
#
# This marker file enables hooks-based automatic tracking for this project.
#
# Hooks configured:
# - PostToolUse: Tracks WebSearch, WebFetch, Read, Grep
# - UserPromptSubmit: Captures user prompts
# - SessionEnd: Pairs prompts with outcomes
#
# Verbosity settings: ./.claude/.ref-config
# Toggle tracking: /track:auto
# Disable tracking: rm .claude/.ref-autotrack
#
# Last enabled: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    echo "✓ Hooks-based tracking enabled"
    echo ""
    echo "Automatic tracking via hooks:"
    echo "  - PostToolUse: Research sources (WebSearch/WebFetch/Read/Grep) → claude_usage/sources.md"
    echo "  - SessionEnd: Major prompts and outcomes → claude_usage/prompts.md"
    echo ""

    # Read config to show current settings
    if [ -f .claude/.ref-config ]; then
        PROMPTS_VERB=$(grep "^PROMPTS_VERBOSITY=" .claude/.ref-config | cut -d= -f2)
        SOURCES_VERB=$(grep "^SOURCES_VERBOSITY=" .claude/.ref-config | cut -d= -f2)
        echo "Current verbosity settings:"
        echo "  - Prompts: ${PROMPTS_VERB:-major}"
        echo "  - Sources: ${SOURCES_VERB:-all}"
        echo ""
    fi

    echo "Hooks run automatically - no manual intervention needed."
    echo ""
    echo "Use /track:config to adjust verbosity settings."
else
    # Delete marker
    rm -f .claude/.ref-autotrack

    # Clean up temporary files
    rm -rf .claude/.track-tmp

    echo "✓ Hooks-based tracking disabled"
    echo ""
    echo "Hooks will no longer run automatically."
    echo ""
    echo "Tracked files remain intact:"
    echo "  - claude_usage/sources.md"
    echo "  - claude_usage/prompts.md"
    echo ""
    echo "To re-enable: /track:auto on"
fi

# Show toggle message if applicable
if [ -z "$ARG" ]; then
    echo ""
    echo "Toggled: $CURRENT_STATE → $NEW_STATE"
fi
