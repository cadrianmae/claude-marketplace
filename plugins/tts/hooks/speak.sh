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

# Check for one-shot suppress token from /tts stop. If present, consume
# it and skip this cycle (no chime, no speech). The token is a single-use
# flag: delete it so the NEXT response speaks normally.
if [ -f /tmp/tts-suppress-next ]; then
    rm -f /tmp/tts-suppress-next
    exit 0
fi

# Play chime before speech (blocks until done so chime finishes first).
tts_play_chime

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

# Extract all assistant text from the current turn.
#
# A single agent turn can span many JSONL lines: text → thinking → tool_use
# → tool_result → more text → another tool_use → final text. We want to
# speak EVERYTHING the assistant actually said in text form during the
# current turn, concatenated in order.
#
# Subtlety: role="user" in the transcript is NOT just the human user. It
# also includes tool_result messages (wrapped as user role because that's
# how the API models tool responses). A real human user message has
# content that is either a plain string OR an array containing a text
# block. Tool results have arrays containing tool_result blocks.
#
# Strategy: find the index of the most recent REAL user message, then
# collect text blocks from every assistant message that comes after it.
# Pure thinking or tool_use messages contribute nothing and are skipped.
latest_text="$(
    jq -rs '
        def is_real_user:
            .message.role == "user"
            and (.message.content
                 | if type == "string" then true
                   elif type == "array" then (map(.type) | any(. == "text"))
                   else false end);

        (map(is_real_user) | length - 1 - (reverse | index(true) // length)) as $idx
        | .[$idx + 1:]
        | map(select(.message.role == "assistant"))
        | map(.message.content
            | if type == "array" then
                map(select(.type == "text") | .text) | join("\n")
              elif type == "string" then
                .
              else empty end)
        | map(select(length > 0))
        | join("\n\n")
    ' "$transcript_path" 2>/dev/null
)"

[ -z "$latest_text" ] && exit 0

tts_speak "$latest_text"
exit 0
