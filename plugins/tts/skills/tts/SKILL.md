---
name: tts
description: This skill should be used when the user asks to "speak something", "read this aloud", "enable text to speech", "change voice", "try a different voice", "list available voices", "turn tts on/off", "test tts", "configure tts", "adjust tts volume", "pick a speaker", or anything involving the tts plugin for Piper-based text-to-speech. Single unified interactive entry point. Supports multi-speaker voices via voice:speaker syntax.
version: 0.1.3
user-invocable: true
allowed-tools: [Bash, Read, AskUserQuestion]
argument-hint: "[speak|test|voices|voice|config|auto|help] [args...]"
---

# TTS — Piper Text-to-Speech

The tts plugin speaks Claude's assistant responses aloud through [Piper](https://github.com/rhasspy/piper), a local neural TTS engine. Two hooks do the work: `Stop` fires after each assistant response and plays audio via `piper --output-raw | paplay --raw`; `UserPromptSubmit` kills any in-flight `paplay` so typing interrupts speech mid-sentence. Both hooks read `~/.claude/.tts-config` for voice, volume, speak mode, and an enable/disable flag — none of which live in the skill namespace, so this skill is purely for user-facing control and testing.

The plugin targets Linux with PipeWire and requires `piper` on `PATH` plus at least one voice installed at `~/.local/share/piper-voices/*.onnx`. It never touches speech-dispatcher — that's a separate stack with its own gotchas.

## First Step

When invoked with no arguments, the FIRST action must be a single AskUserQuestion tool call (no preamble). Use this EXACT string for the `question` field:

"What would you like to do with tts?"

Set `header: "Action"` and offer these options:

- `speak` — Speak a one-off string (testing)
- `test` — Play a canned sample with the current voice
- `voices` — List installed voices
- `voice` — Change the default voice
- `config` — View or update config values
- `auto` — Toggle tts on/off
- `help` — Show subcommand grammar and config reference

If the user's message already includes a subcommand (e.g. `/tts voice lessac`), skip the AUQ and jump straight into the matching workflow. See "Subcommand Grammar" below.

## Helper Commands

All real work is done by thin wrappers in the plugin's `bin/` directory. Claude Code puts that directory on `PATH` automatically, so invoke them as bare commands — **no path construction, no `$CLAUDE_PLUGIN_ROOT`**. (`$CLAUDE_PLUGIN_ROOT` is not substituted inside SKILL.md files; see [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354).)

- `tts-speak <text>` — speak arbitrary text
- `tts-voices` — list installed voices with the current default marked
- `tts-voice <name>` — set the default voice
- `tts-config [KEY=VALUE ...]` — view or update config
- `tts-auto [on|off]` — toggle `TTS_ENABLED`

Do NOT edit `~/.claude/.tts-config` directly from this skill. Use the commands.

## Configuration Reference

The global config file is `~/.claude/.tts-config`. Both this skill and the hooks read it on every invocation.

| Key | Default | Values | Purpose |
|---|---|---|---|
| `VOICE` | `aru` | any installed voice name | Which Piper voice to use |
| `VOLUME` | `40000` | 0–65536 | `paplay --volume=N` attenuation level (~61% at default) |
| `SPEAK_MODE` | `truncate` | `full` / `truncate` / `summary` | How to handle Claude's response |
| `MAX_CHARS` | `1000` | positive integer | Char cap for `truncate` and `summary` modes |
| `TTS_ENABLED` | `false` | `true` / `false` | Master on/off switch — hooks are no-ops when false |
| `INTERRUPT_ON_TYPE` | `true` | `true` / `false` | Kill in-flight `paplay` on UserPromptSubmit |
| `SPEED` | `1.0` | 0.1–3.0 (float) | Speech rate via piper `--length-scale`. **Inverted**: <1.0 = faster, >1.0 = slower |
| `EXPRESSIVENESS` | `0.667` | 0.0–1.0 (float) | Generator noise via `--noise-scale`. Higher = more expressive |
| `PRONUNCIATION_VARIATION` | `0.8` | 0.0–1.0 (float) | Phoneme width noise via `--noise-w-scale`. Higher = more variation |
| `SENTENCE_SILENCE` | `0.0` | 0.0–5.0 (float) | Seconds of silence between sentences via `--sentence-silence` |

**First-install state:** `TTS_ENABLED=false`. The user opts in via `/tts auto on`.

## Speak Modes

- **`full`** — entire response, markdown stripped, code blocks removed. Can run 30+ seconds on long answers; interrupt by typing.
- **`truncate`** (default) — same pipeline as `full`, but hard-cut at `MAX_CHARS` with `…` suffix.
- **`summary`** — calls Claude Haiku to summarize the response for speech in under `MAX_CHARS` characters. Falls back to `truncate` silently if the Haiku call fails (error logged to stderr, visible only in `claude --debug`).

Code blocks are ALWAYS excluded from speech, in every mode, because speaking code is painful to listen to.

## Workflow: SPEAK

1. If the user supplied text as arguments, call `tts-speak "<text>"` directly.
2. If no text was supplied, AUQ: `header: "Speak"`, question: "What should I speak?" — accept free-text.
3. Show the wrapper's output ("Speaking..."). Audio plays detached in the background via `setsid`.

The wrapper does not wait for playback to finish — it returns immediately. Speech continues even if this skill exits.

## Workflow: TEST

Run `tts-speak "Hello from Piper. This is a test of the Claude Code text-to-speech plugin."` and show its output.

Test does NOT take arguments. It is a fixed canned phrase so the user can confirm the voice and volume are working.

## Workflow: VOICES

Run `tts-voices` and show its output. The wrapper lists each installed voice on its own line, marks the current default with `*`, and prints a hint about how to change it.

If the user wants to change the voice after seeing the list, offer to run the `voice` workflow.

## Workflow: VOICE

1. **If the user supplied a name**, call `tts-voice <name>` directly. The wrapper validates the name against the installed voices and errors out cleanly if it's not found.
2. **If no name was supplied**, run `tts-voices` first so the user can see what's installed, then AUQ: `header: "Voice"`, question: "Which voice should be the new default?". Options: each installed voice name (plus `cancel`).
3. After setting, show the wrapper's confirmation ("✓ Default voice set to: ...").

### Multi-speaker voices

Some Piper voices bundle multiple speakers in one `.onnx` file (e.g. `semaine` has `prudence`, `spike`, `obadiah`, `poppy`). To select a specific speaker, use `name:speaker` syntax:

- `tts-voice semaine:poppy` — set speaker by name (looked up in `speaker_id_map`)
- `tts-voice semaine:3` — set speaker by integer id
- `tts-voice semaine` — use the voice's default speaker (Piper uses id 0)

`tts-voices` annotates multi-speaker voices with their speaker list: `semaine (speakers: prudence, spike, obadiah, poppy)`. The annotation is read from the voice's sidecar `.onnx.json` file.

Single-speaker voices reject the `:speaker` suffix with a clean error. Invalid speaker names or out-of-range integers also error cleanly.

Note: voice changes take effect on the next speak invocation. Any audio already playing continues with the old voice.

## Workflow: CONFIG

Two modes:

- **No args** → call `tts-config` with no arguments. The wrapper prints the current config. Pass its output through unchanged.
- **With `KEY=VALUE` pairs** → call `tts-config KEY=VALUE [KEY=VALUE ...]` directly. The wrapper validates each key and value before applying anything, so an invalid pair aborts the whole update with a clean error message.

Supported keys: `VOICE`, `VOLUME`, `SPEAK_MODE`, `MAX_CHARS`, `TTS_ENABLED`, `INTERRUPT_ON_TYPE`. Refer to the Configuration Reference table above for valid values.

## Workflow: AUTO

1. If the user supplied `on` or `off`, call `tts-auto on` or `tts-auto off` directly.
2. Otherwise, AUQ: `header: "Auto-tracking"`, question: "Enable or disable tts?". Options: `on`, `off`, `cancel`.
3. Show the wrapper's output, including the summary of current config when enabling.

`auto off` only flips `TTS_ENABLED`. It does not delete the config file or kill in-flight speech. If the user wants to interrupt speech that's already playing, run `tts-speak ""` with empty text, or wait for it to finish, or send another user prompt (which triggers the interrupt hook).

## Workflow: HELP

Print a static reference. Do NOT call any helper script. Output:

1. The subcommand grammar block from "Subcommand Grammar" below.
2. The Configuration Reference table from above.
3. The list of installed voices (call `tts-voices` once for this — it's cheap and gives current state).
4. 2-3 usage examples.

Keep it under 80 lines.

## Subcommand Grammar (skip the AUQs)

The first positional argument is the subcommand. **If the first argument matches a subcommand below, jump straight into that workflow** and only AUQ for what is missing.

```
/tts                              → fully interactive (action AUQ first)
/tts speak <text>                 → manually speak a one-off string
/tts test                         → play a canned sample with current voice
/tts voices                       → list installed voices (annotated with speakers)
/tts voice <name>                 → set VOICE config value (single-speaker)
/tts voice <name>:<speaker>       → set VOICE config value (multi-speaker)
/tts config [KEY=VALUE ...]       → view or update global config
/tts auto [on|off]                → toggle TTS_ENABLED
/tts help                         → subcommand grammar + config + voices
```

### Subcommand → helper-command mapping

| Subcommand | Helper invocation |
|---|---|
| `speak TEXT` | `tts-speak "TEXT"` |
| `test` | `tts-speak "Hello from Piper. This is a test of the Claude Code text-to-speech plugin."` |
| `voices` | `tts-voices` |
| `voice NAME` | `tts-voice NAME` |
| `config [ARGS]` | `tts-config [ARGS]` |
| `auto [on\|off]` | `tts-auto [on\|off]` |
| `help` | (no helper — print static reference inline) |

### Examples

```
/tts auto on
/tts voice lessac
/tts voice semaine:poppy              # multi-speaker: poppy character
/tts voice semaine:2                  # multi-speaker: by integer id
/tts test
/tts config VOLUME=30000
/tts config SPEAK_MODE=summary MAX_CHARS=500
/tts speak "Lunch break, back in twenty minutes"
/tts auto off
```

## Important Notes

- The Stop hook is a no-op when `TTS_ENABLED=false`. The config file holds the authoritative state — flip it via `/tts auto`, not by editing the file.
- First-install default is **off**. No surprise audio. The user explicitly runs `/tts auto on` to start hearing Claude.
- Piper raw output is already −13.8 LUFS with +0.8 dBFS true peak. **Volume is attenuation-only via `paplay --volume=N`.** Do not advise the user to amplify via `sox -v` or similar — it causes clipping ("earrape"). 40000 is the sweet spot.
- **SPEED uses piper's inverted `--length-scale`:** values below 1.0 are faster, above 1.0 are slower. 0.7 is noticeably faster; 0.5 is very fast but may sound robotic. 1.3 is a relaxed pace.
- The plugin requires PipeWire. On Pulse-only or ALSA-direct systems, `paplay --raw` will fail silently. There is currently no fallback.
- Multi-speaker voices use `name:speaker` syntax (e.g. `semaine:poppy`, `semaine:3`). Speaker names are looked up in the voice's `.onnx.json` `speaker_id_map`. Not all voices are multi-speaker — `tts-voices` annotates those that are.
- If the user asks for "tool-use announcements" or "speak what Claude is about to do", that's tier D from the design and was deferred. Explain that it's not in v0.1 and offer to file it as a future feature.
- If `summary` mode is enabled but the `claude` CLI is unavailable, the plugin falls back to `truncate` silently. Mention this to the user if they're debugging why summaries aren't appearing.
- All workflows are CWD-independent — the config file is global at `~/.claude/.tts-config`, not per-project.
