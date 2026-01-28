#!/bin/bash
# Configure tracking verbosity and export settings
# Part of Track Plugin v2.0 - called by /track:config skill

# Parse arguments
ARGS=("$@")

# Check if config file exists
if [ ! -f .claude/.ref-config ]; then
    echo "Error: Configuration file not found. Run /track:init first."
    exit 1
fi

# Read current configuration
CURRENT_PROMPTS=$(grep "^PROMPTS_VERBOSITY=" .claude/.ref-config | cut -d= -f2)
CURRENT_SOURCES=$(grep "^SOURCES_VERBOSITY=" .claude/.ref-config | cut -d= -f2)
CURRENT_EXPORT=$(grep "^EXPORT_PATH=" .claude/.ref-config | cut -d= -f2)

# Set defaults if empty
CURRENT_PROMPTS="${CURRENT_PROMPTS:-major}"
CURRENT_SOURCES="${CURRENT_SOURCES:-all}"
CURRENT_EXPORT="${CURRENT_EXPORT:-exports/}"

# If no arguments, use interactive mode
if [ ${#ARGS[@]} -eq 0 ]; then
    # Use AskUserQuestion for interactive configuration
    # This should be handled by Claude using the AskUserQuestion tool
    echo "Interactive mode:"
    echo ""
    echo "Current configuration:"
    echo "  - Prompts: $CURRENT_PROMPTS"
    echo "  - Sources: $CURRENT_SOURCES"
    echo "  - Export: $CURRENT_EXPORT"
    echo ""
    echo "Use AskUserQuestion to present configuration options."
    echo ""
    echo "Questions:"
    echo "1. Prompts verbosity: major (default) | all | minimal | off"
    echo "2. Sources verbosity: all (default) | off"
    echo "3. Export path: $CURRENT_EXPORT (current) | custom path"

    # Exit to allow Claude to use AskUserQuestion
    exit 0
fi

# Direct mode - parse key=value arguments
NEW_PROMPTS="$CURRENT_PROMPTS"
NEW_SOURCES="$CURRENT_SOURCES"
NEW_EXPORT="$CURRENT_EXPORT"

for arg in "${ARGS[@]}"; do
    key="${arg%%=*}"
    value="${arg#*=}"

    case "$key" in
        prompts)
            case "$value" in
                major|all|minimal|off)
                    NEW_PROMPTS="$value"
                    ;;
                *)
                    echo "Error: Invalid prompts value '$value'. Use: major|all|minimal|off"
                    exit 1
                    ;;
            esac
            ;;
        sources)
            case "$value" in
                all|off)
                    NEW_SOURCES="$value"
                    ;;
                *)
                    echo "Error: Invalid sources value '$value'. Use: all|off"
                    exit 1
                    ;;
            esac
            ;;
        export_path)
            # Validate path (basic check - ends with /)
            if [[ ! "$value" =~ /$ ]]; then
                value="${value}/"
            fi
            NEW_EXPORT="$value"
            ;;
        *)
            echo "Error: Unknown configuration key '$key'. Use: prompts|sources|export_path"
            exit 1
            ;;
    esac
done

# Update configuration file
cat > .claude/.ref-config << EOF
PROMPTS_VERBOSITY=$NEW_PROMPTS
SOURCES_VERBOSITY=$NEW_SOURCES
EXPORT_PATH=$NEW_EXPORT
EOF

# Show changes
echo "✓ Configuration updated"
echo ""

# Show what changed
if [ "$NEW_PROMPTS" != "$CURRENT_PROMPTS" ]; then
    echo "PROMPTS_VERBOSITY: $CURRENT_PROMPTS → $NEW_PROMPTS"
else
    echo "PROMPTS_VERBOSITY: $CURRENT_PROMPTS (unchanged)"
fi

if [ "$NEW_SOURCES" != "$CURRENT_SOURCES" ]; then
    echo "SOURCES_VERBOSITY: $CURRENT_SOURCES → $NEW_SOURCES"
else
    echo "SOURCES_VERBOSITY: $CURRENT_SOURCES (unchanged)"
fi

if [ "$NEW_EXPORT" != "$CURRENT_EXPORT" ]; then
    echo "EXPORT_PATH: $CURRENT_EXPORT → $NEW_EXPORT"
else
    echo "EXPORT_PATH: $CURRENT_EXPORT (unchanged)"
fi

echo ""
echo "New behavior:"

# Explain prompts behavior
case "$NEW_PROMPTS" in
    all)
        echo "  - Every user request will be tracked to claude_usage/prompts.md"
        ;;
    major)
        echo "  - Significant multi-step work will be tracked to claude_usage/prompts.md"
        ;;
    minimal)
        echo "  - Only explicitly requested prompts will be tracked"
        ;;
    off)
        echo "  - Prompt tracking is disabled"
        ;;
esac

# Explain sources behavior
case "$NEW_SOURCES" in
    all)
        echo "  - All searches will be tracked to claude_usage/sources.md"
        ;;
    off)
        echo "  - Source tracking is disabled"
        ;;
esac

# Explain export behavior
echo "  - Exports default to $NEW_EXPORT directory"
