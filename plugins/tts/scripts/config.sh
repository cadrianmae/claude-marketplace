#!/bin/bash
# View or update tts config.
# Usage: tts-config                      - print current config
#        tts-config KEY=VALUE [KEY=VALUE...] - update one or more keys
# Called via bin/tts-config wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

tts_ensure_config
tts_load_config

if [ $# -eq 0 ]; then
    # View mode
    echo "tts configuration ($(tts_config_file)):"
    echo
    echo "  VOICE=$TTS_VOICE"
    echo "  VOLUME=$TTS_VOLUME"
    echo "  SPEAK_MODE=$TTS_SPEAK_MODE"
    echo "  MAX_CHARS=$TTS_MAX_CHARS"
    echo "  TTS_ENABLED=$TTS_ENABLED"
    echo "  INTERRUPT_ON_TYPE=$TTS_INTERRUPT_ON_TYPE"
    echo "  SPEED=$TTS_SPEED"
    echo "  EXPRESSIVENESS=$TTS_EXPRESSIVENESS"
    echo "  PRONUNCIATION_VARIATION=$TTS_PRONUNCIATION_VARIATION"
    echo "  SENTENCE_SILENCE=$TTS_SENTENCE_SILENCE"
    echo "  CHIME_ENABLED=$TTS_CHIME_ENABLED"
    echo "  CHIME_SOUND=$TTS_CHIME_SOUND"
    echo
    echo "Update with: /tts config KEY=VALUE"
    echo "  Speed note: <1.0 = faster, >1.0 = slower (piper's inverted scale)"
    echo "  Chime sounds: $(tts_list_chimes | tr '\n' ' ')"
    exit 0
fi

# Update mode. Validate each arg before applying anything.
declare -a pairs=()
for arg in "$@"; do
    if [[ "$arg" != *=* ]]; then
        echo "Error: '$arg' is not in KEY=VALUE form" >&2
        exit 1
    fi
    key="${arg%%=*}"
    value="${arg#*=}"

    case "$key" in
        VOICE)
            if ! tts_voice_file "$value" >/dev/null; then
                echo "Error: voice '$value' not installed" >&2
                exit 1
            fi
            ;;
        VOLUME)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 0 ] || [ "$value" -gt 65536 ]; then
                echo "Error: VOLUME must be an integer 0-65536 (got '$value')" >&2
                exit 1
            fi
            ;;
        SPEAK_MODE)
            case "$value" in
                full|truncate|summary) ;;
                *)
                    echo "Error: SPEAK_MODE must be full|truncate|summary (got '$value')" >&2
                    exit 1
                    ;;
            esac
            ;;
        MAX_CHARS)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
                echo "Error: MAX_CHARS must be a positive integer (got '$value')" >&2
                exit 1
            fi
            ;;
        TTS_ENABLED|INTERRUPT_ON_TYPE)
            case "$value" in
                true|false) ;;
                *)
                    echo "Error: $key must be true|false (got '$value')" >&2
                    exit 1
                    ;;
            esac
            ;;
        SPEED)
            if ! [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]] || \
               ! awk "BEGIN{exit(!($value >= 0.1 && $value <= 3.0))}"; then
                echo "Error: SPEED must be a float 0.1-3.0 (got '$value'). Note: <1.0 = faster, >1.0 = slower" >&2
                exit 1
            fi
            ;;
        EXPRESSIVENESS)
            if ! [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]] || \
               ! awk "BEGIN{exit(!($value >= 0.0 && $value <= 1.0))}"; then
                echo "Error: EXPRESSIVENESS must be a float 0.0-1.0 (got '$value')" >&2
                exit 1
            fi
            ;;
        PRONUNCIATION_VARIATION)
            if ! [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]] || \
               ! awk "BEGIN{exit(!($value >= 0.0 && $value <= 1.0))}"; then
                echo "Error: PRONUNCIATION_VARIATION must be a float 0.0-1.0 (got '$value')" >&2
                exit 1
            fi
            ;;
        SENTENCE_SILENCE)
            if ! [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]] || \
               ! awk "BEGIN{exit(!($value >= 0.0 && $value <= 5.0))}"; then
                echo "Error: SENTENCE_SILENCE must be a float 0.0-5.0 (got '$value')" >&2
                exit 1
            fi
            ;;
        CHIME_ENABLED)
            case "$value" in
                true|false) ;;
                *)
                    echo "Error: CHIME_ENABLED must be true|false (got '$value')" >&2
                    exit 1
                    ;;
            esac
            ;;
        CHIME_SOUND)
            sounds_dir="$(_tts_sounds_dir)"
            if [ ! -f "$sounds_dir/${value}.wav" ]; then
                echo "Error: sound '$value' not found in $sounds_dir" >&2
                echo "Available: $(tts_list_chimes | tr '\n' ' ')" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: unknown key '$key'" >&2
            echo "Valid keys: VOICE VOLUME SPEAK_MODE MAX_CHARS TTS_ENABLED INTERRUPT_ON_TYPE SPEED EXPRESSIVENESS PRONUNCIATION_VARIATION SENTENCE_SILENCE CHIME_ENABLED CHIME_SOUND" >&2
            exit 1
            ;;
    esac
    pairs+=("$key=$value")
done

# All valid — apply
for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    tts_write_config "$key" "$value"
    echo "✓ $key=$value"
done
