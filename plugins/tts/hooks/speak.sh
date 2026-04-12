#!/bin/bash
# Stop hook: speak Claude's assistant response.
# Fires via hooks.json on the Stop event.
#
# Reads the hook's JSON stdin to locate the transcript, extracts the
# latest assistant text, and hands it to tts_speak() which handles
# markdown stripping, mode application, piper+paplay pipeline, and
# setsid detach.
#
# Exits silently (0) if tracking is disabled or anything goes wrong.
# Errors go to stderr (visible only in `claude --debug`).

set +e  # never fail the hook — silent is safer than blocking Claude

HOOK_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=../scripts/lib.sh disable=SC1091
source "$HOOK_DIR/../scripts/lib.sh"

tts_load_config
[ "$TTS_ENABLED" = "true" ] || exit 0

# Read the hook JSON input from stdin. Claude Code passes transcript
# metadata here. We need the transcript path to extract the last
# assistant message.
HOOK_JSON="$(cat)"
[ -z "$HOOK_JSON" ] && exit 0

# stop_hook_active guard — prevent infinite loops if the Stop hook
# somehow triggers another Stop.
if printf '%s' "$HOOK_JSON" | grep -q '"stop_hook_active":[[:space:]]*true'; then
    exit 0
fi

# Extract transcript_path. jq is widely available; fall back to sed.
if command -v jq >/dev/null 2>&1; then
    transcript_path="$(printf '%s' "$HOOK_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)"
else
    transcript_path="$(printf '%s' "$HOOK_JSON" \
        | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -1)"
fi

# Expand $HOME if literal
transcript_path="${transcript_path/#\~/$HOME}"
transcript_path="${transcript_path/#\$HOME/$HOME}"

[ -z "$transcript_path" ] && exit 0
[ -f "$transcript_path" ] || exit 0

# Extract the latest assistant message text. Transcript is JSONL, each
# line a message. We want the last "role":"assistant" entry's text
# content, joined across all text blocks.
if ! command -v jq >/dev/null 2>&1; then
    # Without jq we give up silently — jq is effectively required.
    exit 0
fi

latest_text="$(
    tac "$transcript_path" 2>/dev/null \
        | while IFS= read -r line; do
            role="$(printf '%s' "$line" | jq -r '.message.role // empty' 2>/dev/null)"
            [ "$role" = "assistant" ] || continue
            text="$(printf '%s' "$line" | jq -r '
                .message.content
                | if type == "array" then
                    map(select(.type == "text") | .text) | join("\n")
                  elif type == "string" then
                    .
                  else empty end
            ' 2>/dev/null)"
            # Skip assistant messages that are pure tool_use (no text block).
            # Walk back until we find a message that actually has speakable text.
            if [ -n "$text" ]; then
                printf '%s' "$text"
                break
            fi
        done
)"

[ -z "$latest_text" ] && exit 0

tts_speak "$latest_text"
exit 0
