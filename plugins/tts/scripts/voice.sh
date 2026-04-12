#!/bin/bash
# Set the default voice. Used by `/tts voice <name>`.
# Called via bin/tts-voice wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ $# -ne 1 ]; then
    echo "Usage: tts-voice <name>" >&2
    echo >&2
    echo "Installed voices:" >&2
    tts_list_voices | sed 's/^/  /' >&2
    exit 1
fi

voice="$1"

if ! tts_voice_file "$voice" >/dev/null; then
    echo "Error: voice '$voice' not found in $(tts_voices_dir)" >&2
    echo >&2
    echo "Installed voices:" >&2
    tts_list_voices | sed 's/^/  /' >&2
    exit 1
fi

tts_write_config VOICE "$voice"
echo "✓ Default voice set to: $voice"
