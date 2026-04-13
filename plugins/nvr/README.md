[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# NVR Plugin v2.0

Neovim Remote integration for Claude Code. Unified `/nvr` command for opening files, listing instances, checking status, and viewing workspace context. Git-root-aware socket discovery.

## Overview

The NVR plugin enables Claude to seamlessly open files in your active neovim editor. It automatically discovers which neovim instance corresponds to your current project using a two-pass strategy: git root matching first (immune to `:lcd` changes), then closest parent cwd matching as fallback.

**Key features:**
- **Unified `/nvr` skill** -- one interactive entry point with subcommand grammar
- **Git-root-aware discovery** -- robust against `:lcd` changes from autocmds
- **Closest parent matching** -- picks the most specific instance when multiple match
- **Auto-invocation** -- Claude uses `/nvr open` automatically when you ask to open files
- **Multi-project support** -- works across multiple simultaneous neovim instances
- **Environment override** -- set `$NVIM_SOCKET` to bypass discovery

## Prerequisites

| Requirement | How to verify |
|---|---|
| neovim | `nvim --version` |
| neovim-remote (nvr) | `nvr --version` (install: `pip install neovim-remote`) |

## Command

- `/nvr` -- Interactive entry point for open / list / status / workspace / help. Accepts arguments to skip prompts (e.g. `/nvr open README.md 42`).

## Quick Start

```bash
# Open a file at a specific line
/nvr open src/main.py 42

# List all active neovim instances
/nvr list

# Check current instance details
/nvr status

# Show workspace context (git + neovim)
/nvr workspace
```

## Subcommand Grammar

```
/nvr                              -> AUQ menu (interactive)
/nvr open <file> [line]           -> open file at optional line
/nvr list                         -> list all neovim instances
/nvr status                       -> current instance details
/nvr workspace                    -> workspace context
/nvr help                         -> usage reference
```

## Socket Discovery

The `nvr-discover` utility finds the correct neovim instance using a two-pass strategy:

1. **Git root match (preferred):** Query each neovim instance for its git root. Pick the instance whose git root is the longest prefix of the target directory. Immune to `:lcd` changes from autocmds (e.g. cmp-pandoc-references).

2. **Closest parent cwd match (fallback):** If no git root match, fall back to `getcwd()` matching. Pick the instance whose working directory is the longest prefix of the target directory.

3. **Environment override:** Setting `$NVIM_SOCKET` to a socket path bypasses all discovery.

## See Also

- [CHANGELOG.md](./CHANGELOG.md) -- Version history
- `/nvr help` -- In-app subcommand reference
- [neovim-remote](https://github.com/mhinz/neovim-remote) -- Upstream nvr project
