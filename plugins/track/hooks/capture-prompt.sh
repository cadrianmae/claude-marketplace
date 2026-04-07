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

# Read hook input now so we can derive a per-session debounce key.
# Each Claude session/project gets its own debounce file, so concurrent
# sessions don't suppress each other's tracking during the 5s window.
HOOK_INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false')

# CRITICAL: Prevent infinite loops - skip if hook already ran (before sleep)
[ "$STOP_HOOK_ACTIVE" = "true" ] && hook_exit "stop_hook_active is true"

# Debounce: only the last Stop event in a rapid burst runs the LLM call.
# Scope by session_id (falling back to cwd) so different sessions don't
# clobber each other's debounce file.
DEBOUNCE_KEY_RAW=$(echo "$HOOK_INPUT" | jq -r '.session_id // .cwd // "default"')
DEBOUNCE_KEY=$(printf '%s' "$DEBOUNCE_KEY_RAW" | sha1sum | cut -c1-16)
DEBOUNCE_FILE="/tmp/track-capture-prompt-debounce-${DEBOUNCE_KEY}"
DEBOUNCE_DELAY=5
MY_TIME=$(date +%s%N)
echo "$MY_TIME" > "$DEBOUNCE_FILE"
sleep "$DEBOUNCE_DELAY"
CURRENT_TIME=$(cat "$DEBOUNCE_FILE" 2>/dev/null)
[ "$CURRENT_TIME" != "$MY_TIME" ] && exit 0

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

# Expand $HOME in transcript path if present
TRANSCRIPT_PATH="${TRANSCRIPT_PATH/\$HOME/$HOME}"

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
    local last_assistant_timestamp

    # Get last assistant message with text content
    last_assistant=""
    last_assistant_timestamp=""
    while IFS= read -r line; do
        local text_content
        text_content=$(echo "$line" | jq -r '.message.content[] | select(.type == "text") | .text // empty' 2>/dev/null | head -1)
        if [ -n "$text_content" ]; then
            last_assistant="$text_content"
            last_assistant_timestamp=$(echo "$line" | jq -r '.timestamp // empty')
            break
        fi
    done < <(grep '"type":"assistant"' "$transcript" | tac)

    # Get ALL user messages with text content AFTER the last assistant message
    # (captures consecutive user messages from interruptions)
    local user_messages=()
    while IFS= read -r line; do
        local msg_timestamp
        msg_timestamp=$(echo "$line" | jq -r '.timestamp // empty')

        # Only include messages after the last assistant message
        if [ -n "$last_assistant_timestamp" ] && [ -n "$msg_timestamp" ]; then
            if [[ "$msg_timestamp" > "$last_assistant_timestamp" ]]; then
                if echo "$line" | jq -e '.message.content | type == "string"' >/dev/null 2>&1; then
                    local msg_content
                    msg_content=$(echo "$line" | jq -r '.message.content')
                    user_messages+=("$msg_content")
                fi
            fi
        fi
    done < <(grep '"type":"user"' "$transcript")

    # Concatenate all user messages with " [continued] " separator
    if [ ${#user_messages[@]} -gt 0 ]; then
        last_user=$(IFS=" [continued] "; echo "${user_messages[*]}")
    else
        # Fallback: just get the last user message if no timestamp comparison worked
        while IFS= read -r line; do
            if echo "$line" | jq -e '.message.content | type == "string"' >/dev/null 2>&1; then
                last_user=$(echo "$line" | jq -r '.message.content')
                break
            fi
        done < <(grep '"type":"user"' "$transcript" | tac)
    fi

    # Output as JSON for easier parsing
    jq -n \
        --arg user "$last_user" \
        --arg assistant "$last_assistant" \
        '{user: $user, assistant: $assistant}'
}

# Extract tool uses from last assistant response
extract_tool_uses() {
    local transcript="$1"

    # Get tool uses from recent assistant messages (not just the last one)
    # Look back through last 5 assistant messages to find tools
    grep '"type":"assistant"' "$transcript" | tail -5 | \
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
