---
name: audio-feedback
description: This skill should be used when the user asks to "configure audio feedback", "change sound settings", "enable/disable sounds", "set notification sound", "mute audio", "turn off sounds", "change the chime", "change theme", "tune click sounds", "audio accessibility", "audio cues", "audio settings", or anything involving the audio-feedback plugin for hook event sounds.
version: 0.2.2
user-invocable: true
allowed-tools: Bash, AskUserQuestion
argument-hint: "[config|sounds|test|help] [args...]"
---

# Audio Feedback — Accessible Audio Cues for Claude Code

The audio-feedback plugin provides non-speech audio cues for Claude Code hook events, supporting awareness of Claude's activity without needing to watch the terminal. Short synth sounds fire on response complete, notifications, context compaction, user input, tool calls, subagent completion, session start, and pre-compact. Each event maps to a configurable sound (or `off`) and is organised by theme. On Stop / PostToolUse / SubagentStop the event sound is optionally followed by a "click" sequence whose density scales with Claude's token output — an audible work-scale indicator. Independent of the tts plugin (purely non-speech).

## First Step

When invoked with no arguments, the FIRST action must be a single AskUserQuestion tool call (no preamble):

"What would you like to do with audio-feedback?"

Set `header: "Action"` and offer: `config`, `sounds`, `test`, `help`.

If the user's message already includes a subcommand, skip the AUQ and jump into the matching workflow.

## Helper Commands

- `audio-feedback-config [KEY=VALUE ...]` — view or update config

Invoke as a bare command — `bin/` is on `PATH` automatically.

## Configuration Reference

Global config: `~/.claude/.audio-feedback-config`

### Core

| Key | Default | Purpose |
|---|---|---|
| `ENABLED` | `true` | Master switch — all sounds off when false |
| `THEME` | `default` | Sound pack (subdirectory under `sounds/`) |
| `STOP_SOUND` | `stop` | Response complete |
| `NOTIFICATION_SOUND` | `notification` | Cron/alert fired |
| `PRE_COMPACT_SOUND` | `pre-compact` | Context about to compact |
| `USER_PROMPT_SOUND` | `user-prompt-submit` | Input acknowledged |
| `SESSION_START_SOUND` | `off` | Session began |
| `SUBAGENT_STOP_SOUND` | `off` | Subagent finished |
| `PRE_TOOL_USE_SOUND` | `off` | Before tool call |
| `POST_TOOL_USE_SOUND` | `off` | After tool call |

Set any event to `off` to silence it. Set `ENABLED=false` to silence everything.

Subtype-specific sounds (e.g. `notification-permission.wav`, `post-tool-use-observe.wav`) are auto-resolved from the theme directory when present, falling back to the generic sound above.

### Click sounds

Clicks play after the event sound on enabled events, with start rate scaled from output tokens via a log curve.

| Key | Default | Purpose |
|---|---|---|
| `CLICKS_ENABLED` | `true` | Master switch for click sequences |
| `CLICKS_EVENTS` | `stop,post_tool_use,subagent_stop` | Which events get clicks (comma-separated). Also supports `notification`, `pre_compact` |
| `CLICKS_RATE` | `25` | Start rate at the anchor token count (cps) |
| `CLICKS_RATE_AT` | `50` | Anchor token count |
| `CLICKS_RATE_GROWTH` | `4` | Log2 slope above the anchor |

Formula: `start_rate = CLICKS_RATE + CLICKS_RATE_GROWTH * log2(tokens / CLICKS_RATE_AT)` (floored at 5 cps). Duration also scales logarithmically from tokens, clamped to [0.3, 1.5]s, with quadratic ease-out (gap grows 4× by the tail).

Token sources per event:
- `stop` — exact `output_tokens` from last assistant entry in `transcript_path`
- `subagent_stop` — **sum** of `output_tokens` across `agent_transcript_path`
- `post_tool_use` / `notification` — estimated as `chars(text) / 4`

## Bundled Sounds — Default Theme

Lo-fi minimal aesthetic, sox-generated, 0.5s reverb tail, normalised to 0dB peak, mono 44.1 kHz.

### Generic event sounds

| File | Event | Character | Duration |
|---|---|---|---|
| `stop.wav` | Stop | Descending G4–C4 fifth, settling | 1.0s |
| `notification.wav` | Notification | Ascending A4–C5, attention | 0.9s |
| `pre-compact.wav` | PreCompact | Low G3 tone, warning | 1.1s |
| `user-prompt-submit.wav` | UserPromptSubmit | Tiny 600Hz click | 0.55s |
| `session-start.wav` | SessionStart | Ascending C4–E4–G4 arpeggio | 0.94s |
| `subagent-stop.wav` | SubagentStop | Double ping E5 | 0.66s |
| `pre-tool-use.wav` | PreToolUse | Barely-there 500Hz tick | 0.53s |
| `post-tool-use.wav` | PostToolUse | Short 700Hz tick | 0.54s |

### Subtype-aware variants

The hook inspects the JSON payload and, when a subtype-specific WAV exists, prefers it over the generic sound. Lets the user distinguish *kinds* of events by ear — core to the accessibility purpose of the plugin.

| Event | Subtype source | Variant files |
|---|---|---|
| Notification | `notification_type` | `notification-permission.wav`, `notification-idle.wav`, `notification-auth.wav`, `notification-elicitation.wav` |
| SessionStart | `source` | `session-start-resume.wav`, `session-start-compact.wav`, `session-start-clear.wav` |
| PreToolUse / PostToolUse | `tool_name` → tool group | `pre-tool-use-{execute,observe,modify,network,dispatch,interact}.wav` (and `post-tool-use-*` mirror) |

Tool-group mapping (so one file serves a family of tools):

| Group | Tools |
|---|---|
| `execute` | Bash |
| `observe` | Read, Glob, Grep |
| `modify` | Write, Edit, NotebookEdit |
| `network` | WebFetch, WebSearch |
| `dispatch` | Agent |
| `interact` | AskUserQuestion, ExitPlanMode |

Any WAV file not listed is a silent no-op if missing from the active theme — themes don't need to ship a complete set.

## Workflow: CONFIG

Two modes:

- **No args** — run `audio-feedback-config` to show current config. Pass output through.
- **With KEY=VALUE** — run `audio-feedback-config KEY=VALUE [...]` to update. Validates sound names against bundled files.

## Workflow: SOUNDS

Run `audio-feedback-config` (no args) — its footer lists sounds in the active theme and all available themes.

## Workflow: TEST

Play each configured sound that isn't `off` in sequence so the user can hear them. Resolves the active theme directory so the test works regardless of `THEME`.

```bash
cfg=$(audio-feedback-config 2>/dev/null)
plugin_root=$(dirname "$(dirname "$(readlink -f "$(which audio-feedback-config)")")")
theme=$(printf '%s' "$cfg" | awk -F= '/^  THEME=/{print $2}')
sounds_dir="$plugin_root/sounds/${theme:-default}"

for key in STOP_SOUND NOTIFICATION_SOUND PRE_COMPACT_SOUND USER_PROMPT_SOUND \
           SESSION_START_SOUND SUBAGENT_STOP_SOUND PRE_TOOL_USE_SOUND POST_TOOL_USE_SOUND; do
    sound=$(printf '%s' "$cfg" | awk -F= -v k="  $key" '$1==k{print $2}')
    [ -z "$sound" ] || [ "$sound" = "off" ] && { echo "$key: $sound"; continue; }
    echo "$key: $sound"
    paplay "$sounds_dir/${sound}.wav" 2>/dev/null || echo "  [missing: $sounds_dir/${sound}.wav]"
done
```

Show which event→sound mappings played and which were `off` or missing.

## Workflow: HELP

Print the subcommand grammar, config reference table, and bundled sounds table inline. No helper script needed.

## Subcommand Grammar

```
/audio-feedback                     → interactive (AUQ first)
/audio-feedback config [KEY=VALUE]  → view or update config
/audio-feedback sounds              → list available sounds
/audio-feedback test                → play all active sounds in sequence
/audio-feedback help                → grammar + config + sounds reference
```

## Important Notes

- **Coexistence with tts plugin:** If tts is also installed with CHIME_ENABLED=true, both plugins fire on Stop — double chime. Disable one: either `/tts config CHIME_ENABLED=false` or `/audio-feedback config STOP_SOUND=off`.
- PreToolUse and PostToolUse default to `off` because they fire on EVERY tool call (high frequency, can be annoying during heavy tool use).
- Hooks are non-blocking: event sound + click sequence run in a detached background subshell, so the hook script returns in ~50ms regardless of sox/paplay latency.
- Requires PipeWire (`paplay`). Click generation additionally needs `sox` and `jq`. No fallback for Pulse-only or ALSA-direct systems.
