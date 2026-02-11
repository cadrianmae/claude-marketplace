#!/bin/bash
# Stop hook for prompts tracking only
# Tracks conversation outcomes to claude_usage/prompts.md
# Sources tracking handled by capture-sources.sh (PostToolUse hook)

# Helper function to exit with debug message
hook_exit() {
    local reason="$1"
    jq -n --arg reason "$reason" '{
        "systemMessage": "[Track v2.5 Debug] Hook exited early: \($reason)"
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
is_tracking_enabled || hook_exit "tracking not enabled (TRACKING_ENABLED not true in .ref-config)"

# Read verbosity config
PROMPTS_VERBOSITY=$(get_config_value "PROMPTS_VERBOSITY" "major")

# Exit if prompts tracking is off
[ "$PROMPTS_VERBOSITY" = "off" ] && hook_exit "prompts verbosity off"

# Extract or construct transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# If not provided, construct from session_id and cwd
if [ -z "$TRANSCRIPT_PATH" ]; then
    SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
    if [ -n "$SESSION_ID" ] && [ -n "$PROJECT_DIR" ]; then
        # Normalize cwd: /tmp/track-test -> -tmp-track-test
        NORMALIZED_CWD="${PROJECT_DIR//\//-}"
        TRANSCRIPT_PATH="$HOME/.claude/projects/$NORMALIZED_CWD/$SESSION_ID.jsonl"
    fi
fi

# Verify transcript exists
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    hook_exit "no valid transcript: $TRANSCRIPT_PATH"
fi

# Extract latest interaction from transcript
extract_latest_interaction() {
    local transcript="$1"
    local last_user
    local last_assistant

    # Get last user message content from nested structure
    last_user=$(grep '"type":"user"' "$transcript" | tail -1 | jq -r '.message.content // empty')

    # Get last assistant message text from content array
    last_assistant=$(grep '"type":"assistant"' "$transcript" | tail -1 | \
        jq -r '.message.content[] | select(.type == "text") | .text // empty' | head -1)

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
    grep '"type":"assistant"' "$transcript" | tail -1 | \
        jq -r '(.message.content[]? | select(.type == "tool_use")) // .tool_uses[]? | @json' 2>/dev/null
}

INTERACTION=$(extract_latest_interaction "$TRANSCRIPT_PATH")
USER_PROMPT=$(echo "$INTERACTION" | jq -r '.user')
ASSISTANT_RESPONSE=$(echo "$INTERACTION" | jq -r '.assistant')

# Skip if no user prompt or empty response
if [ -z "$USER_PROMPT" ] || [ -z "$ASSISTANT_RESPONSE" ]; then
    hook_exit "no user prompt or assistant response in transcript"
fi

# Get tool uses as JSON array
TOOL_USES=$(extract_tool_uses "$TRANSCRIPT_PATH" | jq -s '.')

# Try LLM summarization with error capture
if OUTCOME_SUMMARY=$(summarize_outcome "$USER_PROMPT" "$ASSISTANT_RESPONSE" "$TOOL_USES" 2>/tmp/track-llm-error.log) && [ -n "$OUTCOME_SUMMARY" ]; then
    # Parse JSON output using jq
    OUTCOME_TEXT=$(echo "$OUTCOME_SUMMARY" | jq -r '.Outcome // empty')
    FILES_TEXT=$(echo "$OUTCOME_SUMMARY" | jq -r '.Files // "NONE"')
    SIGNIFICANCE=$(echo "$OUTCOME_SUMMARY" | jq -r '.Significance // "MINOR"')

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

        # Summarize long prompts (>500 chars = ~1 paragraph)
        if [ ${#USER_PROMPT} -gt 500 ]; then
            if PROMPT_SUMMARY=$(summarize_long_prompt "$USER_PROMPT" 2>>/tmp/track-llm-error.log) && [ -n "$PROMPT_SUMMARY" ]; then
                PROMPT_DISPLAY="$PROMPT_SUMMARY (summarized from ${#USER_PROMPT} chars)"
            else
                # Fallback to verbatim if LLM fails
                PROMPT_DISPLAY="$USER_PROMPT"
            fi
        else
            PROMPT_DISPLAY="$USER_PROMPT"
        fi

        {
            printf "Prompt: \"%s\"\n" "$PROMPT_DISPLAY"
            printf "Outcome: %s\n" "$OUTCOME_TEXT"
            [ "$FILES_TEXT" != "NONE" ] && printf "Files: %s\n" "$FILES_TEXT"
            printf "Session: %s\n" "$(get_timestamp)"
            echo ""
        } >> claude_usage/prompts.md
    fi
fi

# Silent completion - no systemMessage to avoid triggering continuation
jq -n '{
    "suppressOutput": true
}'

exit 0
