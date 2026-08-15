#!/bin/bash
# When agent_id is present + SUBAGENT_ACCENT=true and a <name>-subagent.wav
# exists, af_play_event_with_subtype plays the BACKGROUND variant (the normal
# sound pushed to the background) instead of the plain sound. Respects
# AF_ENABLED and the base event's "off" gate.
set -u
HERE="$(dirname "$(readlink -f "$0")")"
PLUGIN="$(dirname "$HERE")"
fail=0
ok()  { echo "[OK] $1"; }
bad() { echo "[FAIL] $1"; fail=1; }

STUB="/tmp/aftest-sub-stub"; rm -rf "$STUB"; mkdir -p "$STUB"
cat >"$STUB/paplay" <<'EOF'
#!/bin/bash
echo "PAPLAY $*" >> /tmp/aftest-sub-calls.log
EOF
chmod +x "$STUB/paplay"
CFG=/tmp/aftest-sub-cfg; rm -rf "$CFG"; mkdir -p "$CFG/.claude"

run() {  # $1 = extra config lines, $2 = agent_id
    : > /tmp/aftest-sub-calls.log
    printf 'DAEMON_ENABLED=false\n%b\n' "$1" > "$CFG/.claude/.audio-feedback-config"
    HOME="$CFG" PATH="$STUB:$PATH" bash -c "
        source '$PLUGIN/scripts/lib.sh'; af_load_config
        af_play_event_with_subtype pre_tool_use '' '$2'
    "
}

# agent_id present + toggle on -> plays the -subagent background variant
run 'PRE_TOOL_USE_SOUND=pre-tool-use\nSUBAGENT_ACCENT=true' 'agent-123'
if grep -q 'pre-tool-use-subagent.wav' /tmp/aftest-sub-calls.log; then ok "background variant in subagent"; else bad "background variant in subagent"; fi

# agent_id present + toggle off -> plays the plain sound (no background)
run 'PRE_TOOL_USE_SOUND=pre-tool-use\nSUBAGENT_ACCENT=false' 'agent-123'
if grep -q 'subagent' /tmp/aftest-sub-calls.log; then bad "toggle off -> plain sound"; else ok "toggle off -> plain sound"; fi

# no agent_id -> plain sound (no background)
run 'PRE_TOOL_USE_SOUND=pre-tool-use\nSUBAGENT_ACCENT=true' ''
if grep -q 'subagent' /tmp/aftest-sub-calls.log; then bad "no agent -> plain sound"; else ok "no agent -> plain sound"; fi

# base event "off" -> silent even with agent_id
run 'ENABLED=true\nPRE_TOOL_USE_SOUND=off\nSUBAGENT_ACCENT=true' 'agent-123'
if [ -s /tmp/aftest-sub-calls.log ]; then bad "off event silent in subagent"; else ok "off event silent in subagent"; fi

exit "$fail"
