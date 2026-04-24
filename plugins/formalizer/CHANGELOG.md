# Changelog

All notable changes to the formalizer plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-24

### Added

- **Pipeline mode** — apply multiple tones sequentially to the same text and return one merged output. Resolves #29.
  - `agents/formalizer-pipeline.md` — isolated subagent chaining tones in order; each stage feeds into the next.
  - `commands/pipeline.md` — `/formalizer:pipeline <tones...> [level | tone:level] [--show-stages] <text>`.
  - Supports uniform register level or per-stage `tone:level` overrides.
  - Accepts both space- and comma-separated tone lists.
  - `--show-stages` flag exposes intermediate outputs for verification; default returns only the final.
- **Contradiction guardrail** — refuses pipelines with adjacent contradictory tones (e.g. `formal → informal`, `angry → calm`), naming the conflicting pair and suggesting a reorder.
- **Pipeline constraints** — minimum 2 tones (single-tone pipelines redirect to `/formalizer:rewrite`), maximum 8 stages.

## [1.0.2] - 2026-04-20

### Fixed

- Moved `formalizer-compare` agent from `skills/formalizer/agents/` to the top-level `agents/` directory so Claude Code auto-discovers it. Agent was not loading before this fix.

## [1.0.1] - 2026-04-20

### Added

- `argument-hint` frontmatter on `SKILL.md`, `commands/rewrite.md`, and `commands/compare.md` for inline CLI discoverability, each with a concrete example.

## [1.0.0] - 2026-04-20

### Added

- Initial port of the standalone `formalizer` skill to a full marketplace plugin.
- 21 tones: professional, formal, technical, academic, legal, informal, polite, less snarky, angry, calm, passionate, sarcastic, sociable, empathetic, diplomatic, accessible, readable, concise, grammatical, bullets, thesaurus, marketing, irish-english.
- Register level (1-5) anchored to Joos's Five Clocks (intimate / casual / consultative / formal / frozen).
- Preservation rules for markdown structure, code fences, quotations, and proper nouns.
- Anti-patterns: no disclaimers, no moralising, no fact-checking, no meta-commentary, no length expansion outside formal/academic/legal.
- Context-isolated `formalizer-compare` subagent for batch/compare and `--iterate` (critique-refine) modes; max 12 rewrites per call.
- `/formalizer:rewrite` command — single-tone inline rewrite with AskUserQuestion fallback when tone is missing.
- `/formalizer:compare` command — dispatches the compare subagent.
- Bundled references:
  - `references/sources.md` — Joos, Halliday, Biber, Plain Language Guidelines, Hyland, Wydick, Brown & Levinson, Rosenberg.
  - `references/tone-examples.md` — one before/after per tone for consistency anchoring.
