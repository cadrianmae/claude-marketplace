#!/bin/bash
# Stop hook for real-time tracking
# Tracks prompts and tool calls after each Claude response

# Helper function to exit with debug message
hook_exit() {
    local reason="$1"
    jq -n --arg reason "$reason" '{
        "systemMessage": "[Track v2.1 Debug] Hook exited early: \($reason)"
    }'
    exit 0
}

# Calculate SCRIPT_DIR first (before any cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse hook input FIRST (need cwd to check tracking)
HOOK_INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false')

# CRITICAL: Prevent infinite loops - skip if hook already ran
[ "$STOP_HOOK_ACTIVE" = "true" ] && hook_exit "stop_hook_active is true"

# Extract cwd and change to project directory
PROJECT_DIR=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    hook_exit "no valid PROJECT_DIR: $PROJECT_DIR"
fi
cd "$PROJECT_DIR" || hook_exit "failed to cd to $PROJECT_DIR"

# Load common utilities (now that we're in project dir)
source "$SCRIPT_DIR/common.sh"

# Exit if tracking not enabled
is_tracking_enabled || hook_exit "tracking not enabled (.ref-autotrack not found)"

# Read verbosity config
PROMPTS_VERBOSITY=$(get_config_value "PROMPTS_VERBOSITY" "major")
SOURCES_VERBOSITY=$(get_config_value "SOURCES_VERBOSITY" "all")

# Exit if all tracking is off
[ "$PROMPTS_VERBOSITY" = "off" ] && [ "$SOURCES_VERBOSITY" = "off" ] && hook_exit "all verbosity off"

# Extract transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    hook_exit "no valid transcript: $TRANSCRIPT_PATH"
fi

# Extract latest interaction from transcript
extract_latest_interaction() {
    local transcript="$1"

    # Get last user message
    local last_user=$(grep '"role":"user"' "$transcript" | tail -1 | jq -r '.content // empty')

    # Get last assistant message
    local last_assistant=$(grep '"role":"assistant"' "$transcript" | tail -1 | jq -r '.content // empty')

    # Output as JSON for easier parsing
    jq -n \
        --arg user "$last_user" \
        --arg assistant "$last_assistant" \
        '{user: $user, assistant: $assistant}'
}

# Extract tool uses from last assistant response
extract_tool_uses() {
    local transcript="$1"

    # Get last assistant message (may contain multiple tool uses)
    grep '"role":"assistant"' "$transcript" | tail -1 | \
        jq -r '.tool_uses[]? | @json' 2>/dev/null
}

INTERACTION=$(extract_latest_interaction "$TRANSCRIPT_PATH")
USER_PROMPT=$(echo "$INTERACTION" | jq -r '.user')
ASSISTANT_RESPONSE=$(echo "$INTERACTION" | jq -r '.assistant')

# Skip if no user prompt or empty response
if [ -z "$USER_PROMPT" ] || [ -z "$ASSISTANT_RESPONSE" ]; then
    hook_exit "no user prompt or assistant response in transcript"
fi

# Track prompt-outcome if verbosity allows
if [ "$PROMPTS_VERBOSITY" != "off" ]; then
    # Get tool uses as JSON array
    TOOL_USES=$(extract_tool_uses "$TRANSCRIPT_PATH" | jq -s '.')

    # Try LLM summarization with error capture
    OUTCOME_SUMMARY=$(summarize_outcome "$USER_PROMPT" "$ASSISTANT_RESPONSE" "$TOOL_USES" 2>/tmp/track-llm-error.log)
    LLM_EXIT_CODE=$?

    if [ $LLM_EXIT_CODE -eq 0 ] && [ -n "$OUTCOME_SUMMARY" ]; then
        # Parse LLM output
        OUTCOME_TEXT=$(echo "$OUTCOME_SUMMARY" | sed -n '/^Outcome:/,/^Files:/p' | sed '1d;$d')
        FILES_TEXT=$(extract_field "Files" "$OUTCOME_SUMMARY")
        SIGNIFICANCE=$(extract_field "Significance" "$OUTCOME_SUMMARY")

        # Apply verbosity filter
        SHOULD_TRACK=false
        case "$PROMPTS_VERBOSITY" in
            all)
                SHOULD_TRACK=true
                ;;
            major)
                [ "$SIGNIFICANCE" = "MAJOR" ] && SHOULD_TRACK=true
                ;;
            minimal)
                echo "$USER_PROMPT" | grep -qiE "(track this|log this|save this)" && SHOULD_TRACK=true
                ;;
        esac

        # Write entry
        if [ "$SHOULD_TRACK" = "true" ]; then
            ensure_file_with_preamble "claude_usage/prompts.md" "prompts"
            {
                echo "Prompt: \"$USER_PROMPT\""
                echo "Outcome: $OUTCOME_TEXT"
                [ "$FILES_TEXT" != "NONE" ] && echo "Files: $FILES_TEXT"
                echo "Session: $(get_timestamp)"
                echo ""
            } >> claude_usage/prompts.md
        fi
    fi
fi

# Track tool calls if verbosity allows
if [ "$SOURCES_VERBOSITY" != "off" ]; then
    ensure_file_with_preamble "claude_usage/sources.md" "sources"

    # Associative array for deduplication within this turn
    declare -A seen_tools

    # Process each tool use (use process substitution to avoid subshell)
    while IFS= read -r tool_json; do
        TOOL_NAME=$(echo "$tool_json" | jq -r '.name')
        TOOL_INPUT=$(echo "$tool_json" | jq -r '.input')

        # Only track documentation tools
        case "$TOOL_NAME" in
            WebSearch|WebFetch|Read|Grep)
                # Create deduplication key: tool+params
                DEDUP_KEY="${TOOL_NAME}:$(echo "$TOOL_INPUT" | jq -c -S '.')"

                # Skip if already seen in this turn
                if [ -n "${seen_tools[$DEDUP_KEY]}" ]; then
                    continue
                fi
                seen_tools[$DEDUP_KEY]=1

                # Try LLM summarization with error capture
                TOOL_SUMMARY=$(summarize_tool_call "$TOOL_NAME" "$TOOL_INPUT" "$USER_PROMPT" "$ASSISTANT_RESPONSE" 2>>/tmp/track-llm-error.log)
                TOOL_LLM_EXIT=$?

                if [ $TOOL_LLM_EXIT -eq 0 ] && [ -n "$TOOL_SUMMARY" ]; then
                    # Parse LLM output
                    SUMMARY_TEXT=$(echo "$TOOL_SUMMARY" | sed -n '/^Summary:/,/^Attribution:/p' | sed '1d;$d')
                    ATTRIBUTION=$(extract_field "Attribution" "$TOOL_SUMMARY")
                    LINKS_TEXT=$(extract_field "Links" "$TOOL_SUMMARY")
                    FILES_TEXT=$(extract_field "Files" "$TOOL_SUMMARY")

                    # Format tool call line
                    PARAMS=$(echo "$TOOL_INPUT" | jq -c '.')

                    # Write entry
                    {
                        echo "[$ATTRIBUTION] $TOOL_NAME($PARAMS)"
                        echo "Summary: $SUMMARY_TEXT"
                        [ "$LINKS_TEXT" != "NONE" ] && echo "Links: $LINKS_TEXT"
                        [ "$FILES_TEXT" != "NONE" ] && echo "Files: $FILES_TEXT"
                        echo ""
                    } >> claude_usage/sources.md
                fi
                ;;
        esac
    done < <(extract_tool_uses "$TRANSCRIPT_PATH")
fi

# Output debug message to verify hook execution
TRACKED_PROMPTS=0
TRACKED_SOURCES=0
LLM_STATUS="${LLM_EXIT_CODE:-unknown}"

if [ "$PROMPTS_VERBOSITY" != "off" ] && [ "${SHOULD_TRACK:-false}" = "true" ]; then
    TRACKED_PROMPTS=1
fi

if [ "$SOURCES_VERBOSITY" != "off" ]; then
    # Count tracked sources in this turn
    TRACKED_SOURCES=$(extract_tool_uses "$TRANSCRIPT_PATH" | wc -l)
fi

# Return systemMessage for debugging
jq -n \
    --arg prompts "$TRACKED_PROMPTS" \
    --arg sources "$TRACKED_SOURCES" \
    --arg verbosity "$PROMPTS_VERBOSITY" \
    --arg llm_status "$LLM_STATUS" \
    --arg has_prompt "$([ -n "$USER_PROMPT" ] && echo "yes" || echo "no")" \
    --arg has_response "$([ -n "$ASSISTANT_RESPONSE" ] && echo "yes" || echo "no")" \
    '{
        "systemMessage": "[Track v2.1 Debug] Hook fired | Prompts tracked: \($prompts) | Sources: \($sources) | Verbosity: \($verbosity) | LLM exit: \($llm_status) | Has prompt: \($has_prompt) | Has response: \($has_response)"
    }'

exit 0
