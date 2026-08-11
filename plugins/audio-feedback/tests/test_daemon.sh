#!/bin/bash
# Daemon lifecycle tests (no real audio). Daemon/selftest run via uv.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
SOUNDD="$PLUGIN/bin/af-soundd"
fail=0
ok()  { echo "[OK] $1"; }
bad() { echo "[FAIL] $1"; fail=1; }

if ! command -v uv >/dev/null 2>&1; then
  echo "[SKIP] uv not installed; skipping daemon tests"; exit 0
fi

# selftest (mixer math), env supplied by uv from PEP 723 metadata
if uv run --script "$SOUNDD" selftest; then ok "selftest passes"; else bad "selftest passes"; fi

# lifecycle: start daemon (no-audio), send a path via stdlib client, expect PLAY + IDLE-EXIT
SOCK="/tmp/aftest-daemon.sock"; rm -f "$SOCK"
log="/tmp/aftest-daemon.log"; : > "$log"
uv run --script "$SOUNDD" daemon --socket "$SOCK" --idle-timeout 2 --no-audio >"$log" 2>&1 &
dpid=$!
for _ in $(seq 1 100); do grep -q READY "$log" 2>/dev/null && break; sleep 0.1; done
grep -q READY "$log" && ok "daemon READY" || bad "daemon READY"

printf '%s\n' "/tmp/does-not-matter.wav" | python3 "$SOUNDD" raw-send --socket "$SOCK"
for _ in $(seq 1 30); do grep -q 'PLAY ' "$log" 2>/dev/null && break; sleep 0.1; done
grep -q 'PLAY /tmp/does-not-matter.wav' "$log" && ok "daemon received PLAY" || bad "daemon received PLAY"

for _ in $(seq 1 80); do kill -0 "$dpid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$dpid" 2>/dev/null; then bad "daemon idle-exited"; kill "$dpid" 2>/dev/null; else ok "daemon idle-exited"; fi
grep -q IDLE-EXIT "$log" && ok "logged IDLE-EXIT" || bad "logged IDLE-EXIT"

exit "$fail"
