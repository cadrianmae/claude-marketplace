---
description: Scan recent conversation history and add missing tracking entries
allowed-tools: Read, Write
---

## Tracking Status (Auto-Captured)

**Auto-Track**: !`[ -f .claude/.ref-autotrack ] && echo "✓ Enabled" || echo "✗ Disabled"`
**Sources Tracked**: !`wc -l < CLAUDE_SOURCES.md 2>/dev/null || echo "0"`
**Prompts Tracked**: !`grep -c "^Prompt:" CLAUDE_PROMPTS.md 2>/dev/null || echo "0"`
**Git Status**: !`git rev-parse --is-inside-work-tree &>/dev/null && echo "✓ Git repo" || echo "✗ Not a git repo"`

## Quick Example

```bash
/track:update
# Scans last 20 messages
# Adds 3 sources to CLAUDE_SOURCES.md
# Adds 1 prompt to CLAUDE_PROMPTS.md
# Done! Research tracked retroactively.
```

# update - Retroactive tracking scan

Scan recent conversation history and add missing tracking entries.

## What it does

1. **Review last 20 messages** in this conversation looking for:
   - WebSearch operations and results
   - WebFetch operations and results
   - Grep/Read operations on documentation
   - Major user requests (features, debugging, refactoring)

2. **Track sources** to `./CLAUDE_SOURCES.md`:
   - Format: `[User] Tool("query"): result` or `[Claude] Tool("query"): result`
   - **[User]** if user explicitly requested search ("search the web for...")
   - **[Claude]** if Claude autonomously searched for missing info
   - Result is URL or brief concept (1-2 sentences max)

3. **Track prompts** to `./CLAUDE_PROMPTS.md`:
   - Two-line format:
     ```
     Prompt: "user request verbatim or paraphrased"
     Outcome: what was accomplished in present tense

     ```
   - Blank line separator after each entry
   - Only significant work (features, complex tasks, multi-step work)
   - Respects verbosity setting from `.claude/.ref-config`

4. **Read configuration:**
   - Checks `./.claude/.ref-config` for verbosity settings
   - Respects PROMPTS_VERBOSITY (major, all, minimal, off)
   - Respects SOURCES_VERBOSITY (all, off)

5. **Check prerequisites:**
   - Verifies tracking files exist
   - If missing, suggests running `/track:init` first

6. **Show summary:**
   - Number of sources added
   - Number of prompts added
   - Confirmation message

## Usage notes

- Works regardless of auto-tracking status (manual override)
- Respects verbosity configuration
- Scans only last 20 messages (not entire conversation)
- Safe to run multiple times (appends new entries only)

## Prerequisites

Run `/track:init` first to create tracking files and configuration.

## Output

Concise summary showing what was tracked from recent history.
