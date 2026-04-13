#!/bin/bash
# LLM summarization functions using Claude Haiku with structured outputs

# Ensure plugin data directory exists for error logs
mkdir -p "${CLAUDE_PLUGIN_DATA:-/tmp}" 2>/dev/null

# Summarize outcome for prompts.md using Claude Haiku
summarize_outcome() {
    local prompt="$1"
    local response="$2"
    local tool_uses="$3"  # JSON array of tool uses

    # Check if claude CLI is available
    command -v claude >/dev/null 2>&1 || return 1

    # Build context input
    local context
    context=$(cat <<EOF
Analyze this development interaction and provide a structured summary.

USER PROMPT: "$prompt"

ASSISTANT RESPONSE: "$response"

TOOLS USED: $tool_uses

Summarize what was accomplished, which files were modified, and whether this was major or minor work.
EOF
)

    # Define JSON schema for structured output
    local schema='{
        "type": "object",
        "properties": {
            "Outcome": {
                "type": "string",
                "description": "Brief summary of what was accomplished in 1-2 sentences"
            },
            "Files": {
                "type": "string",
                "description": "Comma-separated list of files modified, or NONE"
            },
            "Significance": {
                "type": "string",
                "enum": ["MAJOR", "MINOR"],
                "description": "MAJOR for features/fixes/multi-step work, MINOR for questions/lookups"
            }
        },
        "required": ["Outcome", "Files", "Significance"],
        "additionalProperties": false
    }'

    # Call Claude with structured output and extract just the structured_output field
    local output
    output=$(echo "$context" | claude --model haiku --print --no-session-persistence --output-format json --json-schema "$schema" 2>>${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log | jq -r '.structured_output // empty')

    # Return output. Optionally also tee to a debug log when TRACK_LLM_DEBUG_LOG
    # is set to a writable path. The previous unconditional append to a fixed
    # /tmp file leaked tracked content to disk and grew unbounded.
    if [ -n "${TRACK_LLM_DEBUG_LOG:-}" ]; then
        printf '%s\n' "$output" | tee -a "$TRACK_LLM_DEBUG_LOG"
    else
        printf '%s\n' "$output"
    fi
}

# Summarize tool call for sources.md using Claude Haiku
summarize_tool_call() {
    local tool_name="$1"
    local tool_input="$2"
    local user_prompt="$3"
    local assistant_response="$4"

    command -v claude >/dev/null 2>&1 || return 1

    # Build context input
    local context
    context=$(cat <<EOF
Analyze this tool call and provide structured information about it.

TOOL USED: $tool_name
TOOL INPUT: $tool_input

CONTEXT:
User: "$user_prompt"
Assistant: "$assistant_response"

Determine who initiated the tool use (USER explicitly asked vs CLAUDE autonomously decided), summarize what was accessed, and extract relevant links/files.
EOF
)

    # Define JSON schema for structured output
    local schema='{
        "type": "object",
        "properties": {
            "Summary": {
                "type": "string",
                "description": "Brief summary of what prompted this tool and how it was used"
            },
            "Attribution": {
                "type": "string",
                "enum": ["USER", "CLAUDE"],
                "description": "USER if user explicitly requested, CLAUDE if autonomously decided"
            },
            "Links": {
                "type": "string",
                "description": "Comma-separated URLs for WebSearch/WebFetch, or NONE"
            },
            "Files": {
                "type": "string",
                "description": "Comma-separated file paths for Read/Grep/Edit, or NONE"
            }
        },
        "required": ["Summary", "Attribution", "Links", "Files"],
        "additionalProperties": false
    }'

    # Call Claude with structured output and extract just the structured_output field
    local output
    output=$(echo "$context" | claude --model haiku --print --no-session-persistence --output-format json --json-schema "$schema" 2>>${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log | jq -r '.structured_output // empty')

    # Return output. Optionally also tee to a debug log when TRACK_LLM_DEBUG_LOG
    # is set to a writable path. The previous unconditional append to a fixed
    # /tmp file leaked tracked content to disk and grew unbounded.
    if [ -n "${TRACK_LLM_DEBUG_LOG:-}" ]; then
        printf '%s\n' "$output" | tee -a "$TRACK_LLM_DEBUG_LOG"
    else
        printf '%s\n' "$output"
    fi
}

# Summarize long user prompts (>500 chars) for prompts.md
summarize_long_prompt() {
    local prompt="$1"

    command -v claude >/dev/null 2>&1 || return 1

    # Build context input
    local context
    context=$(cat <<CONTEXT_EOF
Summarize this user request concisely while preserving key intent and details.

USER PROMPT (${#prompt} chars):
"$prompt"

Create a concise summary (100-150 chars) that captures the core request and important details.
CONTEXT_EOF
)

    # Define JSON schema for structured output
    local schema='{
        "type": "object",
        "properties": {
            "Summary": {
                "type": "string",
                "description": "Concise summary of user request in 100-150 characters"
            }
        },
        "required": ["Summary"],
        "additionalProperties": false
    }'

    # Call Claude with structured output and extract just the Summary field
    local output
    output=$(echo "$context" | claude --model haiku --print --no-session-persistence --output-format json --json-schema "$schema" 2>>${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log | jq -r '.structured_output.Summary // empty')

    # Return output. Optionally also tee to a debug log when TRACK_LLM_DEBUG_LOG
    # is set to a writable path. The previous unconditional append to a fixed
    # /tmp file leaked tracked content to disk and grew unbounded.
    if [ -n "${TRACK_LLM_DEBUG_LOG:-}" ]; then
        printf '%s\n' "$output" | tee -a "$TRACK_LLM_DEBUG_LOG"
    else
        printf '%s\n' "$output"
    fi
}
