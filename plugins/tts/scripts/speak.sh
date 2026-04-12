#!/bin/bash
# Manually speak arbitrary text. Used by `/tts speak <text>` and `/tts test`.
# Called via bin/tts-speak wrapper.

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
    echo "Usage: tts-speak <text>" >&2
    echo "       echo <text> | tts-speak" >&2
    exit 1
fi

tts_speak "$*"
echo "Speaking..."
