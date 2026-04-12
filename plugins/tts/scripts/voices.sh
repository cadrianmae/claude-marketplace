#!/bin/bash
# List installed Piper voices. Used by `/tts voices`.
# Called via bin/tts-voices wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

voices_dir="$(tts_voices_dir)"

if [ ! -d "$voices_dir" ]; then
    echo "No voices directory found at: $voices_dir" >&2
    echo "Install Piper voices there before using tts." >&2
    exit 1
fi

tts_load_config

echo "Installed voices (at $voices_dir):"
echo

while IFS= read -r voice; do
    if [ "$voice" = "$TTS_VOICE" ]; then
        echo "  * $voice  (current default)"
    else
        echo "    $voice"
    fi
done < <(tts_list_voices)

echo
echo "Set default with: /tts voice <name>"
