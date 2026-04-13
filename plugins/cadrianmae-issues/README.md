[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# cadrianmae-issues

File bugs and feature requests as GitHub issues on cadrianmae/claude-marketplace via `gh` CLI.

## Overview

This plugin provides skills to file bugs and feature requests for marketplace plugins directly as GitHub issues. Claude asks clarifying questions, composes a structured issue body, applies labels, and files it -- then returns to your current work.

**IMPORTANT:** This plugin is for LOGGING ONLY. Claude will not attempt to implement fixes or features when using these commands.

## Requirements

- `gh` CLI installed and authenticated (`gh auth status`)

## Skills

### `/cadrianmae-issues:bug`

File a bug report for a marketplace plugin.

**Usage:**
```bash
/cadrianmae-issues:bug "cron plugin - schedule matching fails for weekly expressions"
```

**What it does:**
1. Asks clarifying questions (steps to reproduce, expected behaviour)
2. Infers which marketplace plugin is affected (or asks)
3. Creates a GitHub issue with `bug` + `plugin:<name>` labels
4. Returns the issue URL and continues with your current work

### `/cadrianmae-issues:feature`

File a feature request for a marketplace plugin.

**Usage:**
```bash
/cadrianmae-issues:feature "tts plugin - add volume control per-voice"
```

**What it does:**
1. Asks clarifying questions (use case, proposed behaviour)
2. Infers which marketplace plugin is affected (or asks)
3. Creates a GitHub issue with `enhancement` + `plugin:<name>` labels
4. Returns the issue URL and continues with your current work

## Labels

- **Type:** `bug` or `enhancement`
- **Plugin:** `plugin:<name>` -- inferred from context or user description

## Installation

This plugin is part of the cadrianmae-claude-marketplace.

## Author

Mae Capacite (cadrianmae@users.noreply.github.com)

## License

MIT
