[![Version](https://img.shields.io/badge/version-1.0.3-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# cadrianmae-integration

Integrate marketplace plugins into CLAUDE.md with user/project scope selection.

## Overview

This plugin helps you generate documentation for all installed marketplace plugins and add them to CLAUDE.md. Choose between user-level (global) or project-level (current directory) integration.

## Commands

### `/integrate`

Generate documentation for installed cadrianmae marketplace plugins and add to CLAUDE.md.

**Usage:**
```bash
/integrate
```

**What it does:**
1. Asks for scope - User-level (~/.claude/CLAUDE.md) or Project-level (./CLAUDE.md)
2. Scans all installed marketplace plugins
3. Extracts information from plugin.json, skills, and commands
4. Generates formatted markdown documentation
5. Appends or updates the plugins section in CLAUDE.md

**Output:**
Creates a `marketplace-plugins.md` section in CLAUDE.md with:
- Plugin descriptions
- Available commands and skills
- Usage examples

## Skills

### `integration`

Internal skill for generating marketplace plugin documentation.

## Installation

This plugin is part of the cadrianmae-claude-marketplace. No additional installation needed.

## Author

cadrianmae

## Version

1.0.0

## Keywords

integration, documentation, marketplace, plugins, CLAUDE.md

## License

MIT License - see [LICENSE](./LICENSE) for details.
