---
description: Apply multiple tones sequentially to the same text and return one merged output via the formalizer-pipeline agent
argument-hint: "<tones...> [level OR tone:level] [--show-stages] <text>  e.g. grammatical readable concise 3 The report is overdue."
allowed-tools: Read, AskUserQuestion, Agent
---

# /formalizer:pipeline — Chain tones into one output

Apply multiple tones sequentially, feeding the output of each stage into the next, and return one final merged version. Dispatches the `formalizer-pipeline` subagent so intermediate drafts never enter the parent context.

## Usage

```
/formalizer:pipeline grammatical readable concise          The report is overdue.
/formalizer:pipeline grammatical,readable,concise 4        The report is overdue.
/formalizer:pipeline grammatical:3 concise:5               The report is overdue.
/formalizer:pipeline grammatical readable --show-stages    The report is overdue.
/formalizer:pipeline                                        (prompts for tones and text)
```

## Argument parsing

Arguments arrive as `$ARGUMENTS`. Parse as follows:

1. **Tones** — positional, at the start of the argument string. Consume tokens (comma- or space-separated) as tones until the first non-tone token is reached. A known tone name appearing later in the source text is NOT reinterpreted as a tone. See SKILL.md for the 21 tones.
2. **Per-stage levels** — a tone token of the form `<tone>:<level>` (e.g. `concise:5`). Applies that level to that stage only.
3. **Uniform level** — a bare integer 1-5 anywhere in the args. Applied to every stage without a per-stage override.
4. **`--show-stages` flag** — anywhere in the args; toggles per-stage output.
5. **Remaining tokens** — the text to rewrite.

If a token is ambiguous (e.g. could be a tone or a level), prefer the tone interpretation.

## Behaviour

- **If fewer than 2 tones given:** ask the user via `AskUserQuestion`, offering the 21 tones grouped (formal / informal / structural / domain) as multi-select. Refuse single-tone pipelines — suggest `/formalizer:rewrite` instead.
- **If no level given:** default to 3 uniformly. Do not prompt.
- **If text is missing:** check recent conversation context. If no text is obvious, prompt the user to paste it.
- **If more than 8 tones given:** refuse and ask the user to split the pipeline.
- **If adjacent tones contradict** (per the agent's contradiction list): refuse, name the conflicting pair, suggest a reorder.

Dispatch the `formalizer-pipeline` agent via the `Agent` tool with parsed tones (in order), resolved levels, `--show-stages` flag, and source text. Return the agent's output verbatim — no wrapping, no commentary.

## Why an isolated agent

A pipeline runs N stages, each producing a draft. Running that in a subagent keeps every intermediate draft out of the parent session's context — only the final output (or the labelled stages with `--show-stages`) comes back.

## Pipeline vs compare

- `/formalizer:rewrite` — one tone, one output.
- `/formalizer:compare` — many tones, many outputs for side-by-side selection.
- `/formalizer:pipeline` — many tones, one merged output. Use when you want tones to compound (e.g. `grammatical → concise → irish-english`).
