#!/bin/bash
# Generic hook script for all audio-feedback events.
# Called by hooks.json with the event name as $1:
#   bash ${CLAUDE_PLUGIN_ROOT}/hooks/play-sound.sh stop
#   bash ${CLAUDE_PLUGIN_ROOT}/hooks/play-sound.sh notification
#   etc.
#
# Reads stdin JSON to extract subtypes (notification_type, source,
# tool_name, agent_type) and resolves to subtype-specific sounds
# with fallback to the generic event sound.

set +e  # never fail a hook

HOOK_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=../scripts/lib.sh disable=SC1091
source "$HOOK_DIR/../scripts/lib.sh"

EVENT="${1:-}"
[ -z "$EVENT" ] && exit 0

# Read stdin JSON for subtype resolution.
HOOK_JSON="$(cat)"

# Resolve subtype from JSON based on event type.
SUBTYPE=""
if [ -n "$HOOK_JSON" ] && command -v jq >/dev/null 2>&1; then
    case "$EVENT" in
        notification)
            SUBTYPE="$(printf '%s' "$HOOK_JSON" | jq -r '.notification_type // empty' 2>/dev/null)"
            ;;
        session_start)
            SUBTYPE="$(printf '%s' "$HOOK_JSON" | jq -r '.source // empty' 2>/dev/null)"
            ;;
        pre_tool_use|post_tool_use)
            SUBTYPE="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_name // empty' 2>/dev/null)"
            ;;
        subagent_stop)
            SUBTYPE="$(printf '%s' "$HOOK_JSON" | jq -r '.agent_type // empty' 2>/dev/null)"
            ;;
    esac
fi

# Load config for click event checking.
af_load_config

# Extract a token count for click-enabled events.
# - stop:          true output_tokens from last assistant entry in transcript
# - subagent_stop: sum of output_tokens across the subagent's transcript
# - post_tool_use: estimated from tool_response length (chars / 4)
# - notification:  estimated from message length (chars / 4)
# - pre_compact:   fixed sentinel for a consistent "crunching" feel
TOKEN_COUNT=0
if af_clicks_enabled_for "$EVENT" && command -v jq >/dev/null 2>&1; then
    case "$EVENT" in
        stop)
            t_path="$(printf '%s' "$HOOK_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)"
            [ -n "$t_path" ] && TOKEN_COUNT="$(af_tokens_from_transcript "$t_path" last)"
            ;;
        subagent_stop)
            t_path="$(printf '%s' "$HOOK_JSON" | jq -r '.agent_transcript_path // empty' 2>/dev/null)"
            [ -n "$t_path" ] && TOKEN_COUNT="$(af_tokens_from_transcript "$t_path" sum)"
            ;;
        post_tool_use)
            chars="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_response // empty' 2>/dev/null | wc -c)"
            TOKEN_COUNT=$(( chars / 4 ))
            ;;
        notification)
            chars="$(printf '%s' "$HOOK_JSON" | jq -r '.message // empty' 2>/dev/null | wc -c)"
            TOKEN_COUNT=$(( chars / 4 ))
            ;;
        pre_compact)
            TOKEN_COUNT=260
            ;;
    esac
    TOKEN_COUNT="${TOKEN_COUNT//[^0-9]/}"
    [ -z "$TOKEN_COUNT" ] && TOKEN_COUNT=0
fi

# Background the entire sound sequence (event sound + optional clicks)
# and detach, so the hook script returns to Claude Code immediately
# regardless of sox/paplay latency.
{
    af_play_event_with_subtype "$EVENT" "$SUBTYPE"
    if af_clicks_enabled_for "$EVENT" && [ "$TOKEN_COUNT" -gt 0 ] 2>/dev/null; then
        af_play_clicks "$TOKEN_COUNT"
    fi
} </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
