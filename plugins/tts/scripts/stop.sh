#!/bin/bash
# Kill all in-flight tts audio and suppress the next Stop hook speak.
# Used by `/tts stop`. Called via bin/tts-stop wrapper.
#
# The suppress token prevents the Stop hook from immediately speaking
# Claude's "Stopped" response right after we killed speech. The hook
# checks for the token, deletes it, and skips that one cycle.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

tts_kill_inflight

# Drop a one-shot suppress token so the next Stop hook skips speech.
touch /tmp/tts-suppress-next 2>/dev/null || true

echo "✓ Stopped all in-flight tts audio (next response will not be spoken)"
