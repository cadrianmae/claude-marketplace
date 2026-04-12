#!/bin/bash
# List installed Piper voices. Used by `/tts voices`.
# Called via bin/tts-voices wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

voices_dir="$(tts_voices_dir)"

if [ ! -d "$voices_dir" ]; then
    echo "No voices directory found at: $voices_dir" >&2
    echo "Install Piper voices there before using tts." >&2
    exit 1
fi

tts_load_config

# Split TTS_VOICE into base name and optional speaker for display.
# e.g. "semaine:poppy" -> base="semaine", speaker="poppy"
#      "aru"           -> base="aru",     speaker=""
current_voice_base="${TTS_VOICE%%:*}"
current_voice_speaker=""
if [[ "$TTS_VOICE" == *:* ]]; then
    current_voice_speaker="${TTS_VOICE##*:}"
fi

echo "Installed voices (at $voices_dir):"
echo

while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Extract just the voice name (before any " (speakers:" annotation)
    # so we can compare against the current default's base name.
    list_voice_base="${line%% *}"
    if [ "$list_voice_base" = "$current_voice_base" ]; then
        if [ -n "$current_voice_speaker" ]; then
            echo "  * $line  (current default: $current_voice_speaker)"
        else
            echo "  * $line  (current default)"
        fi
    else
        echo "    $line"
    fi
done < <(tts_list_voices)

echo
echo "Set default with:"
echo "  /tts voice <name>                    (single-speaker, e.g. /tts voice lessac)"
echo "  /tts voice <name>:<speaker>          (multi-speaker, e.g. /tts voice semaine:poppy)"
