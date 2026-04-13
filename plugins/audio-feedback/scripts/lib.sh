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
af_default_clicks_enabled="true"
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
    AF_CLICKS_ENABLED="$af_default_clicks_enabled"
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
            CLICKS_ENABLED) AF_CLICKS_ENABLED="$value" ;;
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
CLICKS_ENABLED=$af_default_clicks_enabled
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

# Map a tool_name to its sound group. Used by af_play_event_with_subtype
# to resolve e.g. "Read" -> "observe" so we look for pre-tool-use-observe.wav
# instead of needing a separate file per tool.
_af_tool_group() {
    local tool="$1"
    case "$tool" in
        Bash)                                    printf 'execute' ;;
        Read|Glob|Grep)                          printf 'observe' ;;
        Write|Edit|NotebookEdit)                 printf 'modify' ;;
        WebFetch|WebSearch)                      printf 'network' ;;
        Agent)                                   printf 'dispatch' ;;
        AskUserQuestion|ExitPlanMode)            printf 'interact' ;;
        *)                                       printf '%s' "$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')" ;;
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

# Play with subtype resolution. Tries a subtype-specific sound file first
# (e.g. "notification-permission.wav"), then falls back to the generic
# event sound (e.g. "notification.wav" via config).
#
# Subtype mapping: the hook passes raw subtype values from the JSON
# (e.g. "permission_prompt", "startup"). We normalize to filename form
# by replacing underscores with hyphens: "permission_prompt" -> "permission-prompt".
#
# Resolution order:
# 1. sounds/<theme>/<event>-<normalized-subtype>.wav  (if file exists)
# 2. Config-based generic sound via af_sound_for_event (existing behavior)
af_play_event_with_subtype() {
    local event="$1"
    local subtype="$2"

    af_load_config
    [ "$AF_ENABLED" = "true" ] || return 0

    local sounds_dir
    sounds_dir="$(_af_sounds_dir)"

    # Try subtype-specific file first (if subtype is non-empty).
    if [ -n "$subtype" ]; then
        # Normalize event: underscores -> hyphens, lowercase
        local norm_event norm_subtype
        norm_event="$(printf '%s' "$event" | tr '_' '-' | tr '[:upper:]' '[:lower:]')"

        # For tool events, map tool_name to its group rather than using
        # individual tool names as filenames. This avoids duplicate files.
        if [[ "$event" == pre_tool_use || "$event" == post_tool_use ]]; then
            norm_subtype="$(_af_tool_group "$subtype")"
        else
            norm_subtype="$(printf '%s' "$subtype" | tr '_' '-' | tr '[:upper:]' '[:lower:]')"
        fi

        local subtype_file="$sounds_dir/${norm_event}-${norm_subtype}.wav"
        if [ -f "$subtype_file" ]; then
            paplay "$subtype_file" 2>/dev/null || true
            return 0
        fi
    fi

    # Fall back to generic event sound from config.
    local sound
    sound="$(af_sound_for_event "$event")"
    [ "$sound" = "off" ] && return 0

    local sound_file="$sounds_dir/${sound}.wav"
    [ -f "$sound_file" ] || return 0

    paplay "$sound_file" 2>/dev/null || true
}

# ---- click sounds -------------------------------------------------------

# Generate and play an ease-out click sequence proportional to word count.
# Sound: glassy tri-tone (lo/hi/shimmer sines) + filtered noise friction
# + impulse transient + reverb. Inspired by Elite Dangerous station UI.
#
# Scaling: 13 clicks/sec starting rate, ease-out curve (quadratic
# deceleration). Duration is logarithmic from word count, clamped
# to [0.3, 1.5].
#
# Usage: af_play_clicks <word_count>
af_play_clicks() {
    local words="${1:-0}"
    [ "$words" -le 0 ] 2>/dev/null && return 0
    [ "$AF_CLICKS_ENABLED" = "true" ] || return 0
    command -v sox >/dev/null 2>&1 || return 0

    # Logarithmic duration scaling from word count.
    local max_dur
    max_dur="$(awk -v w="$words" 'BEGIN {
        d = log(w / 5) / log(2) * 0.3 + 0.3
        if (d < 0.3) d = 0.3
        if (d > 1.5) d = 1.5
        printf "%.2f", d
    }')"

    # Click sound parameters.
    local click_dur="0.02"
    local start_rate=13
    local base_gap
    base_gap="$(awk -v r="$start_rate" -v cd="$click_dur" 'BEGIN {
        g = 1/r - cd
        if (g < 0.001) g = 0.001
        printf "%.4f", g
    }')"

    local tmpdir
    tmpdir="$(mktemp -d)"

    local t=0 i=0
    local lo_freq hi_freq sh_freq gap d

    while (( $(awk -v t="$t" -v m="$max_dur" 'BEGIN { print (t < m) ? 1 : 0 }') )); do
        # Random frequency variation per click.
        lo_freq=$(( 5050 + RANDOM % 301 - 150 ))
        hi_freq=$(( 10000 + RANDOM % 501 - 250 ))
        sh_freq=$(( 3500 + RANDOM % 401 - 200 ))

        # Ease-out: gap grows quadratically with elapsed time.
        gap="$(awk -v bg="$base_gap" -v t="$t" -v m="$max_dur" 'BEGIN {
            ratio = t / m
            g = bg * (1 + ratio * ratio * 4)
            printf "%.4f", g
        }')"

        d="$tmpdir/c$(printf '%03d' "$i")"

        # Lo tone (5050 Hz base, slow decay).
        sox -n -r 44100 -c 1 "${d}_lo.wav" \
            synth "$click_dur" sine "$lo_freq" \
            fade q 0.0002 "$click_dur" 0.015 \
            vol 0.02 2>/dev/null

        # Hi tone (10000 Hz base, faster decay).
        sox -n -r 44100 -c 1 "${d}_hi.wav" \
            synth "$click_dur" sine "$hi_freq" \
            fade q 0.0002 "$click_dur" 0.008 \
            vol 0.015 2>/dev/null

        # Shimmer tone (3500 Hz base).
        sox -n -r 44100 -c 1 "${d}_sh.wav" \
            synth "$click_dur" sine "$sh_freq" \
            fade q 0.0002 "$click_dur" 0.006 \
            vol 0.012 2>/dev/null

        # Friction (filtered noise).
        sox -n -r 44100 -c 1 "${d}_n.wav" \
            synth "$click_dur" noise \
            fade q 0.0002 "$click_dur" 0.010 \
            vol 0.025 2>/dev/null

        # Impulse transient (short noise burst).
        sox -n -r 44100 -c 1 "${d}_i.wav" \
            synth 0.002 noise \
            fade q 0 0.002 0.001 \
            vol 0.015 \
            pad 0 0.018 2>/dev/null

        # Mix all layers, pad with gap.
        sox -m "${d}_lo.wav" "${d}_hi.wav" "${d}_sh.wav" "${d}_n.wav" "${d}_i.wav" "${d}.wav" \
            pad 0 "$gap" 2>/dev/null

        t="$(awk -v t="$t" -v cd="$click_dur" -v g="$gap" 'BEGIN { printf "%.4f", t + cd + g }')"
        i=$((i + 1))
    done

    # Concatenate all clicks, apply reverb over the whole sequence, play.
    if [ "$i" -gt 0 ]; then
        sox "$tmpdir"/c???.wav "$tmpdir/full.wav" 2>/dev/null
        sox "$tmpdir/full.wav" -t wav - reverb 40 50 80 2>/dev/null | paplay 2>/dev/null || true
    fi

    rm -rf "$tmpdir"
}
