#!/bin/bash
# Config validation tests for daemon keys and removed clicks keys.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
CFG=/tmp/aftest-cfg
run() { rm -rf "$CFG" && mkdir -p "$CFG/.claude"; HOME="$CFG" "$PLUGIN/bin/audio-feedback-config" "$@"; }

fail=0
expect_ok()  { if run "$@" >/dev/null 2>&1; then echo "[OK] accept $*"; else echo "[FAIL] accept $*"; fail=1; fi; }
expect_err() { if run "$@" >/dev/null 2>&1; then echo "[FAIL] reject $*"; fail=1; else echo "[OK] reject $*"; fi; }

expect_ok  DAEMON_ENABLED=false
expect_ok  DAEMON_IDLE_TIMEOUT=15
expect_ok  DAEMON_MAX_VOICES=4
expect_err DAEMON_ENABLED=maybe
expect_err DAEMON_IDLE_TIMEOUT=0
expect_err DAEMON_MAX_VOICES=0
expect_err CLICKS_ENABLED=true

run DAEMON_IDLE_TIMEOUT=42 >/dev/null 2>&1
if grep -q '^DAEMON_IDLE_TIMEOUT=42$' "$CFG/.claude/.audio-feedback-config"; then
  echo "[OK] persists DAEMON_IDLE_TIMEOUT"; else echo "[FAIL] persists DAEMON_IDLE_TIMEOUT"; fail=1; fi

exit "$fail"
