---
name: update
description: DEPRECATED in v2.0 - Retroactive scanning no longer needed with hooks-based tracking
allowed-tools: Read, Write
disable-model-invocation: true
user-invocable: false
deprecated: true
---

## ⚠️ DEPRECATED IN v2.0

**This command is no longer needed in Track Plugin v2.0.**

**Why deprecated:**
- v1.x required manual retroactive scanning via `/track:update`
- v2.0 uses hooks-based tracking that captures everything automatically
- Hooks run in real-time - no retroactive scanning needed

**Migration:**
- Remove any `/track:update` calls from workflows
- Use `/track:init` to enable hooks-based tracking
- Hooks capture all activity automatically

**See:** `/track:help` for v2.0 documentation

---

## Historical Context (v1.x)

In v1.x, this command was used to:
- Scan last 20 messages in conversation history
- Add missing WebSearch/WebFetch entries to CLAUDE_SOURCES.md
- Add missing major prompts to CLAUDE_PROMPTS.md
- Manual override when auto-tracking was disabled

This is no longer necessary because v2.0 hooks capture all activity in real-time.

---

## Implementation

```bash
echo "⚠️  DEPRECATED: /track:update is no longer needed in v2.0"
echo ""
echo "Track Plugin v2.0 uses hooks-based automatic tracking:"
echo "  - PostToolUse hook tracks sources in real-time"
echo "  - SessionEnd hook tracks prompts automatically"
echo ""
echo "No retroactive scanning needed!"
echo ""
echo "Migration steps:"
echo "  1. Remove /track:update calls from workflows"
echo "  2. Use /track:init to enable hooks"
echo "  3. Work normally - hooks track automatically"
echo ""
echo "See: /track:help for v2.0 documentation"
```
