---
name: audio-feedback
description: This skill should be used when the user asks to "configure audio feedback", "change sound settings", "enable/disable sounds", "set notification sound", "mute audio", "turn off sounds", "change the chime", "audio settings", or anything involving the audio-feedback plugin for hook event sounds.
version: 0.1.0
user-invocable: true
allowed-tools: Bash, AskUserQuestion
argument-hint: "[config|sounds|test|help] [args...]"
---

# Audio Feedback — Hook Event Sounds

The audio-feedback plugin plays short synth sounds on Claude Code hook events: response complete, notifications, context compaction, user input, and more. Each event maps to a configurable sound (or "off"). Eight bundled sounds cover different event characters. Independent of the tts plugin — this is purely non-speech audio cues.

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

| Key | Default | Purpose |
|---|---|---|
| `ENABLED` | `true` | Master switch — all sounds off when false |
| `STOP_SOUND` | `soft-chime` | Response complete |
| `NOTIFICATION_SOUND` | `bell` | Cron/alert fired |
| `PRE_COMPACT_SOUND` | `hum` | Context about to compact |
| `USER_PROMPT_SOUND` | `pip` | Input acknowledged |
| `SESSION_START_SOUND` | `off` | Session began |
| `SUBAGENT_STOP_SOUND` | `off` | Subagent finished |
| `PRE_TOOL_USE_SOUND` | `off` | Before tool call |
| `POST_TOOL_USE_SOUND` | `off` | After tool call |

Set any event to `off` to silence it. Set `ENABLED=false` to silence everything.

## Bundled Sounds

| Sound | Character | Duration |
|---|---|---|
| `soft-chime` | Warm C4+E4 chord | 0.4s |
| `bell` | Descending C5-G4 glide | 0.6s |
| `hum` | Low warm G3 tone | 0.5s |
| `pip` | Quick triangle blip | 0.15s |
| `welcome` | Ascending C4-E4 two-note | 0.4s |
| `agent-done` | Double pip 660-880Hz | 0.22s |
| `click` | Short filtered noise burst | 0.04s |
| `blip` | Tiny 880Hz sine | 0.07s |

All generated with sox, normalized to 0dB peak, mono 44.1kHz.

## Workflow: CONFIG

Two modes:

- **No args** — run `audio-feedback-config` to show current config. Pass output through.
- **With KEY=VALUE** — run `audio-feedback-config KEY=VALUE [...]` to update. Validates sound names against bundled files.

## Workflow: SOUNDS

List available sounds by running `audio-feedback-config` (which shows available sounds in its footer).

## Workflow: TEST

Play each configured sound that isn't "off" in sequence so the user can hear them. Run:

```bash
for event in stop notification pre_compact user_prompt session_start subagent_stop pre_tool_use post_tool_use; do
    sound=$(audio-feedback-config 2>/dev/null | grep -i "${event}_SOUND" | cut -d= -f2 || true)
    [ "$sound" = "off" ] && continue
    echo "$event: $sound"
    paplay "$(dirname "$(readlink -f "$(which audio-feedback-config)")")/../sounds/${sound}.wav" 2>/dev/null || true
done
```

Show which event→sound mappings played and which were off.

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
- Sounds play synchronously via `paplay`. Each hook blocks briefly while the sound plays. Short sounds (pip: 0.15s, click: 0.04s, blip: 0.07s) have negligible impact; longer sounds (bell: 0.6s) may add slight latency.
- Requires PipeWire (`paplay`). No fallback for Pulse-only or ALSA-direct systems.
