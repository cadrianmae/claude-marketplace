# Changelog

All notable changes to the formalizer plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
