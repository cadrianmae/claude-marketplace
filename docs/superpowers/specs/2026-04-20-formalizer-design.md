# Formalizer Plugin — Design Spec

**Date:** 2026-04-20
**Status:** Draft for review
**Author:** Mae Capacite

## Summary

Port an existing `formalizer` skill into the `cadrianmae-claude-marketplace` as a full plugin with expanded tone coverage, academic grounding, an isolated batch/compare agent, and namespaced commands. The plugin rewrites text into a specified tone and register level; it does not generate new content.

## Goals

- Provide a reliable inline tone-rewriter via skill triggering on natural language
- Add citable academic grounding (Joos, Halliday, Biber, Plain Language, etc.)
- Add 6 domain-specific tones (academic, legal, marketing, empathetic, Irish English, diplomatic)
- Offer batch/compare and iterative-refinement via a context-isolated subagent
- Keep main-session context overhead minimal (progressive disclosure)

## Non-Goals

- Drafting new content from scratch (generator ≠ rewriter)
- Fact-checking, moralising, or editorialising input
- Real-time UI or streaming output
- Translation between languages (though the skill preserves input language)

## Plugin Structure

```
plugins/formalizer/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── formalizer/
│       ├── SKILL.md
│       └── references/
│           ├── sources.md
│           └── tone-examples.md
├── agents/
│   └── formalizer-compare.md
├── commands/
│   ├── rewrite.md
│   └── compare.md
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Components

### 1. Skill (`skills/formalizer/SKILL.md`)

Lean, always-loadable rewriter. Handles single-tone, single-level inline rewrites.

**Tone list (21 total):**

Original 15: `professional`, `formal`, `informal`, `technical`, `accessible`, `polite`, `less-snarky`, `angry`, `calm`, `passionate`, `sarcastic`, `sociable`, `readable`, `concise`, `grammatical`, `bullets`, `thesaurus`.

New 6: `academic`, `legal`, `marketing`, `empathetic`, `irish-english`, `diplomatic`.

**Register rubric (1–5), anchored to Joos's Five Clocks:**

| Level | Joos register | Application |
|---|---|---|
| 1 | intimate | barely perceptible nudge |
| 2 | casual | light touch |
| 3 | consultative | default, clear application |
| 4 | formal | strong lean into tone characteristics |
| 5 | frozen | maximum, pushed as far as coherence allows |

Default level when unspecified: **3**.

**Preservation rules:**

- Markdown structure (headings, lists, links) preserved; rewrite prose only
- Never touch content inside code fences (```)
- Never rewrite text inside quote marks or blockquotes
- Preserve proper nouns, product names, technical terms, identifiers

**Anti-patterns (explicit "do NOT" rules):**

- Do not add disclaimers ("I am an AI...", "please note...")
- Do not moralise or editorialise the content
- Do not fact-check or correct factual claims
- Do not add meta-commentary about the rewrite itself
- Do not expand length unless the target tone demands it

**Output contract:** output ONLY the rewritten text. No preamble. No labels. No surrounding quotes.

**Triggering description:**

> Rewrite text into a different tone or register. Use when asked to make text more professional, formal, academic, concise, casual, angry, calm, empathetic, diplomatic, marketing, legal, technical, accessible, polite, passionate, sarcastic, sociable, readable, grammatical, bulleted, or Irish English. Triggered by rewrite verbs like "make this more professional", "unwaffle this", "soften", "sharpen", "polish", "reword", "formalise", or similar phrasing. Supports register levels 1–5 anchored to Joos's Five Clocks (intimate → frozen). Not for drafting new content from scratch — this is a rewriter, not a generator.

### 2. Compare agent (`agents/formalizer-compare.md`)

Context-isolated subagent for batch and iterative rewrites.

**When triggered:**

- User asks for multiple tones side-by-side
- User asks for multiple intensities of one tone
- Explicit batch rewrites ("show me this as professional and concise")
- `/formalizer:compare` command dispatches here

**Inputs:**

- Source text (required)
- Tones: one or many (default: `professional, concise, diplomatic`)
- Levels: one or many (default: `3`)
- `--iterate` flag: enable critique/refine mode

**Default mode (batch/compare):**

1. Parse tone × level combinations
2. Produce one rewrite per combination
3. Return as markdown table (columns = tones, rows = levels) or simple list if only one axis varies
4. No commentary unless labels are needed

**Iterate mode (`--iterate`):**

1. Produce initial rewrite
2. Self-critique against tone definition + preservation rules + anti-patterns
3. Produce one refinement
4. Return final version only (draft + critique never surface)

**Context isolation:**

- Agent runs via the `Agent` tool → own context window
- `allowed-tools` limited to Read (for loading `references/tone-examples.md`) — no Bash, no Edit, no Write
- Returns ONLY final output; no reasoning trace, no draft, no working notes
- Reference material loaded inside agent's context, never leaks to parent session

**Constraint:** max 12 rewrites per call (e.g. 3 tones × 4 levels). Beyond that, refuse and suggest narrowing the axes.

### 3. Commands

#### `/formalizer:rewrite [tone] [level]`

- `argument-hint: "[tone] [level]"`
- If `tone` missing → AskUserQuestion with the 21 tone names (grouped: formal registers / emotional / structural / domain)
- If `level` missing → default to 3; no prompt
- Input text resolution order: (a) text in conversation context referenced by the user, (b) text passed as remaining positional args after tone/level, (c) AUQ prompt for inline paste
- Defers to skill for actual rewrite

#### `/formalizer:compare [tones...] [levels...] [--iterate]`

- If no tones → AUQ multi-select, offering default set
- If no levels → default `[3]`
- Dispatches `formalizer-compare` agent with parsed args
- Returns agent output to user

Both commands never auto-load references; delegation preserves context discipline.

### 4. References

`references/sources.md` — citable academic grounding, loaded on demand only:

- Joos, M. (1962). *The Five Clocks.* Harcourt, Brace & World.
- Halliday, M.A.K. & Hasan, R. (1985). *Language, Context, and Text.* Deakin University Press.
- Biber, D. (1988). *Variation Across Speech and Writing.* Cambridge University Press.
- Plain Language Action and Information Network (2011). *Federal Plain Language Guidelines.*
- Hyland, K. (2005). *Metadiscourse: Exploring Interaction in Writing.* Continuum.
- Wydick, R. (2005). *Plain English for Lawyers* (5th ed.).
- Brown, P. & Levinson, S. (1987). *Politeness: Some Universals in Language Usage.* CUP.
- Rosenberg, M. (2003). *Nonviolent Communication: A Language of Life.* PuddleDancer Press.

`references/tone-examples.md` — one short before/after per tone (21 entries, ~4 lines each direction). Loaded by skill or agent only when consistency needs shoring up.

## plugin.json

```json
{
  "name": "formalizer",
  "version": "1.0.0",
  "description": "Rewrite text into a different tone or register (21 tones) with optional 1-5 intensity anchored to Joos's Five Clocks.",
  "author": {
    "name": "Mae Capacite",
    "email": "cadrianmae@users.noreply.github.com"
  },
  "homepage": "https://github.com/cadrianmae/claude-marketplace",
  "repository": "https://github.com/cadrianmae/claude-marketplace",
  "license": "MIT",
  "keywords": ["text", "tone", "rewrite", "register", "formal", "professional", "academic", "writing", "style"],
  "skills": "./skills/",
  "agents": "./agents/",
  "commands": "./commands/"
}
```

## marketplace.json entry

Append to `plugins` array in `/.claude-plugin/marketplace.json`:

```json
{
  "name": "formalizer",
  "source": "./plugins/formalizer",
  "description": "Rewrite text into a different tone or register (21 tones: professional, academic, concise, empathetic, diplomatic, Irish English, etc.) with optional 1-5 intensity anchored to Joos's Five Clocks. Skill for inline rewrites, isolated agent for batch/compare and iterative refinement, namespaced commands.",
  "version": "1.0.0",
  "author": {
    "name": "Mae Capacite",
    "email": "45900436+cadrianmae@users.noreply.github.com"
  },
  "license": "MIT",
  "keywords": ["text", "tone", "rewrite", "register", "formal", "academic", "writing", "style"]
}
```

## Context Discipline

Key constraint: usage in a large-scope parent session must not pollute future responses.

- SKILL.md: target <250 lines, contains only active rewriting logic
- References: never auto-loaded; skill/agent reads them only when explicitly needed
- Agent: runs as subagent with own context; returns final output only
- Commands: thin wrappers, no reference material loaded at command dispatch
- No hooks, no background processes, no state persisted between invocations

## Scope Decisions (from brainstorming)

| Area | Decision |
|---|---|
| Tone grounding | Hybrid: practical names + Joos/Halliday/Biber/Plain Language anchoring |
| New tones | All 6 (academic, legal, marketing, empathetic, irish-english, diplomatic) |
| Triggering | Middle path: verb list + tone names + anti-triggers |
| I/O preservation | Markdown (1), code blocks (2), quotes (6), proper nouns (7) |
| Agent role | Parallel (2) + batch/compare (4) with `--iterate` flag (3+4 combo) |
| Prompt quality | All refinements (A6): examples, Joos rubric, anti-patterns, length rule, ambiguity fixes |
| Structure approach | B (full surface) with single command namespace |
| Command shape | Namespaced subcommands (`/formalizer:rewrite`, `/formalizer:compare`) + AUQ fallback |

## Open Questions

None at design time.

## Next Steps

1. User reviews this spec
2. On approval: invoke `superpowers:writing-plans` to produce an implementation plan
3. Execute plan via `superpowers:executing-plans` or inline
