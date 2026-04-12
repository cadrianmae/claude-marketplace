#!/bin/bash
# Generic hook script for all audio-feedback events.
# Called by hooks.json with the event name as $1:
#   bash ${CLAUDE_PLUGIN_ROOT}/hooks/play-sound.sh stop
#   bash ${CLAUDE_PLUGIN_ROOT}/hooks/play-sound.sh notification
#   etc.
#
# Loads config, resolves the event→sound mapping, plays via paplay.
# Silent no-op if ENABLED=false, sound=off, or file missing.

set +e  # never fail a hook

HOOK_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=../scripts/lib.sh disable=SC1091
source "$HOOK_DIR/../scripts/lib.sh"

EVENT="${1:-}"
[ -z "$EVENT" ] && exit 0

af_play_event "$EVENT"
exit 0
