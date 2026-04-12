#!/bin/bash
# UserPromptSubmit hook: kill any in-flight tts speech.
# Fires via hooks.json on the UserPromptSubmit event.
#
# Silent no-op when INTERRUPT_ON_TYPE=false or when no paplay is running.
# Exits 0 unconditionally — this hook must never block a user prompt.

set +e

HOOK_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=scripts/lib.sh
source "$HOOK_DIR/../scripts/lib.sh"

tts_load_config
[ "$TTS_ENABLED" = "true" ] || exit 0
[ "$TTS_INTERRUPT_ON_TYPE" = "true" ] || exit 0

tts_kill_inflight
exit 0
