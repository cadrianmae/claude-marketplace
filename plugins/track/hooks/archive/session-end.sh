#!/bin/bash
# SessionEnd hook for prompt-outcome pairing
# Reads transcript, pairs prompts with outcomes, writes to claude_usage/prompts.md

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
PROMPTS_VERBOSITY=$(get_config_value "PROMPTS_VERBOSITY" "major")

# Exit if prompts tracking is off
[ "$PROMPTS_VERBOSITY" = "off" ] && exit 0

# Parse hook input JSON from stdin
HOOK_INPUT=$(cat)

# Extract session information
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id // "default"')
transcript_path=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# Check if we have captured prompts for this session
prompts_file=".claude/.track-tmp/${session_id}_prompts.jsonl"
last_prompt_file=".claude/.track-tmp/${session_id}_last_prompt.txt"

# Exit if no prompts captured (backwards compatible check)
[ -f "$prompts_file" ] || [ -f "$last_prompt_file" ] || exit 0

# Ensure file exists with preamble
ensure_file_with_preamble "claude_usage/prompts.md" "prompts"

# Extract all assistant responses from transcript
declare -a assistant_responses=()
if [ -f "$transcript_path" ]; then
    # Read all assistant responses in order
    while IFS= read -r line; do
        if echo "$line" | jq -e '.role == "assistant"' >/dev/null 2>&1; then
            content=$(echo "$line" | jq -r '.content // empty')
            assistant_responses+=("$content")
        fi
    done < "$transcript_path"
fi

# Process all prompts from JSONL file (if exists)
if [ -f "$prompts_file" ]; then
    prompt_index=0
    while IFS= read -r prompt_line; do
        user_prompt=$(echo "$prompt_line" | jq -r '.prompt')

        # Get corresponding assistant response (if available)
        outcome=""
        if [ "$prompt_index" -lt "${#assistant_responses[@]}" ]; then
            outcome="${assistant_responses[$prompt_index]}"
        fi

        # Fallback if no outcome
        if [ -z "$outcome" ]; then
            outcome="Session completed"
        fi

        # Determine if this should be tracked based on verbosity
        should_track=false

        case "$PROMPTS_VERBOSITY" in
            all)
                should_track=true
                ;;
            major)
                # Heuristic: Track if response is substantial (>100 words)
                word_count=$(echo "$outcome" | wc -w)
                if [ "$word_count" -gt 100 ]; then
                    should_track=true
                fi
                ;;
            minimal)
                # Only track if user explicitly said "track this"
                if echo "$user_prompt" | grep -qiE "(track this|log this|save this)"; then
                    should_track=true
                fi
                ;;
        esac

        # Write to claude_usage/prompts.md if should track
        if [ "$should_track" = "true" ]; then
            truncated_outcome=$(truncate_text "$outcome" 200)

            {
                echo "Prompt: \"$user_prompt\""
                echo "Outcome: $truncated_outcome"
                echo "Session: $(get_timestamp)"
                echo ""
            } >> claude_usage/prompts.md
        fi

        ((prompt_index++))
    done < "$prompts_file"
else
    # Fallback: Use old single-prompt behavior for backward compatibility
    if [ -f "$last_prompt_file" ]; then
        user_prompt=$(cat "$last_prompt_file")

        # Get last assistant response
        last_outcome=""
        if [ -f "$transcript_path" ]; then
            last_outcome=$(grep '"role":"assistant"' "$transcript_path" | tail -1 | jq -r '.content // empty' 2>/dev/null)
        fi

        if [ -z "$last_outcome" ]; then
            last_outcome="Session completed"
        fi

        # Apply verbosity filter
        should_track=false
        case "$PROMPTS_VERBOSITY" in
            all)
                should_track=true
                ;;
            major)
                word_count=$(echo "$last_outcome" | wc -w)
                if [ "$word_count" -gt 100 ]; then
                    should_track=true
                fi
                ;;
            minimal)
                if echo "$user_prompt" | grep -qiE "(track this|log this|save this)"; then
                    should_track=true
                fi
                ;;
        esac

        if [ "$should_track" = "true" ]; then
            truncated_outcome=$(truncate_text "$last_outcome" 200)

            {
                echo "Prompt: \"$user_prompt\""
                echo "Outcome: $truncated_outcome"
                echo "Session: $(get_timestamp)"
                echo ""
            } >> claude_usage/prompts.md
        fi
    fi
fi

# Cleanup temp files
rm -f "$prompts_file"
rm -f "$last_prompt_file"
rm -f ".claude/.track-tmp/${session_id}_prompt_time.txt"

# Exit successfully
exit 0
