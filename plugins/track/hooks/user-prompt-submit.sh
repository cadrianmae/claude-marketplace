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
echo "$user_prompt" > ".claude/.track-tmp/${session_id}_last_prompt.txt"

# Store timestamp for attribution logic
echo "$(date +%s)" > ".claude/.track-tmp/${session_id}_prompt_time.txt"

# Exit successfully
exit 0
