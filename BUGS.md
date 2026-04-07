# Known Bugs

## Track Plugin

### `/track:init` Command Does Not Execute Script

**Reported:** 2026-02-09
**Plugin:** track v2.0.4
**Severity:** High - Plugin unusable without initialization

**Description:**
The `/track:init` command is invoked successfully and displays the skill documentation, but the underlying `scripts/init.sh` script does not execute. As a result, no tracking files are created.

**Expected Behavior:**
When `/track:init` is run, it should:
1. Create `claude_usage/` directory
2. Create `claude_usage/sources.md` with preamble
3. Create `claude_usage/prompts.md` with preamble
4. Create `.claude/.ref-config` with default settings
5. Create `.claude/.ref-autotrack` marker file
6. Display success summary

**Actual Behavior:**
- Skill documentation is displayed
- No files or directories are created
- No success summary is shown
- Hooks remain disabled (no `.ref-autotrack` marker)

**Investigation:**
- Skill file: `plugins/track/skills/init/SKILL.md`
- Script: `plugins/track/skills/init/scripts/init.sh`
- Script content appears correct (verified lines 1-135)
- Script has `disable-model-invocation: true` in frontmatter
- Script has `user-invocable: false` in frontmatter

**Reproduction:**
```bash
# In project directory
/track:init
# Expected: Files created
# Actual: Only documentation shown
```

**Impact:**
- Track plugin cannot be initialized
- Hooks do not activate (require `.ref-autotrack` marker)
- No automatic tracking occurs
- Plugin is effectively non-functional

**Workaround:**
Manual execution works: `bash plugins/track/skills/init/scripts/init.sh`

**Next Steps:**
- Investigate why `disable-model-invocation: true` skills don't execute scripts
- Check if command skills need different configuration
- Review skill execution model for script-based skills
- Test if `user-invocable: true` affects execution

---

### UserPromptSubmit Hook Only Captures Last Prompt

**Reported:** 2026-02-09
**Fixed:** 2026-02-09
**Plugin:** track v2.0.4 → v2.0.5 (pending)
**Severity:** High - Loses conversation history
**Status:** ✓ FIXED

**Description:**
The UserPromptSubmit hook overwrites the previous prompt each time, only storing the most recent prompt. SessionEnd hook then pairs only this last prompt with an outcome, losing all previous interaction history in multi-turn conversations.

**Expected Behavior:**
Should capture **all prompt-outcome pairs** during the session:
1. User submits prompt → Captured
2. Claude responds → Response captured
3. Prompt-outcome pair written to `prompts.md` immediately (or queued)
4. Repeat for each interaction in the session

**Actual Behavior:**
- UserPromptSubmit overwrites previous prompt (line 37: `echo "$user_prompt" > "...last_prompt.txt"`)
- Only the final prompt before session end is stored
- Multi-turn conversation history is lost
- `prompts.md` only shows last interaction per session

**Example:**
In a 5-turn conversation:
1. "initialize track plugin" → Captured, then **overwritten**
2. "test the hooks" → Captured, then **overwritten**
3. "check sources.md" → Captured, then **overwritten**
4. "is it logging usersubmit?" → **Stored** (last prompt)
5. Session ends → Only prompt 4 paired with outcome

Prompts 1-3 and their outcomes are completely lost.

**Root Cause:**
File: `plugins/track/hooks/user-prompt-submit.sh:37`
```bash
echo "$user_prompt" > ".claude/.track-tmp/${session_id}_last_prompt.txt"
```
The `>` operator overwrites instead of appending.

**Impact:**
- Cannot track methodology of multi-step development work
- Lost context for academic methodology sections
- Only captures final interaction, not the development process
- Defeats purpose of tracking "significant multi-step work"

**Proposed Solutions:**

**Option 1: Immediate Pairing (Preferred)**
- Add a PostToolUse or similar hook that triggers after Claude's response
- Immediately pair prompt with outcome and append to `prompts.md`
- Clear temporary storage after writing
- Real-time tracking, no data loss

**Option 2: Append All Prompts**
- Change `>` to `>>` to append prompts
- Store prompts with sequence numbers or timestamps
- SessionEnd reads entire conversation transcript
- Pairs all prompts with all outcomes
- Writes all pairs to `prompts.md` at once

**Option 3: Multi-file Storage**
- Store each prompt in separate timestamped file
- SessionEnd processes all prompt files
- Pairs with outcomes from transcript
- More complex but preserves order

**Recommendation:**
Option 1 (immediate pairing) provides:
- Real-time feedback in `prompts.md`
- No risk of data loss from crashes
- Simpler logic (no batch processing)
- Better user experience (see tracking as it happens)

**Solution Implemented (Option 2):**

Modified two hook scripts:

1. **`user-prompt-submit.sh`** (lines 34-59):
   - Changed from single-file overwrite to JSONL append
   - Each prompt stored as compact JSON: `{timestamp, sequence, prompt}`
   - Appends to `.track-tmp/${session_id}_prompts.jsonl`
   - Maintains backward compatibility with `_last_prompt.txt`

2. **`session-end.sh`** (lines 31-113):
   - Reads all prompts from JSONL file
   - Extracts all assistant responses from transcript
   - Pairs prompts with responses in order (by index)
   - Applies verbosity filter to each pair
   - Writes all qualifying pairs to `prompts.md`
   - Falls back to old behavior if JSONL file doesn't exist

**Changes:**
- `jq -nc` flag for compact JSONL output (one line per entry)
- Array-based processing of multiple assistant responses
- Sequential pairing: prompt[0] → response[0], prompt[1] → response[1], etc.
- Cleanup includes new `_prompts.jsonl` file

**Testing:**
- ✓ Captured 3 prompts in single session
- ✓ Paired all 3 with corresponding assistant responses
- ✓ All 3 entries written to prompts.md
- ✓ Temp files cleaned up successfully
- ✓ Backward compatible with old single-prompt files

**Files Modified:**
- `plugins/track/hooks/user-prompt-submit.sh`
- `plugins/track/hooks/session-end.sh`
