# Track Plugin v2.1.0 Testing Guide

## Critical Testing Considerations

### 1. Async Hook Behavior

**IMPORTANT:** The Stop hook runs with `async: true`, which means:
- systemMessage output appears on the **NEXT conversation turn**
- If session closes immediately after work, debug output will NEVER appear
- Testing requires **keeping session alive** for next turn

**Testing Pattern:**
```bash
# Start test session
claude

# Do work that triggers Stop hook
/track init
# ... do some work ...

# WAIT - Don't close session!
# Send another message to see systemMessage from previous turn
"show me the debug output"

# NOW you'll see: [Track v2.1 Debug] Hook fired | ...
```

### 2. Stop Hook Doesn't Fire On Interrupts

If you press Ctrl+C during Claude's response, the Stop hook **will not fire**.

**Testing Pattern:**
- ✅ Let Claude complete full response
- ❌ Don't interrupt with Ctrl+C
- ❌ Don't close session immediately

### 3. LLM Error Logging

Haiku call errors are logged to `${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log`.

**Check for failures:**
```bash
# After testing, check for LLM errors
cat "${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log"

# Common errors:
# - "Authentication failed" - Claude CLI not configured
# - "No such file or directory" - system prompt files missing
# - "Timeout" - Haiku call exceeded 30 seconds
```

### 4. Shell Profile Interference

**CRITICAL:** If `~/.zshrc` or `~/.bashrc` outputs to stdout unconditionally, it corrupts hook JSON output.

**Check your shell profile:**
```bash
# Look for unconditional echo/print statements
grep -n "echo\|print" ~/.zshrc

# Fix: wrap in interactive check
if [[ $- == *i* ]]; then
  echo "Shell ready"
fi
```

## Testing Procedure

### Phase 1: Hook Registration Verification

```bash
# Start Claude Code in debug mode
claude --debug 2>&1 | tee /tmp/claude-debug.log

# Check hooks loaded
/hooks

# Look for Stop hook in output:
# "Stop: [1 matcher]"
```

### Phase 2: Stop Hook Execution Test

```bash
# In Claude session:
/track init

# Do some work
"create a test file called hello.txt with 'Hello World'"

# CRITICAL: Don't close session - send another message
"what did you just do?"

# Look for systemMessage output:
# [Track v2.1 Debug] Hook fired | Prompts tracked: 1 | Sources: 0 | ...
```

### Phase 3: LLM Error Check

```bash
# Exit Claude session
# Check LLM error log
cat "${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log"

# If empty: Haiku calls succeeded
# If contains errors: Fix authentication or system prompt paths
```

### Phase 4: Output Verification

```bash
# Check files created
ls -la claude_usage/

# Check sources captured
cat claude_usage/sources.md

# Check prompts captured
cat claude_usage/prompts.md
```

### Phase 5: Direct Hook Testing

```bash
# Create test input
cat > /tmp/stop-input.json << 'EOF'
{
  "session_id": "test123",
  "transcript_path": "$HOME/.claude/projects/.../transcript.jsonl",
  "cwd": "/tmp/track-test",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
EOF

# Test hook directly
cat /tmp/stop-input.json | bash plugins/track/hooks/stop.sh

# Should output JSON with systemMessage
```

## Debug Output Fields

The systemMessage contains these fields:

| Field | Meaning |
|-------|---------|
| `Prompts tracked` | 0 = not tracked, 1 = tracked |
| `Sources` | Number of tool calls tracked |
| `Verbosity` | Current PROMPTS_VERBOSITY setting |
| `LLM exit` | Exit code from Haiku call (0 = success) |
| `Has prompt` | yes/no - user prompt extracted |
| `Has response` | yes/no - assistant response extracted |

**Example output:**
```
[Track v2.1 Debug] Hook fired | Prompts tracked: 1 | Sources: 3 | Verbosity: all | LLM exit: 0 | Has prompt: yes | Has response: yes
```

## Common Issues

### Issue: "Prompts tracked: 0" but work was done

**Possible causes:**
1. `PROMPTS_VERBOSITY=major` but work classified as MINOR
2. LLM call failed (check LLM exit code)
3. Haiku authentication not working

**Fix:**
```bash
# Change verbosity to 'all' temporarily
echo "PROMPTS_VERBOSITY=all" > .claude/.ref-config

# Re-test
```

### Issue: "Has prompt: no" or "Has response: no"

**Possible causes:**
1. Transcript extraction failed
2. Empty transcript file
3. Wrong transcript format

**Fix:**
```bash
# Check transcript exists and has content
cat ~/.claude/projects/.../transcript.jsonl | tail -5
```

### Issue: No systemMessage appears at all

**Possible causes:**
1. Session closed before next turn (async output not delivered)
2. Hook not registered (check `/hooks`)
3. Hook exited early (stop_hook_active check)

**Fix:**
```bash
# Keep session alive - send another message
# Enable debug mode: claude --debug
```

### Issue: "LLM exit: 1" or other non-zero code

**Possible causes:**
1. Claude CLI not authenticated
2. System prompt files missing
3. Haiku API error

**Fix:**
```bash
# Test Claude CLI directly
claude --model haiku "Test summarization"

# Check system prompt files exist
ls -la plugins/track/hooks/prompts/

# Check error log
cat "${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log"
```

## Success Criteria

✅ Stop hook fires after each Claude response
✅ systemMessage appears on next turn
✅ LLM exit code is 0
✅ Has prompt: yes, Has response: yes
✅ Entries appear in claude_usage/prompts.md
✅ Entries appear in claude_usage/sources.md (if tools used)
✅ `${CLAUDE_PLUGIN_DATA:-/tmp}/track-llm-error.log` is empty

## Next Steps

After verifying basic functionality:
1. Test verbosity filtering (all/major/minimal)
2. Test LLM fallback (disable Claude CLI temporarily)
3. Test export tools with captured data
4. Test deduplication (multiple same tool calls)
5. Remove debug systemMessage output (production version)
