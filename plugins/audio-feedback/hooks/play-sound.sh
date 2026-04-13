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

# Events that support click sounds: extract word count from response text.
WORD_COUNT=0
if command -v jq >/dev/null 2>&1; then
    case "$EVENT" in
        stop)
            WORD_COUNT="$(printf '%s' "$HOOK_JSON" | jq -r '.assistant_message // empty' 2>/dev/null | wc -w)"
            ;;
        post_tool_use)
            WORD_COUNT="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_response // empty' 2>/dev/null | wc -w)"
            ;;
        subagent_stop)
            WORD_COUNT="$(printf '%s' "$HOOK_JSON" | jq -r '.result // empty' 2>/dev/null | wc -w)"
            ;;
    esac
fi
WORD_COUNT="${WORD_COUNT##* }"  # trim whitespace from wc output

# For click-enabled events, background the entire sound sequence
# (event sound then clicks) so the hook returns instantly.
case "$EVENT" in
    stop|post_tool_use|subagent_stop)
        {
            af_play_event_with_subtype "$EVENT" "$SUBTYPE"
            af_play_clicks "$WORD_COUNT"
        } &
        ;;
    *)
        af_play_event_with_subtype "$EVENT" "$SUBTYPE"
        ;;
esac

exit 0
