#!/bin/bash
# View or update audio-feedback config.
# Usage: audio-feedback-config                    - print current config
#        audio-feedback-config KEY=VALUE [...]     - update one or more keys
# Called via bin/audio-feedback-config wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

af_ensure_config
af_load_config

VALID_KEYS="THEME ENABLED CLICKS_ENABLED STOP_SOUND NOTIFICATION_SOUND PRE_COMPACT_SOUND USER_PROMPT_SOUND SESSION_START_SOUND SUBAGENT_STOP_SOUND PRE_TOOL_USE_SOUND POST_TOOL_USE_SOUND"

if [ $# -eq 0 ]; then
    echo "audio-feedback configuration ($(af_config_file)):"
    echo
    echo "  THEME=$AF_THEME"
    echo "  ENABLED=$AF_ENABLED"
    echo "  CLICKS_ENABLED=$AF_CLICKS_ENABLED"
    echo
    echo "  Event sounds (set to 'off' to disable):"
    echo "  STOP_SOUND=$AF_STOP_SOUND"
    echo "  NOTIFICATION_SOUND=$AF_NOTIFICATION_SOUND"
    echo "  PRE_COMPACT_SOUND=$AF_PRE_COMPACT_SOUND"
    echo "  USER_PROMPT_SOUND=$AF_USER_PROMPT_SOUND"
    echo "  SESSION_START_SOUND=$AF_SESSION_START_SOUND"
    echo "  SUBAGENT_STOP_SOUND=$AF_SUBAGENT_STOP_SOUND"
    echo "  PRE_TOOL_USE_SOUND=$AF_PRE_TOOL_USE_SOUND"
    echo "  POST_TOOL_USE_SOUND=$AF_POST_TOOL_USE_SOUND"
    echo
    echo "Available sounds: $(af_list_sounds | tr '\n' ' ')"
    # List available themes (subdirectories of sounds/)
    themes_dir="$(_af_sounds_base)"
    if [ -d "$themes_dir" ]; then
        echo "Available themes: $(find "$themes_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | tr '\n' ' ')"
    fi
    echo "Update with: /audio-feedback config KEY=VALUE"
    exit 0
fi

# Validate and apply
sounds_dir="$(_af_sounds_dir)"
for arg in "$@"; do
    if [[ "$arg" != *=* ]]; then
        echo "Error: '$arg' is not in KEY=VALUE form" >&2
        exit 1
    fi
    key="${arg%%=*}"
    value="${arg#*=}"

    case "$key" in
        THEME)
            themes_dir="$(_af_sounds_base)"
            if [ ! -d "$themes_dir/$value" ]; then
                echo "Error: theme '$value' not found in $themes_dir" >&2
                echo "Available: $(find "$themes_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | tr '\n' ' ')" >&2
                exit 1
            fi
            ;;
        ENABLED|CLICKS_ENABLED)
            case "$value" in
                true|false) ;;
                *)
                    echo "Error: $key must be true|false (got '$value')" >&2
                    exit 1
                    ;;
            esac
            ;;
        STOP_SOUND|NOTIFICATION_SOUND|PRE_COMPACT_SOUND|USER_PROMPT_SOUND|SESSION_START_SOUND|SUBAGENT_STOP_SOUND|PRE_TOOL_USE_SOUND|POST_TOOL_USE_SOUND)
            if [ "$value" != "off" ] && [ ! -f "$sounds_dir/${value}.wav" ]; then
                echo "Error: sound '$value' not found. Use 'off' or one of: $(af_list_sounds | tr '\n' ' ')" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: unknown key '$key'" >&2
            echo "Valid keys: $VALID_KEYS" >&2
            exit 1
            ;;
    esac
    af_write_config "$key" "$value"
    echo "✓ $key=$value"
done
