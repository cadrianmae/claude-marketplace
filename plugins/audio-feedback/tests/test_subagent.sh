#!/bin/bash
# When agent_id present + SUBAGENT_ACCENT=true, the accent sound is dispatched too.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
fail=0
ok()  { echo "[OK] $1"; }
bad() { echo "[FAIL] $1"; fail=1; }

STUB="/tmp/aftest-sub-stub"; rm -rf "$STUB"; mkdir -p "$STUB"
cat >"$STUB/paplay" <<EOF
#!/bin/bash
echo "PAPLAY \$*" >> /tmp/aftest-sub-calls.log
EOF
chmod +x "$STUB/paplay"
: > /tmp/aftest-sub-calls.log
CFG=/tmp/aftest-sub-cfg; rm -rf "$CFG"; mkdir -p "$CFG/.claude"
printf 'DAEMON_ENABLED=false\nPRE_TOOL_USE_SOUND=pre-tool-use\nSUBAGENT_ACCENT=true\n' \
  > "$CFG/.claude/.audio-feedback-config"

# invoke the accent helper directly with an agent_id present
HOME="$CFG" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'
  af_load_config
  af_play_subagent_accent
"
if grep -q "subagent-accent.wav" /tmp/aftest-sub-calls.log; then ok "accent dispatched"; else bad "accent dispatched"; fi

# with SUBAGENT_ACCENT=false -> no accent
: > /tmp/aftest-sub-calls.log
printf 'DAEMON_ENABLED=false\nSUBAGENT_ACCENT=false\n' > "$CFG/.claude/.audio-feedback-config"
HOME="$CFG" PATH="$STUB:$PATH" bash -c "
  source '$PLUGIN/scripts/lib.sh'; af_load_config; af_play_subagent_accent
"
if grep -q "subagent-accent.wav" /tmp/aftest-sub-calls.log; then bad "accent suppressed when off"; else ok "accent suppressed when off"; fi

exit "$fail"
