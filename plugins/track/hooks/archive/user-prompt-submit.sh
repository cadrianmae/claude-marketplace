#!/bin/bash
# UserPromptSubmit hook for prompt capture
# Captures user prompts to temporary storage for later pairing with outcomes

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

# Extract user prompt and session ID
user_prompt=$(echo "$HOOK_INPUT" | jq -r '.prompt // .message // empty')
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id // "default"')

# Skip if no prompt
[ -z "$user_prompt" ] && exit 0

# Store in temporary file for SessionEnd processing
# Use session_id to avoid conflicts between concurrent sessions
mkdir -p .claude/.track-tmp

# Append prompt to JSONL file (one prompt per line)
# This captures ALL prompts during session, not just the last one
prompt_file=".claude/.track-tmp/${session_id}_prompts.jsonl"
timestamp=$(date +%s)

# Get next sequence number (count existing lines)
sequence=0
if [ -f "$prompt_file" ]; then
    sequence=$(wc -l < "$prompt_file")
fi

# Append prompt as compact JSON object (JSONL format - one line per entry)
jq -nc \
    --arg prompt "$user_prompt" \
    --argjson timestamp "$timestamp" \
    --argjson sequence "$sequence" \
    '{timestamp: $timestamp, sequence: $sequence, prompt: $prompt}' >> "$prompt_file"

# Also keep last_prompt.txt for backward compatibility with SessionEnd
echo "$user_prompt" > ".claude/.track-tmp/${session_id}_last_prompt.txt"
echo "$timestamp" > ".claude/.track-tmp/${session_id}_prompt_time.txt"

# Exit successfully
exit 0
