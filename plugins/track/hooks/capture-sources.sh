#!/bin/bash
# PostToolUse hook for sources tracking
# Writes tool calls to claude_usage/sources.md in ASCII format
# Format: [YYYY-MM-DDTHH:MM±HH:MM] ToolName(params) -> summary
#   |> optional details (indented)
# Timestamps come from `date --iso-8601=minutes` (minute precision, with TZ).

# Calculate SCRIPT_DIR first (before any cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse hook input
HOOK_INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT_JSON=$(echo "$HOOK_INPUT" | jq -c '.tool_input // {}')
TOOL_RESPONSE=$(echo "$HOOK_INPUT" | jq -r '.tool_response // empty')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')

# Exit early if missing data
[ -z "$TOOL_NAME" ] && exit 0
[ -z "$CWD" ] && exit 0

# Change to project directory
cd "$CWD" || exit 0

# Load common utilities
source "$SCRIPT_DIR/common.sh"

# Ensure plugin data directory exists for error logs
mkdir -p "${CLAUDE_PLUGIN_DATA:-/tmp}" 2>/dev/null

# Exit if tracking not enabled
is_tracking_enabled || exit 0

# Read verbosity config
SOURCES_VERBOSITY=$(get_config_value "SOURCES_VERBOSITY" "all")
[ "$SOURCES_VERBOSITY" = "off" ] && exit 0

# Ensure file exists with preamble
ensure_file_with_preamble "claude_usage/sources.md" "sources"

# Get timestamp
TIMESTAMP=$(date --iso-8601=minutes)

# --- Format functions ---

format_read_entry() {
    local file_path
    local offset
    local limit
    local basename

    file_path=$(echo "$TOOL_INPUT_JSON" | jq -r '.file_path // "unknown"')
    offset=$(echo "$TOOL_INPUT_JSON" | jq -r '.offset // 0')
    limit=$(echo "$TOOL_INPUT_JSON" | jq -r '.limit // empty')

    # Get basename for compact display
    basename=$(basename "$file_path")

    # Calculate line range from response
    local line_count=0
    if [ -n "$TOOL_RESPONSE" ]; then
        line_count=$(echo "$TOOL_RESPONSE" | wc -l)
    fi

    # Build range string
    local range_str=""
    if [ "$offset" != "0" ] && [ -n "$offset" ]; then
        if [ -n "$limit" ]; then
            range_str=":${offset}-$((offset + limit))"
        else
            range_str=":${offset}+"
        fi
    fi

    # Detect functions/classes from response content
    local details=""
    if [ -n "$TOOL_RESPONSE" ]; then
        details=$(echo "$TOOL_RESPONSE" | grep -oE '^\s*(def |function |class |func |const |export (default )?(function|class) )\S+' | \
            sed 's/^[[:space:]]*//' | \
            sed 's/[({:].*//' | \
            sed 's/^def //' | sed 's/^function //' | sed 's/^class //' | sed 's/^func //' | \
            sed 's/^const //' | sed 's/^export default function //' | sed 's/^export default class //' | \
            sed 's/^export function //' | sed 's/^export class //' | \
            head -5 | tr '\n' ', ' | sed 's/, $//')
    fi

    # Write main line
    echo "[$TIMESTAMP] Read(${basename}${range_str}) -> ${line_count} lines" >> claude_usage/sources.md

    # Write detail line if functions/classes found
    if [ -n "$details" ]; then
        echo "  |> $details" >> claude_usage/sources.md
    fi
}

format_grep_entry() {
    local pattern
    local path
    local glob
    local output_mode

    pattern=$(echo "$TOOL_INPUT_JSON" | jq -r '.pattern // "unknown"')
    path=$(echo "$TOOL_INPUT_JSON" | jq -r '.path // "."')
    glob=$(echo "$TOOL_INPUT_JSON" | jq -r '.glob // empty')
    output_mode=$(echo "$TOOL_INPUT_JSON" | jq -r '.output_mode // "files_with_matches"')

    # Use glob as file filter display if available
    local file_filter="$path"
    if [ -n "$glob" ]; then
        file_filter="$glob"
    fi

    # Count matches and extract content/locations from response
    local match_count=0
    local details=""
    if [ -n "$TOOL_RESPONSE" ]; then
        match_count=$(echo "$TOOL_RESPONSE" | grep -c '.' 2>/dev/null || echo "0")

        # Show different details based on output mode
        case "$output_mode" in
            content)
                # Show actual match content (first 3 lines, truncate long lines)
                details=$(echo "$TOOL_RESPONSE" | head -3 | cut -c1-100 | tr '\n' ' | ' | sed 's/ | $//')
                ;;
            files_with_matches)
                # Show file paths (first 5)
                details=$(echo "$TOOL_RESPONSE" | head -5 | tr '\n' ', ' | sed 's/, $//')
                ;;
            count)
                # For count mode, show file:count pairs
                details=$(echo "$TOOL_RESPONSE" | head -5 | tr '\n' ', ' | sed 's/, $//')
                ;;
        esac
    fi

    # Write main line
    echo "[$TIMESTAMP] Grep($file_filter, \"$pattern\") -> $match_count matches" >> claude_usage/sources.md

    # Write detail line with matches/locations
    if [ -n "$details" ]; then
        echo "  |> $details" >> claude_usage/sources.md
    fi
}

format_webfetch_entry() {
    local url
    local short_url
    local summary

    url=$(echo "$TOOL_INPUT_JSON" | jq -r '.url // "unknown"')

    # Shorten URL for display (remove protocol, trim long paths)
    short_url=$(echo "$url" | sed 's|^https\?://||' | sed 's|^www\.||')
    if [ ${#short_url} -gt 60 ]; then
        short_url="${short_url:0:57}..."
    fi

    # Try LLM summarization of fetched content
    if [ -n "$TOOL_RESPONSE" ] && command -v claude >/dev/null 2>&1; then
        local prompt
        prompt=$(echo "$TOOL_INPUT_JSON" | jq -r '.prompt // "summarize this content"')

        # Create summarization context
        local context
        context=$(cat <<CONTEXT_EOF
Summarize what was learned from this web fetch in 1-2 sentences.

URL: $url
User asked: "$prompt"

Content (first 2000 chars):
${TOOL_RESPONSE:0:2000}

Provide a concise summary of the key information extracted.
CONTEXT_EOF
)

        # Call Claude for summary (no structured output needed, just text)
        summary=$(echo "$context" | claude --model haiku --print --no-session-persistence 2>>${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log | head -c 200)
    fi

    # Fallback to headings if LLM fails
    if [ -z "$summary" ] && [ -n "$TOOL_RESPONSE" ]; then
        summary=$(echo "$TOOL_RESPONSE" | grep -E '^#{1,3} ' | head -4 | sed 's/^#* //' | tr '\n' ', ' | sed 's/, $//')
    fi

    # Write main line
    echo "[$TIMESTAMP] WebFetch($short_url) -> Summary" >> claude_usage/sources.md

    # Write summary detail line
    if [ -n "$summary" ]; then
        echo "  |> $summary" >> claude_usage/sources.md
    fi
}

format_websearch_entry() {
    local query

    query=$(echo "$TOOL_INPUT_JSON" | jq -r '.query // "unknown"')

    # Count results and extract URLs from response (FULL URLs, no truncation)
    local result_count=0
    local urls=""
    if [ -n "$TOOL_RESPONSE" ]; then
        # Count result entries (lines with URLs or titles)
        result_count=$(echo "$TOOL_RESPONSE" | grep -cE 'https?://' 2>/dev/null || echo "0")
        # Extract first 5 URLs, keep full URLs (remove protocol for brevity)
        urls=$(echo "$TOOL_RESPONSE" | grep -oE 'https?://[^[:space:])"]+' | head -5 | \
            sed 's|^https\?://||' | sed 's|^www\.||' | \
            tr '\n' ', ' | sed 's/, $//')
    fi

    # Write main line
    echo "[$TIMESTAMP] WebSearch(\"$query\") -> $result_count results" >> claude_usage/sources.md

    # Write detail line with full URLs
    if [ -n "$urls" ]; then
        echo "  |> $urls" >> claude_usage/sources.md
    fi
}

# --- Main dispatch ---

case "$TOOL_NAME" in
    Read)
        format_read_entry
        ;;
    Grep)
        format_grep_entry
        ;;
    WebFetch)
        format_webfetch_entry
        ;;
    WebSearch)
        format_websearch_entry
        ;;
    *)
        # Skip other tools
        exit 0
        ;;
esac

exit 0
