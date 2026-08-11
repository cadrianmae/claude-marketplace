#!/bin/bash
# Resolution tests: path layout, theme listing.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
# shellcheck source=../scripts/lib.sh disable=SC1091
source "$PLUGIN/scripts/lib.sh"

fail=0
check() { if [ "$1" = "$2" ]; then echo "[OK] $3"; else echo "[FAIL] $3: got '$1' want '$2'"; fail=1; fi; }

base="$(_af_sounds_base)"
check "$(basename "$base")" "sound-theme" "base is sound-theme/"
AF_THEME="default"
dir="$(_af_sounds_dir)"
check "$dir" "$base/default/sounds" "dir is <base>/default/sounds"
[ -f "$dir/stop.wav" ] && check yes yes "stop.wav present in new layout" || check no yes "stop.wav present in new layout"
themes="$(af_list_themes)"
case "$themes" in *default*) check yes yes "af_list_themes finds default";; *) check no yes "af_list_themes finds default";; esac

exit "$fail"
