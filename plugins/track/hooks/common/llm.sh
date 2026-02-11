#!/bin/bash
# LLM summarization functions using Claude Haiku

# Summarize outcome for prompts.md using Claude Haiku
summarize_outcome() {
    local prompt="$1"
    local response="$2"
    local tool_uses="$3"  # JSON array of tool uses

    # Check if claude CLI is available
    command -v claude >/dev/null 2>&1 || return 1

    # Read system prompt
    local system_prompt_file="$SCRIPT_DIR/prompts/summarize_outcome.txt"
    [ ! -f "$system_prompt_file" ] && return 1
    local system_prompt=$(cat "$system_prompt_file")

    # Debug: log what we're passing
    echo "[DEBUG] System prompt file: $system_prompt_file" >&2
    echo "[DEBUG] System prompt length: ${#system_prompt}" >&2

    # Build context input using heredoc (safer for quotes)
    local context=$(cat <<EOF
USER PROMPT: "$prompt"

ASSISTANT RESPONSE: "$response"

TOOLS USED: $tool_uses
EOF
)

    # Call Claude with system prompt and context
    local output=$(echo "$context" | claude --model haiku --system-prompt "$system_prompt" 2>>/tmp/track-llm-error.log)
    # Log and return output (tee outputs to both file and stdout)
    echo "$output" | tee -a /tmp/track-llm-output.log
}

# Summarize tool call for sources.md using Claude Haiku
summarize_tool_call() {
    local tool_name="$1"
    local tool_input="$2"
    local user_prompt="$3"
    local assistant_response="$4"

    command -v claude >/dev/null 2>&1 || return 1

    # Read system prompt
    local system_prompt_file="$SCRIPT_DIR/prompts/summarize_tool_call.txt"
    [ ! -f "$system_prompt_file" ] && return 1
    local system_prompt=$(cat "$system_prompt_file")

    # Build context input using heredoc (safer for quotes)
    local context=$(cat <<EOF
TOOL USED: $tool_name
TOOL INPUT: $tool_input

CONTEXT:
User: "$user_prompt"
Assistant: "$assistant_response"
EOF
)

    # Call Claude with system prompt and context
    local output=$(echo "$context" | claude --model haiku --system-prompt "$system_prompt" 2>>/tmp/track-llm-error.log)
    # Log and return output (tee outputs to both file and stdout)
    echo "$output" | tee -a /tmp/track-llm-output.log
}
