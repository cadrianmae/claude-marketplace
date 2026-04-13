---
name: nvr
description: This skill should be used when the user asks to "open a file in neovim", "open in editor", "show in nvim", "open at line", "jump to line", "edit file", "list neovim instances", "check neovim status", "show workspace info", or mentions nvr, neovim remote, or opening files in their editor. Single unified entry point for neovim remote integration.
version: 2.0.0
user-invocable: true
allowed-tools: Bash, AskUserQuestion
argument-hint: <open|list|status|workspace|help> [args...]
---

# NVR -- Neovim Remote Integration

Neovim remote integration for Claude Code. Automatically discovers the correct neovim instance based on working directory and git root, then opens files, checks status, or lists instances.

## Current Workspace (Auto-Captured)

**Working Directory**: !`pwd`
**Discovered Socket**: !`timeout 3 nvr-discover 2>/dev/null || echo "None"`
**Active Instances**: !`timeout 2 nvr --serverlist 2>/dev/null | wc -l` neovim process(es)
**Instance List**: !`timeout 3 nvr-list 2>/dev/null || echo "None"`

## First Step

When invoked with no arguments, the FIRST action must be a single AskUserQuestion tool call (no preamble). Use this EXACT string for the `question` field:

"What would you like to do with nvr?"

Set `header: "Action"` and offer these options:

- `open` -- Open a file in neovim at an optional line number
- `list` -- List all active neovim instances
- `status` -- Show current neovim instance details
- `workspace` -- Show workspace context (git, neovim, cwd)
- `help` -- Show subcommand grammar and usage

If the user's message already includes a subcommand (e.g. `/nvr open README.md 42`), skip the AUQ and jump straight into the matching workflow. See "Subcommand Grammar" below.

## Helper Commands

All real work is done by thin wrappers in the plugin's `bin/` directory. Claude Code puts that directory on `PATH` automatically, so invoke them as bare commands -- **no path construction, no `$CLAUDE_PLUGIN_ROOT`**. (`$CLAUDE_PLUGIN_ROOT` is not substituted inside SKILL.md files; see [anthropics/claude-code#9354](https://github.com/anthropics/claude-code/issues/9354).)

- `nvr-open <file> [line]` -- open file at optional line in discovered instance
- `nvr-list` -- list all active neovim instances with directories
- `nvr-status` -- show PID, cwd, buffer count for current instance
- `nvr-workspace` -- show git root, branch, neovim instance for cwd
- `nvr-discover [dir]` -- discover socket for a directory (used internally)

Do NOT construct paths to scripts. Use the bare commands above.

## Auto-Invocation

This skill should be automatically invoked whenever opening files in the user's editor. When using tools like Read or Grep and the user asks to "open that file" or "show me that in neovim", invoke `nvr-open` with the file path.

## Subcommand Grammar

```
/nvr                              -> AUQ menu (interactive)
/nvr open <file> [line]           -> open file at optional line
/nvr list                         -> list all neovim instances
/nvr status                       -> current instance details
/nvr workspace                    -> workspace context
/nvr help                         -> usage reference
```

## Workflow: OPEN

1. If the user supplied a file path, call `nvr-open <file> [line]` directly.
2. If no file was supplied, AUQ: `header: "File"`, question: "Which file should I open?" -- accept free-text.
3. Parse natural language for file path and line number:
   - "database.py at line 45" -> `nvr-open database.py 45`
   - "src/utils/helper.py" -> `nvr-open src/utils/helper.py`
   - "the error on line 23 of server.js" -> `nvr-open server.js 23`
4. Show the wrapper's output (success: socket path and file opened; failure: diagnostic info).

If the socket discovery fails, show the error and suggest running `/nvr list` to see available instances or setting `$NVIM_SOCKET` manually.

## Workflow: LIST

Run `nvr-list` and show its output. Takes no arguments. The wrapper queries all active sockets and displays each with its PID, working directory, and socket path.

If no instances are found, suggest starting neovim with `nvim`.

## Workflow: STATUS

Run `nvr-status` and show its output. Takes no arguments. The wrapper discovers the socket for the current directory, then queries neovim for PID, working directory, and buffer count.

If no matching instance is found, suggest running `/nvr list` to see what's available.

## Workflow: WORKSPACE

Run `nvr-workspace` and show its output. Takes no arguments. The wrapper gathers:
- Current working directory
- Git root and current branch (if in a git repo)
- Discovered neovim instance (if any)

Useful for debugging socket discovery or understanding project context.

## Workflow: HELP

Print the subcommand grammar block from above, the helper commands list, and 2-3 usage examples. Do NOT call any helper script.

Examples:
```
/nvr open src/main.py 42          # Open file at line 42
/nvr list                         # Show all neovim instances
/nvr status                       # Current instance details
/nvr workspace                    # Git + neovim context
```

## Socket Discovery

The `nvr-discover` utility finds the correct neovim instance for a directory using a two-pass strategy:

1. **Git root match (preferred):** Query each neovim instance for its git root. Pick the instance whose git root is the longest prefix of the target directory. This is immune to `:lcd` changes from autocmds.

2. **Closest parent cwd match (fallback):** If no git root match, fall back to `getcwd()` matching. Pick the instance whose working directory is the longest prefix of the target directory.

3. **Environment override:** Setting `$NVIM_SOCKET` to a socket path bypasses all discovery and uses that socket directly.

## Important Notes

- The plugin requires `nvr` (neovim-remote) on PATH. Install with `pip install neovim-remote`.
- Socket discovery uses git root matching first, making it robust against `:lcd` changes from plugins like cmp-pandoc-references.
- When multiple instances match, the one with the longest (most specific) path wins.
- All workflows are CWD-dependent -- they use the current working directory for socket discovery.
