#!/bin/bash
# Toggle or set hooks-based auto-tracking state
# Part of Track Plugin - called by `track-auto` wrapper (bin/track-auto)
# via the unified /track skill.

# Parse argument if provided
ARG="${1:-}"

# Determine current state from .ref-config
if [ -f .claude/.ref-config ]; then
    TRACKING_ENABLED=$(grep "^TRACKING_ENABLED=" .claude/.ref-config 2>/dev/null | cut -d= -f2)
    if [ "$TRACKING_ENABLED" = "true" ]; then
        CURRENT_STATE="enabled"
    else
        CURRENT_STATE="disabled"
    fi
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
    # Ensure .claude directory and config file exist
    mkdir -p .claude

    if [ ! -f .claude/.ref-config ]; then
        # Create config if missing
        cat > .claude/.ref-config << 'EOF'
TRACKING_ENABLED=true
PROMPTS_VERBOSITY=major
SOURCES_VERBOSITY=all
EXPORT_PATH=exports/
EOF
    else
        # Update existing config with sed
        if grep -q "^TRACKING_ENABLED=" .claude/.ref-config; then
            sed -i 's/^TRACKING_ENABLED=.*/TRACKING_ENABLED=true/' .claude/.ref-config
        else
            # Add if missing
            echo "TRACKING_ENABLED=true" >> .claude/.ref-config
        fi
    fi

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
    echo "Use /track config to adjust verbosity settings."
else
    # Update config to set TRACKING_ENABLED=false
    if [ -f .claude/.ref-config ]; then
        if grep -q "^TRACKING_ENABLED=" .claude/.ref-config; then
            sed -i 's/^TRACKING_ENABLED=.*/TRACKING_ENABLED=false/' .claude/.ref-config
        else
            echo "TRACKING_ENABLED=false" >> .claude/.ref-config
        fi
    fi

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
    echo "To re-enable: /track auto on"
fi

# Show toggle message if applicable
if [ -z "$ARG" ]; then
    echo ""
    echo "Toggled: $CURRENT_STATE → $NEW_STATE"
fi
