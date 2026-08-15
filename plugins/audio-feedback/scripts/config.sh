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

VALID_KEYS="THEME ENABLED DAEMON_ENABLED DAEMON_IDLE_TIMEOUT DAEMON_MAX_VOICES SUBAGENT_ACCENT VOLUME STOP_SOUND NOTIFICATION_SOUND PRE_COMPACT_SOUND USER_PROMPT_SOUND SESSION_START_SOUND SUBAGENT_STOP_SOUND PRE_TOOL_USE_SOUND POST_TOOL_USE_SOUND"

if [ $# -eq 0 ]; then
    echo "audio-feedback configuration ($(af_config_file)):"
    echo
    echo "  THEME=$AF_THEME"
    echo "  ENABLED=$AF_ENABLED"
    echo "  DAEMON_ENABLED=$AF_DAEMON_ENABLED"
    echo "  DAEMON_IDLE_TIMEOUT=$AF_DAEMON_IDLE_TIMEOUT"
    echo "  DAEMON_MAX_VOICES=$AF_DAEMON_MAX_VOICES"
    echo "  SUBAGENT_ACCENT=$AF_SUBAGENT_ACCENT"
    echo "  VOLUME=$AF_VOLUME"
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
    echo "Available themes: $(af_list_themes | tr '\n' ' ')"
    echo "Update with: /audio-feedback config KEY=VALUE"
    exit 0
fi

# Validate and apply
for arg in "$@"; do
    if [[ "$arg" != *=* ]]; then
        echo "Error: '$arg' is not in KEY=VALUE form" >&2
        exit 1
    fi
    key="${arg%%=*}"
    value="${arg#*=}"

    case "$key" in
        THEME)
            if [ ! -f "$(_af_sounds_base)/$value/theme.json" ]; then
                echo "Error: theme '$value' not found. Available: $(af_list_themes | tr '\n' ' ')" >&2
                exit 1
            fi
            ;;
        ENABLED|DAEMON_ENABLED|SUBAGENT_ACCENT)
            case "$value" in
                true|false) ;;
                *)
                    echo "Error: $key must be true|false (got '$value')" >&2
                    exit 1
                    ;;
            esac
            ;;
        DAEMON_IDLE_TIMEOUT|DAEMON_MAX_VOICES)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
                echo "Error: $key must be a positive integer (got '$value')" >&2
                exit 1
            fi
            ;;
        VOLUME)
            if ! [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] \
               || ! awk -v v="$value" 'BEGIN{exit !(v>=0 && v<=1)}'; then
                echo "Error: VOLUME must be a number 0.0-1.0 (got '$value')" >&2
                exit 1
            fi
            ;;
        STOP_SOUND|NOTIFICATION_SOUND|PRE_COMPACT_SOUND|USER_PROMPT_SOUND|SESSION_START_SOUND|SUBAGENT_STOP_SOUND|PRE_TOOL_USE_SOUND|POST_TOOL_USE_SOUND)
            # recompute per-arg: a THEME= set earlier in this same invocation
            # has already been persisted, so validate against the pending theme
            sounds_dir="$(_af_sounds_dir)"
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
