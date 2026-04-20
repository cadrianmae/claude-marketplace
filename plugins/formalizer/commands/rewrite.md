---
description: Rewrite text into a specified tone and register level using the formalizer skill
argument-hint: "[tone] [level] [text]"
allowed-tools: Read, AskUserQuestion
---

# /formalizer:rewrite — Rewrite text in a tone

Rewrite the provided text into a specified tone and register level (1-5).

## Usage

```
/formalizer:rewrite professional 4 The thing is, the report is overdue and I need it today.
/formalizer:rewrite concise   The thing is, the report is overdue and I need it today.
/formalizer:rewrite           (then prompts for tone, uses level 3, asks for text)
```

## Argument parsing

Arguments arrive as `$ARGUMENTS`. Parse them in this order:

1. **First token** — tone name. Match against the 21 supported tones (see SKILL.md). If the first token is not a known tone, treat ALL arguments as text and prompt for tone.
2. **Second token** — register level (1-5). If the second token is not a digit 1-5, treat tokens 2..N as text and use level 3.
3. **Remaining tokens** — the text to rewrite.

## Behaviour

- **If tone is missing or unrecognised:** ask the user via `AskUserQuestion`, offering the 21 tones grouped:
  - **Formal:** professional, formal, technical, academic, legal
  - **Informal/emotional:** informal, polite, less snarky, angry, calm, passionate, sarcastic, sociable, empathetic, diplomatic
  - **Structural:** accessible, readable, concise, grammatical, bullets, thesaurus
  - **Domain:** marketing, irish-english
- **If level is missing:** default to 3 (consultative). Do not prompt.
- **If text is missing:** look at the previous turn in the conversation for a quoted passage or recent user input that was clearly the intended target. If none is obvious, ask the user to paste the text.

Once tone, level, and text are resolved, invoke the formalizer skill with the parsed inputs and return ONLY the rewritten text — no preamble, no labels.
