#!/bin/bash
# Toggle or set TTS_ENABLED. Used by `/tts auto [on|off]`.
# Called via bin/tts-auto wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

arg="${1:-}"
tts_ensure_config
tts_load_config

case "$arg" in
    on)  new_state="true" ;;
    off) new_state="false" ;;
    "")
        # Toggle
        if [ "$TTS_ENABLED" = "true" ]; then
            new_state="false"
        else
            new_state="true"
        fi
        ;;
    *)
        echo "Usage: tts-auto [on|off]" >&2
        echo "  No arg toggles the current state." >&2
        exit 1
        ;;
esac

tts_write_config TTS_ENABLED "$new_state"

if [ "$new_state" = "true" ]; then
    echo "✓ tts enabled — Stop hook will speak responses"
    echo
    echo "  Voice:       $TTS_VOICE"
    echo "  Mode:        $TTS_SPEAK_MODE (max $TTS_MAX_CHARS chars)"
    echo "  Volume:      $TTS_VOLUME"
    echo "  Interrupt:   $TTS_INTERRUPT_ON_TYPE"
    echo
    echo "Test with: /tts test"
    echo "Disable with: /tts auto off"
else
    echo "✓ tts disabled — Stop hook is a no-op"
    echo
    echo "Any in-flight speech will play out. To interrupt immediately:"
    echo "  pkill -f 'paplay --raw --format=s16le --rate=22050'"
    echo
    echo "Re-enable with: /tts auto on"
fi
