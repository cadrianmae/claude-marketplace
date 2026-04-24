---
description: Compare multiple tone variants or register levels side-by-side via the formalizer-compare agent
argument-hint: "<tones,...> [levels,...] [--iterate] <text>  e.g. professional,concise 3 The report is overdue."
allowed-tools: Read, AskUserQuestion, Agent
---

# /formalizer:compare — Compare tone variants

Produce multiple tone variants of the same text side-by-side, or iterate one tone via self-critique. Dispatches the `formalizer-compare` subagent so working drafts and critiques never enter the parent context.

## Usage

```
/formalizer:compare professional,concise,diplomatic   The report is overdue.
/formalizer:compare formal 2,3,5                      The report is overdue.
/formalizer:compare diplomatic --iterate              The report is overdue.
/formalizer:compare                                    (prompts for tones and text)
```

## Argument parsing

Arguments arrive as `$ARGUMENTS`. Parse them as follows:

1. **Tones** — first comma-separated token where every part matches a known tone name (see SKILL.md for the list).
2. **Levels** — first comma-separated token where every part is a digit 1-5.
3. **`--iterate` flag** — anywhere in the args; toggles iterate mode.
4. **Remaining tokens** — the text to rewrite.

If a token is ambiguous (e.g. could be a single tone or a level), prefer the tone interpretation.

## Behaviour

- **If no tones given:** ask the user via `AskUserQuestion` (multi-select), offering the default set `professional, concise, diplomatic` plus the full 21-tone list grouped as in `/formalizer:rewrite`.
- **If no levels given:** default to `[3]`.
- **If text is missing:** check recent conversation context, otherwise prompt the user to paste it.
- **If tone × level combinations exceed 12:** refuse, ask the user to narrow one axis.

Dispatch the `formalizer-compare` agent via the `Agent` tool with parsed `tones`, `levels`, `--iterate` flag, and source text. Return the agent's output verbatim — no wrapping, no commentary.

## Why an isolated agent

Compare and iterate workflows can produce many drafts and a self-critique pass. Running them in a subagent keeps that working material out of the parent session's context window — only the final variants come back.
