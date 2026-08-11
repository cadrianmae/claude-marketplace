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
# shellcheck disable=SC2034  # consumed by _af_sounds_dir via lib.sh, sourced above
AF_THEME="default"
dir="$(_af_sounds_dir)"
check "$dir" "$base/default/sounds" "dir is <base>/default/sounds"
if [ -f "$dir/stop.wav" ]; then
    check yes yes "stop.wav present in new layout"
else
    check no yes "stop.wav present in new layout"
fi
themes="$(af_list_themes)"
case "$themes" in *default*) check yes yes "af_list_themes finds default";; *) check no yes "af_list_themes finds default";; esac

exit "$fail"
