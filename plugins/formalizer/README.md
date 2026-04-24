[![Version](https://img.shields.io/badge/version-1.0.2-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# formalizer Plugin

Rewrite text into a different tone or register. 21 tones, 1-5 intensity, anchored to register theory.

## Overview

A skill, two commands, and an isolated subagent for tone-shifting prose. Triggers naturally on phrases like "make this more professional" or "unwaffle this", or via namespaced commands. The compare/iterate workflow runs in a subagent so working drafts never pollute the parent context.

**Key features:**

- 21 tones grouped: formal, informal/emotional, structural, domain-specific
- Register level 1-5 anchored to **Joos's Five Clocks** (intimate → frozen)
- Preservation rules for markdown, code fences, quotes, and proper nouns
- Anti-patterns prevent disclaimers, moralising, and meta-commentary
- Context-isolated `formalizer-compare` subagent for batch and `--iterate` modes
- Academic references bundled (Joos, Halliday, Biber, Plain Language, Hyland, Wydick, Brown & Levinson, Rosenberg)
- Not a generator — refuses to draft new content from scratch

## Commands

- `/formalizer:rewrite [tone] [level] [text]` — single-tone inline rewrite
- `/formalizer:compare [tones...] [levels...] [--iterate] [text]` — batch/compare via subagent

## Tones (21 total)

**Formal:** professional, formal, technical, academic, legal

**Informal / emotional:** informal, polite, less snarky, angry, calm, passionate, sarcastic, sociable, empathetic, diplomatic

**Structural:** accessible, readable, concise, grammatical, bullets, thesaurus

**Domain:** marketing, irish-english

See `skills/formalizer/SKILL.md` for full definitions and `skills/formalizer/references/tone-examples.md` for one before/after per tone.

## Register rubric

| Level | Joos register | Application |
|---|---|---|
| 1 | intimate | Barely perceptible nudge |
| 2 | casual | Light application |
| 3 | consultative | **Default** — apply clearly |
| 4 | formal | Strong; lean in |
| 5 | frozen | Maximum coherent intensity |

## Quick start

```
# Inline via natural language (skill triggers)
> make this more professional: the report is overdue and i'm pretty annoyed
→ The report is overdue, which is causing concern. Could we resolve this today?

# Single-tone via command
/formalizer:rewrite concise   The thing is, the report is overdue and I need it today.
→ The report is a week late. Send it today.

# Compare via command
/formalizer:compare professional,diplomatic,concise   The report is overdue.

# Iterate via command
/formalizer:compare diplomatic --iterate   The report is overdue.
```

## Triggering

The skill auto-triggers on rewrite verbs (rewrite, reword, polish, soften, sharpen, formalise, unwaffle, tidy) combined with any of the 21 tone names. It deliberately does NOT trigger on generative requests like "write me a new essay about X" — this is a rewriter, not a generator.

## References

Academic grounding for the tone taxonomy and the 1-5 register rubric is in `skills/formalizer/references/sources.md`. Cite when producing rewrites for academic work.

## License

MIT — see [LICENSE](./LICENSE).
