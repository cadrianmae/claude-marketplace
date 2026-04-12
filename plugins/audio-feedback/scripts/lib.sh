#!/bin/bash
# Shared helpers for the audio-feedback plugin.
# Sourced by hooks/play-sound.sh and scripts/*.sh.

# ---- paths --------------------------------------------------------------

af_config_file() {
    printf '%s' "${HOME}/.claude/.audio-feedback-config"
}

# Resolve the plugin's sounds base directory (contains theme subdirectories).
_af_sounds_base() {
    printf '%s' "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../sounds"
}

# Resolve the active theme's sounds directory.
# Must call af_load_config first so AF_THEME is set.
_af_sounds_dir() {
    printf '%s' "$(_af_sounds_base)/${AF_THEME:-default}"
}

# ---- config -------------------------------------------------------------

# Default sound for each event. "off" = no sound for that event.
# Default theme and per-event sounds. Theme is the subdirectory name
# under sounds/ (e.g. "default"). Sound values are WAV filenames
# (without .wav) inside that theme directory. "off" = no sound.
af_default_theme="default"
af_default_enabled="true"
af_default_stop="stop"
af_default_notification="notification"
af_default_pre_compact="pre-compact"
af_default_user_prompt="user-prompt-submit"
af_default_session_start="off"
af_default_subagent_stop="off"
af_default_pre_tool_use="off"
af_default_post_tool_use="off"

# Load config into shell variables.
#
# shellcheck disable=SC2034  # these vars are consumed by files that source lib.sh
af_load_config() {
    local cfg
    cfg="$(af_config_file)"

    AF_THEME="$af_default_theme"
    AF_ENABLED="$af_default_enabled"
    AF_STOP_SOUND="$af_default_stop"
    AF_NOTIFICATION_SOUND="$af_default_notification"
    AF_PRE_COMPACT_SOUND="$af_default_pre_compact"
    AF_USER_PROMPT_SOUND="$af_default_user_prompt"
    AF_SESSION_START_SOUND="$af_default_session_start"
    AF_SUBAGENT_STOP_SOUND="$af_default_subagent_stop"
    AF_PRE_TOOL_USE_SOUND="$af_default_pre_tool_use"
    AF_POST_TOOL_USE_SOUND="$af_default_post_tool_use"

    [ -f "$cfg" ] || return 0

    local line key value
    while IFS= read -r line; do
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            THEME) AF_THEME="$value" ;;
            ENABLED) AF_ENABLED="$value" ;;
            STOP_SOUND) AF_STOP_SOUND="$value" ;;
            NOTIFICATION_SOUND) AF_NOTIFICATION_SOUND="$value" ;;
            PRE_COMPACT_SOUND) AF_PRE_COMPACT_SOUND="$value" ;;
            USER_PROMPT_SOUND) AF_USER_PROMPT_SOUND="$value" ;;
            SESSION_START_SOUND) AF_SESSION_START_SOUND="$value" ;;
            SUBAGENT_STOP_SOUND) AF_SUBAGENT_STOP_SOUND="$value" ;;
            PRE_TOOL_USE_SOUND) AF_PRE_TOOL_USE_SOUND="$value" ;;
            POST_TOOL_USE_SOUND) AF_POST_TOOL_USE_SOUND="$value" ;;
        esac
    done < "$cfg"
}

# Create config with defaults if missing.
af_ensure_config() {
    local cfg
    cfg="$(af_config_file)"
    [ -f "$cfg" ] && return 0

    mkdir -p "$(dirname "$cfg")"
    cat > "$cfg" <<EOF
THEME=$af_default_theme
ENABLED=$af_default_enabled
STOP_SOUND=$af_default_stop
NOTIFICATION_SOUND=$af_default_notification
PRE_COMPACT_SOUND=$af_default_pre_compact
USER_PROMPT_SOUND=$af_default_user_prompt
SESSION_START_SOUND=$af_default_session_start
SUBAGENT_STOP_SOUND=$af_default_subagent_stop
PRE_TOOL_USE_SOUND=$af_default_pre_tool_use
POST_TOOL_USE_SOUND=$af_default_post_tool_use
EOF
}

# Update a single config key.
af_write_config() {
    local key="$1"
    local value="$2"
    local cfg
    cfg="$(af_config_file)"
    af_ensure_config
    if grep -q "^${key}=" "$cfg"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$cfg"
    else
        printf '%s=%s\n' "$key" "$value" >> "$cfg"
    fi
}

# ---- sounds -------------------------------------------------------------

# List available sound names (one per line).
af_list_sounds() {
    local dir
    dir="$(_af_sounds_dir)"
    [ -d "$dir" ] || return 0
    local f
    for f in "$dir"/*.wav; do
        [ -e "$f" ] || continue
        basename "$f" .wav
    done | sort
}

# Resolve event name to its config variable value.
# Usage: af_sound_for_event "stop" -> prints "soft-chime" (or "off")
af_sound_for_event() {
    local event="$1"
    case "$event" in
        stop)             printf '%s' "$AF_STOP_SOUND" ;;
        notification)     printf '%s' "$AF_NOTIFICATION_SOUND" ;;
        pre_compact)      printf '%s' "$AF_PRE_COMPACT_SOUND" ;;
        user_prompt)      printf '%s' "$AF_USER_PROMPT_SOUND" ;;
        session_start)    printf '%s' "$AF_SESSION_START_SOUND" ;;
        subagent_stop)    printf '%s' "$AF_SUBAGENT_STOP_SOUND" ;;
        pre_tool_use)     printf '%s' "$AF_PRE_TOOL_USE_SOUND" ;;
        post_tool_use)    printf '%s' "$AF_POST_TOOL_USE_SOUND" ;;
        *) printf 'off' ;;
    esac
}

# Play the sound for a given event. Blocks until done.
# Silent no-op if sound is "off" or file is missing.
af_play_event() {
    local event="$1"
    af_load_config
    [ "$AF_ENABLED" = "true" ] || return 0

    local sound
    sound="$(af_sound_for_event "$event")"
    [ "$sound" = "off" ] && return 0

    local sounds_dir
    sounds_dir="$(_af_sounds_dir)"
    local sound_file="$sounds_dir/${sound}.wav"
    [ -f "$sound_file" ] || return 0

    paplay "$sound_file" 2>/dev/null || true
}
