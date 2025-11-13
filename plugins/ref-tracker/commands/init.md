# init - Initialize reference tracking

Initialize reference and research tracking for the current project.

## What it does

1. **Create tracking files:**
   - Creates `./CLAUDE_SOURCES.md` (empty, pure KV format)
   - Creates `./CLAUDE_PROMPTS.md` (with header)
   - If files exist, leaves them unchanged

2. **Create `.claude/` directory structure:**
   - Creates `./.claude/` directory if missing
   - Creates `./.claude/.ref-autotrack` (empty marker file - enables auto-tracking)
   - Creates `./.claude/.ref-config` with default settings:
     ```
     PROMPTS_VERBOSITY=major
     SOURCES_VERBOSITY=all
     ```

3. **Check skill availability:**
   - Verifies ref-tracker skill is available
   - Reports status

4. **Show setup summary:**
   - Files created/existing
   - Auto-tracking status (enabled)
   - Config location
   - Next steps

## Default configuration

After init, tracking is **automatically enabled** with these defaults:
- **Sources**: Track all WebSearch/WebFetch operations
- **Prompts**: Track major academic/development work only

## Next steps

After running `/track:init`:
- Use `/track:update` to scan recent history
- Use `/track:config` to adjust verbosity settings
- Use `/track:auto` to toggle auto-tracking on/off
- Use `/track:help` for detailed documentation

## Files created

```
.claude/
├── .ref-autotrack          # Marker: auto-tracking enabled
└── .ref-config             # Verbosity settings
CLAUDE_SOURCES.md           # Research sources (KV format)
CLAUDE_PROMPTS.md           # Major prompts and outcomes
```

## Output

Concise status report showing what was created and current configuration.
