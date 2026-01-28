#!/bin/bash
# PostToolUse hook for automatic source tracking
# Tracks WebSearch, WebFetch, Read, and Grep operations to claude_usage/sources.md

# Validate jq is available
command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required for hook execution" >&2
    exit 1
}

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Exit if tracking not enabled for this project
is_tracking_enabled || exit 0

# Read verbosity config
SOURCES_VERBOSITY=$(get_config_value "SOURCES_VERBOSITY" "all")

# Exit if sources tracking is off
[ "$SOURCES_VERBOSITY" = "off" ] && exit 0

# Parse hook input JSON from stdin
HOOK_INPUT=$(cat)

# Extract tool information
tool_name=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
tool_input=$(echo "$HOOK_INPUT" | jq -r '.tool_input // empty')
tool_output=$(echo "$HOOK_INPUT" | jq -r '.tool_response // empty')

# Skip if no tool name
[ -z "$tool_name" ] && exit 0

# Determine attribution (User vs Claude)
# TODO: Smarter attribution logic based on conversation context
# For now, default to [Claude] for all automated tracking
attribution="[Claude]"

# Ensure file exists with preamble
ensure_file_with_preamble "claude_usage/sources.md" "sources"

# Format entry based on tool type
case "$tool_name" in
    WebSearch)
        query=$(echo "$tool_input" | jq -r '.query // empty')
        # Get first result URL if available
        url=$(echo "$tool_output" | jq -r '.results[0].url // "No results"' 2>/dev/null || echo "No results")

        if [ -n "$query" ]; then
            echo "$attribution WebSearch(\"$query\"): $url" >> claude_usage/sources.md
        fi
        ;;

    WebFetch)
        url=$(echo "$tool_input" | jq -r '.url // empty')
        prompt=$(echo "$tool_input" | jq -r '.prompt // empty')
        # Get summary from response (truncate to 200 chars)
        summary=$(echo "$tool_output" | jq -r '.response // .content // empty' 2>/dev/null | head -c 200)

        if [ -n "$url" ]; then
            if [ -n "$summary" ]; then
                echo "$attribution WebFetch(\"$url\", \"$prompt\"): $summary" >> claude_usage/sources.md
            else
                echo "$attribution WebFetch(\"$url\"): Fetched content" >> claude_usage/sources.md
            fi
        fi
        ;;

    Read|Grep)
        # Track documentation reads only
        file_path=$(echo "$tool_input" | jq -r '.file_path // .path // empty')
        pattern=$(echo "$tool_input" | jq -r '.pattern // empty' 2>/dev/null)

        # Check if this is a documentation file
        if [[ "$file_path" =~ (docs?|README|CONTRIBUTING|man/|\.md$) ]]; then
            if [ "$tool_name" = "Grep" ] && [ -n "$pattern" ]; then
                echo "$attribution $tool_name(\"$file_path\", pattern=\"$pattern\"): Documentation reference" >> claude_usage/sources.md
            else
                echo "$attribution $tool_name(\"$file_path\"): Documentation reference" >> claude_usage/sources.md
            fi
        fi
        ;;
esac

# Exit successfully
exit 0
