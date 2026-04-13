#!/bin/bash
# Shared helpers for the tts plugin.
# Sourced by every script in scripts/ — contains no top-level side effects
# EXCEPT the LD_LIBRARY_PATH setup for NVIDIA CUDA libraries below.
#
# Exposed functions:
#   tts_config_file            - path to ~/.claude/.tts-config
#   tts_voices_dir             - path to ~/.local/share/piper-voices
#   tts_load_config            - load config into TTS_* shell vars (with defaults)
#   tts_ensure_config          - create config file with defaults if missing
#   tts_write_config KEY VALUE - set or update a single key (preserves others)
#   tts_list_voices            - print short voice names (one per line) from disk
#   tts_voice_file NAME        - resolve short name to absolute .onnx path
#   tts_strip_markdown         - read stdin, write plain text to stdout
#   tts_speak TEXT             - fire-and-forget: strip, truncate, piper, paplay, detach
#   tts_kill_inflight          - kill any in-flight tts paplay

# ---- NVIDIA CUDA library path setup --------------------------------------
#
# onnxruntime-gpu needs CUDA libraries (cublas, cudnn, curand, cufft,
# cudart) on LD_LIBRARY_PATH. When installed via pip (nvidia-cublas-cu12
# etc.), these live in ~/.local/lib/pythonX.Y/site-packages/nvidia/*/lib/.
# Discover and prepend them automatically so piper --cuda works without
# manual LD_LIBRARY_PATH setup in the user's shell or the hook runner.
_tts_nvidia_lib_root="${HOME}/.local/lib/python$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)/site-packages/nvidia"
if [ -d "$_tts_nvidia_lib_root" ]; then
    _tts_nv_paths=""
    for _tts_nv_dir in "$_tts_nvidia_lib_root"/*/lib; do
        [ -d "$_tts_nv_dir" ] && _tts_nv_paths="${_tts_nv_paths:+$_tts_nv_paths:}$_tts_nv_dir"
    done
    if [ -n "$_tts_nv_paths" ]; then
        export LD_LIBRARY_PATH="${_tts_nv_paths}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
    unset _tts_nv_paths _tts_nv_dir
fi
unset _tts_nvidia_lib_root

# ---- paths --------------------------------------------------------------

tts_config_file() {
    printf '%s' "${HOME}/.claude/.tts-config"
}

tts_voices_dir() {
    printf '%s' "${HOME}/.local/share/piper-voices"
}

# Resolve the plugin's bundled sounds/ directory via this script's location.
_tts_sounds_dir() {
    printf '%s' "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../sounds"
}

# ---- config -------------------------------------------------------------

# Default values for every known config key. Used when loading from a
# file that has missing keys, and when creating a fresh config.
tts_default_voice="aru"
tts_default_volume="40000"
tts_default_speak_mode="truncate"
tts_default_max_chars="1000"
tts_default_enabled="false"
tts_default_interrupt="true"
tts_default_speed="1.0"
tts_default_expressiveness="0.667"
tts_default_pronunciation_variation="0.8"
tts_default_sentence_silence="0.0"
tts_default_chime_enabled="true"
tts_default_chime_sound="soft-chime"

# Load config into shell variables. Missing keys fall back to defaults.
# Sets: TTS_VOICE, TTS_VOLUME, TTS_SPEAK_MODE, TTS_MAX_CHARS,
#       TTS_ENABLED, TTS_INTERRUPT_ON_TYPE, TTS_SPEED,
#       TTS_EXPRESSIVENESS, TTS_PRONUNCIATION_VARIATION, TTS_SENTENCE_SILENCE,
#       TTS_CHIME_ENABLED, TTS_CHIME_SOUND
#
# shellcheck disable=SC2034  # these vars are consumed by files that source lib.sh
tts_load_config() {
    local cfg
    cfg="$(tts_config_file)"

    TTS_VOICE="$tts_default_voice"
    TTS_VOLUME="$tts_default_volume"
    TTS_SPEAK_MODE="$tts_default_speak_mode"
    TTS_MAX_CHARS="$tts_default_max_chars"
    TTS_ENABLED="$tts_default_enabled"
    TTS_INTERRUPT_ON_TYPE="$tts_default_interrupt"
    TTS_SPEED="$tts_default_speed"
    TTS_EXPRESSIVENESS="$tts_default_expressiveness"
    TTS_PRONUNCIATION_VARIATION="$tts_default_pronunciation_variation"
    TTS_SENTENCE_SILENCE="$tts_default_sentence_silence"
    TTS_CHIME_ENABLED="$tts_default_chime_enabled"
    TTS_CHIME_SOUND="$tts_default_chime_sound"

    [ -f "$cfg" ] || return 0

    local line key value
    while IFS= read -r line; do
        # Skip blank lines and comments
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            VOICE) TTS_VOICE="$value" ;;
            VOLUME) TTS_VOLUME="$value" ;;
            SPEAK_MODE) TTS_SPEAK_MODE="$value" ;;
            MAX_CHARS) TTS_MAX_CHARS="$value" ;;
            TTS_ENABLED) TTS_ENABLED="$value" ;;
            INTERRUPT_ON_TYPE) TTS_INTERRUPT_ON_TYPE="$value" ;;
            SPEED) TTS_SPEED="$value" ;;
            EXPRESSIVENESS) TTS_EXPRESSIVENESS="$value" ;;
            PRONUNCIATION_VARIATION) TTS_PRONUNCIATION_VARIATION="$value" ;;
            SENTENCE_SILENCE) TTS_SENTENCE_SILENCE="$value" ;;
            CHIME_ENABLED) TTS_CHIME_ENABLED="$value" ;;
            CHIME_SOUND) TTS_CHIME_SOUND="$value" ;;
        esac
    done < "$cfg"
}

# Create the config file with defaults if it does not exist yet.
tts_ensure_config() {
    local cfg
    cfg="$(tts_config_file)"
    [ -f "$cfg" ] && return 0

    mkdir -p "$(dirname "$cfg")"
    cat > "$cfg" <<EOF
VOICE=$tts_default_voice
VOLUME=$tts_default_volume
SPEAK_MODE=$tts_default_speak_mode
MAX_CHARS=$tts_default_max_chars
TTS_ENABLED=$tts_default_enabled
INTERRUPT_ON_TYPE=$tts_default_interrupt
SPEED=$tts_default_speed
EXPRESSIVENESS=$tts_default_expressiveness
PRONUNCIATION_VARIATION=$tts_default_pronunciation_variation
SENTENCE_SILENCE=$tts_default_sentence_silence
CHIME_ENABLED=$tts_default_chime_enabled
CHIME_SOUND=$tts_default_chime_sound
EOF
}

# Set or update a single key in the config file, preserving all other keys.
# Creates the config file first if needed.
tts_write_config() {
    local key="$1"
    local value="$2"
    local cfg
    cfg="$(tts_config_file)"
    tts_ensure_config
    if grep -q "^${key}=" "$cfg"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$cfg"
    else
        printf '%s=%s\n' "$key" "$value" >> "$cfg"
    fi
}

# ---- voices -------------------------------------------------------------

# Strip .onnx filename to a short voice name.
# "en_GB-aru-medium.onnx" -> "aru"
# "glados_piper_medium.onnx" -> "glados"
_tts_short_name() {
    local name="$1"
    name="${name#en_GB-}"
    name="${name#en_US-}"
    name="${name%-medium}"
    name="${name%-low}"
    name="${name%-high}"
    name="${name%_piper_medium}"
    name="${name%_piper_low}"
    name="${name%_piper_high}"
    printf '%s' "$name"
}

# Print installed voice names, one per line, alphabetically sorted.
# Multi-speaker voices are annotated with their speaker names in order:
#   semaine (speakers: prudence, spike, obadiah, poppy)
tts_list_voices() {
    local dir
    dir="$(tts_voices_dir)"
    [ -d "$dir" ] || return 0

    # Build tab-separated (short_name, onnx_path) pairs, sorted by short_name.
    local pairs
    pairs="$(
        local f name
        for f in "$dir"/*.onnx; do
            [ -e "$f" ] || continue
            name="$(_tts_short_name "$(basename "$f" .onnx)")"
            printf '%s\t%s\n' "$name" "$f"
        done | sort
    )"

    # Emit each with optional speaker annotation.
    while IFS=$'\t' read -r name onnx_path; do
        [ -z "$name" ] && continue
        local json_file="${onnx_path%.onnx}.onnx.json"
        local speakers=""
        if [ -f "$json_file" ] && command -v jq >/dev/null 2>&1; then
            speakers="$(jq -r '
                .speaker_id_map
                | if . then
                    to_entries | sort_by(.value) | map(.key) | join(", ")
                  else empty end
            ' "$json_file" 2>/dev/null)"
        fi
        if [ -n "$speakers" ]; then
            printf '%s (speakers: %s)\n' "$name" "$speakers"
        else
            printf '%s\n' "$name"
        fi
    done <<< "$pairs"
}

# Resolve a voice name (with optional :speaker suffix) to an absolute
# .onnx path plus an optional speaker id.
#
# Input forms:
#   "aru"              -> single-speaker voice, no speaker id
#   "semaine"          -> multi-speaker voice, no speaker id (piper uses 0)
#   "semaine:prudence" -> multi-speaker voice, speaker id 0
#   "semaine:0"        -> multi-speaker voice, speaker id 0 (integer form)
#
# Sets these globals on success:
#   TTS_RESOLVED_FILE     - absolute .onnx path
#   TTS_RESOLVED_SPEAKER  - integer speaker id, or empty string
#
# Returns 0 on success (voice exists, speaker valid if given), 1 otherwise.
#
# shellcheck disable=SC2034  # TTS_RESOLVED_* are consumed by callers that source lib.sh
tts_resolve_voice() {
    local want="$1"
    local voice_part speaker_part

    TTS_RESOLVED_FILE=""
    TTS_RESOLVED_SPEAKER=""

    if [[ "$want" == *:* ]]; then
        voice_part="${want%%:*}"
        speaker_part="${want##*:}"
    else
        voice_part="$want"
        speaker_part=""
    fi

    # Find voice file by short name.
    local dir
    dir="$(tts_voices_dir)"
    [ -d "$dir" ] || return 1

    local f name
    for f in "$dir"/*.onnx; do
        [ -e "$f" ] || continue
        name="$(_tts_short_name "$(basename "$f" .onnx)")"
        if [ "$name" = "$voice_part" ]; then
            TTS_RESOLVED_FILE="$f"
            break
        fi
    done

    [ -z "$TTS_RESOLVED_FILE" ] && return 1

    # No speaker requested — done. (Piper uses speaker 0 by default
    # for multi-speaker models.)
    [ -z "$speaker_part" ] && return 0

    # Speaker requested — need the companion .onnx.json + jq.
    local json_file="${TTS_RESOLVED_FILE%.onnx}.onnx.json"
    if [ ! -f "$json_file" ] || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    # Does this voice even have a speaker map?
    local has_map
    has_map="$(jq -r '.speaker_id_map | if . then "yes" else "no" end' "$json_file" 2>/dev/null)"
    [ "$has_map" != "yes" ] && return 1

    # Resolve speaker: integer → verify in range; name → look up.
    local id
    if [[ "$speaker_part" =~ ^[0-9]+$ ]]; then
        id="$(jq -r --argjson n "$speaker_part" '
            .speaker_id_map
            | to_entries
            | map(.value)
            | if any(. == $n) then ($n | tostring) else empty end
        ' "$json_file" 2>/dev/null)"
    else
        id="$(jq -r --arg n "$speaker_part" '.speaker_id_map[$n] // empty' "$json_file" 2>/dev/null)"
    fi

    [ -z "$id" ] && return 1
    TTS_RESOLVED_SPEAKER="$id"
    return 0
}

# Backwards-compat wrapper: return only the file path for a voice name.
# Used by callers that don't care about speaker resolution.
tts_voice_file() {
    tts_resolve_voice "$1" || return 1
    printf '%s' "$TTS_RESOLVED_FILE"
}

# ---- markdown stripping -------------------------------------------------

# Read stdin, write plain text to stdout. Uses pandoc if available (cleaner
# output); falls back to a minimal sed pipeline otherwise. Always removes
# fenced code blocks before anything else.
tts_strip_markdown() {
    # Remove fenced code blocks first (```...``` and ~~~...~~~).
    # Done with awk so we can handle multi-line blocks regardless of tool.
    awk '
        /^```/ { in_fence = !in_fence; next }
        /^~~~/ { in_fence = !in_fence; next }
        !in_fence { print }
    ' | {
        if command -v pandoc >/dev/null 2>&1; then
            pandoc -f markdown -t plain 2>/dev/null
        else
            # Fallback: strip inline code, emphasis, headings, link wrappers.
            # Single-quoted sed patterns are intentional — these are literal
            # regex expressions, not shell variables.
            # shellcheck disable=SC2016
            sed -e 's/`\([^`]*\)`/\1/g' \
                -e 's/\*\*\([^*]*\)\*\*/\1/g' \
                -e 's/\*\([^*]*\)\*/\1/g' \
                -e 's/_\([^_]*\)_/\1/g' \
                -e 's/^#\{1,6\} //' \
                -e 's/\[\([^]]*\)\](\([^)]*\))/\1/g'
        fi
    }
}

# ---- speak --------------------------------------------------------------

# Fire-and-forget speak. Takes text on stdin OR as $1.
# Reads current config, strips markdown, applies SPEAK_MODE + MAX_CHARS,
# pipes through piper, plays via paplay, detaches via setsid.
#
# This function returns immediately; audio plays in the background.
# Errors go to stderr (visible only in `claude --debug`).
tts_speak() {
    tts_load_config

    local text
    if [ $# -ge 1 ]; then
        text="$1"
    else
        text="$(cat)"
    fi

    [ -z "$text" ] && return 0

    if ! tts_resolve_voice "$TTS_VOICE"; then
        echo "tts: voice '$TTS_VOICE' not found or has no such speaker" >&2
        return 1
    fi
    local voice_file="$TTS_RESOLVED_FILE"
    local speaker_id="$TTS_RESOLVED_SPEAKER"

    # Apply speak mode. 'full' is a no-op. 'truncate' and 'summary' are
    # both capped at MAX_CHARS. 'summary' falls back to truncate silently
    # if the Haiku call fails.
    local processed
    processed="$(printf '%s' "$text" | tts_strip_markdown)"

    case "$TTS_SPEAK_MODE" in
        full)
            : # keep full processed text
            ;;
        summary)
            if [ "${#processed}" -gt "$TTS_MAX_CHARS" ]; then
                # Only summarise if text exceeds the limit.
                local summary
                if summary="$(tts_summarize "$processed" "$TTS_MAX_CHARS" 2>/dev/null)" && [ -n "$summary" ]; then
                    processed="$summary"
                else
                    # Summarize failed — fall through to truncate.
                    processed="${processed:0:$TTS_MAX_CHARS}…"
                fi
            fi
            ;;
        truncate|*)
            if [ "${#processed}" -gt "$TTS_MAX_CHARS" ]; then
                processed="${processed:0:$TTS_MAX_CHARS}…"
            fi
            ;;
    esac

    [ -z "$processed" ] && return 0

    # Build the piper invocation. Always pass --cuda so piper uses GPU
    # when CUDAExecutionProvider is available in onnxruntime; it falls
    # back to CPU gracefully with a stderr warning if CUDA is absent.
    # Include --speaker N for multi-speaker voices.
    local piper_cmd="piper --model '$voice_file' --cuda"
    if [ -n "$speaker_id" ]; then
        piper_cmd+=" --speaker $speaker_id"
    fi
    piper_cmd+=" --length-scale $TTS_SPEED"
    piper_cmd+=" --noise-scale $TTS_EXPRESSIVENESS"
    piper_cmd+=" --noise-w-scale $TTS_PRONUNCIATION_VARIATION"
    piper_cmd+=" --sentence-silence $TTS_SENTENCE_SILENCE"
    piper_cmd+=" --output-raw 2>/dev/null"

    # Detach via setsid so audio survives Claude Code's process group.
    setsid bash -c "
        printf '%s' \"\$1\" \
            | $piper_cmd \
            | paplay --raw --format=s16le --rate=22050 --channels=1 --volume='$TTS_VOLUME' 2>/dev/null
    " _ "$processed" </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# Summarize text for speech via Claude Haiku. Prints summary to stdout,
# returns non-zero on failure. Caller must handle the fallback.
tts_summarize() {
    local text="$1"
    local max_chars="$2"

    command -v claude >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local prompt
    prompt="Rewrite the text below for spoken delivery. Keep as much detail as possible. "
    prompt+="Maximum ${max_chars} characters — use most of that budget, do not over-compress. "
    prompt+="Remove markdown, code blocks, and formatting. Natural spoken language only. "
    prompt+="Put the result in the \"summary\" field."$'\n\n'
    prompt+="$text"

    local schema
    schema='{"type":"object","properties":{"summary":{"type":"string","description":"The spoken-language summary of the input text"}},"required":["summary"]}'

    # One-shot Haiku call: JSON schema output, no tools, no session.
    local output
    output="$(printf '%s' "$prompt" | claude --model haiku --print \
        --output-format json \
        --json-schema "$schema" \
        --allowed-tools "" \
        --no-session-persistence \
        --disable-slash-commands \
        2>/dev/null)" || return 1

    # Extract structured summary from JSON output.
    local summary
    summary="$(printf '%s' "$output" | jq -r '.structured_output.summary // empty' 2>/dev/null)"
    [ -n "$summary" ] || return 1

    printf '%s' "$summary"
}

# ---- chime --------------------------------------------------------------

# Play the configured chime sound synchronously (blocks until done).
# Call this BEFORE speech so the chime finishes before piper starts.
# Returns 0 even if the sound file is missing (silent no-op).
tts_play_chime() {
    tts_load_config
    [ "$TTS_CHIME_ENABLED" = "true" ] || return 0

    local sounds_dir
    sounds_dir="$(_tts_sounds_dir)"
    local chime_file="$sounds_dir/${TTS_CHIME_SOUND}.wav"

    [ -f "$chime_file" ] || return 0
    paplay "$chime_file" 2>/dev/null || true
}

# List available chime sound names (one per line).
tts_list_chimes() {
    local sounds_dir
    sounds_dir="$(_tts_sounds_dir)"
    [ -d "$sounds_dir" ] || return 0

    local f
    for f in "$sounds_dir"/*.wav; do
        [ -e "$f" ] || continue
        basename "$f" .wav
    done | sort
}

# ---- interrupt ----------------------------------------------------------

# Kill any in-flight paplay that matches our speak invocation.
# Idempotent: pkill on nothing is a no-op.
tts_kill_inflight() {
    pkill -f "paplay --raw --format=s16le --rate=22050" 2>/dev/null || true
}
