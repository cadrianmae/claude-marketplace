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
if grep -q READY "$log"; then ok "daemon READY"; else bad "daemon READY"; fi

printf '%s\n' "/tmp/does-not-matter.wav" | python3 "$SOUNDD" raw-send --socket "$SOCK"
for _ in $(seq 1 30); do grep -q 'PLAY ' "$log" 2>/dev/null && break; sleep 0.1; done
if grep -q 'PLAY /tmp/does-not-matter.wav' "$log"; then ok "daemon received PLAY"; else bad "daemon received PLAY"; fi

for _ in $(seq 1 80); do kill -0 "$dpid" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$dpid" 2>/dev/null; then bad "daemon idle-exited"; kill "$dpid" 2>/dev/null; else ok "daemon idle-exited"; fi
if grep -q IDLE-EXIT "$log"; then ok "logged IDLE-EXIT"; else bad "logged IDLE-EXIT"; fi

# Concurrency: many parallel 'play' calls spawn exactly ONE daemon.
SOCK2="/tmp/aftest-daemon2.sock"; rm -f "$SOCK2" "$SOCK2.spawn.lock"
WAV="/tmp/aftest-silence.wav"
uv run --script "$SOUNDD" selftest >/dev/null 2>&1  # warm cache
python3 - "$WAV" <<'PY'
import sys, wave, struct
w = wave.open(sys.argv[1], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
w.writeframes(struct.pack("<" + "h"*2205, *([0]*2205))); w.close()
PY
for _ in $(seq 1 10); do
  python3 "$SOUNDD" play --socket "$SOCK2" --path "$WAV" --idle-timeout 2 --no-audio &
done
wait
n="$(pgrep -fc -- "af-soundd daemon --socket $SOCK2" || true)"
# `uv run --script` launches the resolved interpreter as a *subprocess*
# (not via exec) on this uv version, so one correctly-serialized daemon
# always shows as 2 matching processes: the `uv run` supervisor plus the
# python child it launched. n<=2 with a single parent/child pair is one
# daemon; the race this test guards against produces multiple independent
# pairs (n=20 for 10 concurrent spawns before the fix).
if [ "${n:-0}" -le 2 ]; then ok "single daemon under concurrency (n=${n:-0})"; else bad "single daemon under concurrency (n=$n)"; fi
sleep 3
if pgrep -f -- "af-soundd daemon --socket $SOCK2" >/dev/null; then bad "concurrent daemon idle-exited"; else ok "concurrent daemon idle-exited"; fi

# Fallback: DAEMON_ENABLED=false uses paplay, not the daemon.
STUB="/tmp/aftest-stub"; rm -rf "$STUB"; mkdir -p "$STUB"
cat >"$STUB/paplay" <<EOF
#!/bin/bash
echo "PAPLAY \$*" >> /tmp/aftest-calls.log
EOF
chmod +x "$STUB/paplay"
: > /tmp/aftest-calls.log
CFG3=/tmp/aftest-cfg3; rm -rf "$CFG3"; mkdir -p "$CFG3/.claude"
printf 'DAEMON_ENABLED=false\n' > "$CFG3/.claude/.audio-feedback-config"
HOME="$CFG3" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'
  af_load_config
  af_dispatch_play '$WAV'
"
if grep -q "PAPLAY .*$WAV" /tmp/aftest-calls.log; then ok "DAEMON_ENABLED=false falls back to paplay"; else bad "DAEMON_ENABLED=false falls back to paplay"; fi

exit "$fail"
