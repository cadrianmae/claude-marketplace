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

# Check if we have a captured prompt for this session
last_prompt_file=".claude/.track-tmp/${session_id}_last_prompt.txt"
[ -f "$last_prompt_file" ] || exit 0

# Read last captured user prompt
user_prompt=$(cat "$last_prompt_file")

# Get last assistant response from transcript if available
last_outcome=""
if [ -f "$transcript_path" ]; then
    # Parse JSONL transcript to find last assistant message
    # Extract content from last assistant role message
    last_outcome=$(grep '"role":"assistant"' "$transcript_path" | tail -1 | jq -r '.content // empty' 2>/dev/null)
fi

# If no transcript outcome, use generic message
if [ -z "$last_outcome" ]; then
    last_outcome="Session completed"
fi

# Determine if this should be tracked based on verbosity
should_track=false

case "$PROMPTS_VERBOSITY" in
    all)
        should_track=true
        ;;
    major)
        # Heuristic: Track if response is substantial (>100 words)
        word_count=$(echo "$last_outcome" | wc -w)
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
    off)
        should_track=false
        ;;
esac

# Write to claude_usage/prompts.md if should track
if [ "$should_track" = "true" ]; then
    # Ensure file exists with preamble
    ensure_file_with_preamble "claude_usage/prompts.md" "prompts"

    # Truncate outcome to 200 chars if too long
    truncated_outcome=$(truncate_text "$last_outcome" 200)

    # Append prompt-outcome pair with optional session ID
    {
        echo "Prompt: \"$user_prompt\""
        echo "Outcome: $truncated_outcome"
        echo "Session: $(get_timestamp)"
        echo ""
    } >> claude_usage/prompts.md
fi

# Cleanup temp files
rm -f "$last_prompt_file"
rm -f ".claude/.track-tmp/${session_id}_prompt_time.txt"

# Exit successfully
exit 0
