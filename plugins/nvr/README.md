

# NVR - Neovim Remote Integration for Claude Code

Automatically open files in the correct neovim instance based on Claude Code's working directory using neovim-remote (nvr).

## Overview

The NVR plugin enables Claude to seamlessly open files in your active neovim editor without manual socket management. It automatically discovers which neovim instance corresponds to your current project and opens files at specific lines.

### Key Features

- **Automatic socket discovery** - Finds the correct nvim instance based on working directory
- **Multi-project support** - Works across multiple simultaneous neovim instances
- **Natural language interface** - Claude interprets "open database.py at line 45" automatically
- **Graceful error handling** - Helpful messages when no nvim instance found
- **Status and debugging tools** - Check active instances and workspace context

## Prerequisites

### Required

- **neovim** - Any recent version with remote support
- **neovim-remote (nvr)** - Python package for socket communication

Install nvr:
```bash
pip install neovim-remote
```

### Recommended

- **tmux** - For managing multiple neovim instances (optional)
- **Project-based workflow** - One nvim instance per project directory

## Installation

This plugin is part of the cadrianmae-claude-marketplace.

The plugin auto-loads when Claude Code starts if the marketplace is configured in your settings.

## Usage

### Primary Workflow (Claude-Invoked)

The main use case is Claude automatically opening files when you request it:

```
User: "Open database.py at line 45"
Claude: [Auto-discovers socket and opens file]
Output: ✓ Opened database.py:45 in neovim
```

```
User: "Show me the TODO in config.yaml about logging"
Claude: [Searches file for TODO, then opens at that line]
Output: ✓ Opened config.yaml:23 in neovim
```

### Manual Commands (User-Invoked)

#### Check Status

See which neovim instance is active for current directory:

```bash
/nvr:status
```

Output:
```
✓ Neovim instance found

Socket: /run/user/1000/nvim.123.0
Process ID: 123
Working Directory: /home/user/project-A
Open Buffers: 5
```

#### List All Instances

View all running neovim instances:

```bash
/nvr:list
```

Output:
```
Active neovim instances:

[/home/user/project-A]
  Socket: /run/user/1000/nvim.123.0
  PID: 123

[/home/user/project-B]
  Socket: /run/user/1000/nvim.456.0
  PID: 456
```

#### Discover Workspace Context

Show current workspace information:

```bash
/nvr:workspace
```

Output:
```
Workspace Context
=================

Working Directory: /home/user/project-A
Git Repository: /home/user/project-A
Git Branch: main

Neovim Instance: Active
  Socket: /run/user/1000/nvim.123.0
  PID: 123
  Working Directory: /home/user/project-A
```

#### Open File Manually

Explicitly open a file at a specific line:

```bash
/nvr:open database.py 45
```

## How It Works

### Socket Discovery

The plugin uses intelligent socket discovery:

1. Query all active nvr sockets: `nvr --serverlist`
2. For each socket, query working directory: `nvr --servername <socket> --remote-expr 'getcwd()'`
3. Match socket where `getcwd()` matches Claude's current working directory (or parent)
4. Use matched socket for file operations

### Environment Override

Force a specific socket using environment variable:

```bash
export NVIM_SOCKET=/run/user/1000/nvim.custom.0
```

When set, the plugin uses this socket instead of auto-discovery.

## Examples

### Example 1: Single Project

```bash
# Terminal: Start neovim
cd ~/project-A
nvim

# Claude Code session in ~/project-A
User: "Open database.py at line 45"
# ✓ Opens in project-A's neovim automatically
```

### Example 2: Multiple Projects

```bash
# Terminal 1: Start neovim in project-A
cd ~/project-A
nvim

# Terminal 2: Start neovim in project-B
cd ~/project-B
nvim

# Claude session in project-A
User: "Open server.js at line 10"
# ✓ Opens in project-A's neovim

# Claude session in project-B
User: "Open client.js at line 20"
# ✓ Opens in project-B's neovim
```

### Example 3: No Instance Found

```bash
# No neovim running in current project

User: "Open database.py at line 45"
Output:
Error: No neovim instance found for directory: /home/user/project-A

Available instances:
  - /home/user/project-B (socket: /run/user/1000/nvim.456.0)

Start neovim with: nvim

# Claude responds with helpful guidance
```

## Troubleshooting

### No nvim instances found

**Error**: `No neovim instances found`

**Solution**: Start neovim in your project directory:
```bash
nvim
```

Neovim automatically creates a socket when started.

### nvr not installed

**Error**: `nvr (neovim-remote) not found`

**Solution**: Install neovim-remote:
```bash
pip install neovim-remote
```

### Socket connection failure

**Error**: `Failed to connect to socket`

**Solution**:
1. Check neovim is still running: `ps aux | grep nvim`
2. Verify socket exists: `nvr --serverlist`
3. Restart neovim if needed

### Wrong neovim instance used

**Issue**: File opens in different project's neovim

**Solution**:
1. Check which instance is active: `/nvr:status`
2. Verify working directories match: `/nvr:list`
3. Start neovim in correct project directory if needed

## Advanced Usage

### Using with Tmux

Recommended workflow for managing multiple projects:

```bash
# Session 1: project-A
tmux new -s project-A
cd ~/project-A
nvim

# Session 2: project-B
tmux new -s project-B
cd ~/project-B
nvim

# Claude Code automatically finds correct instance per project
```

### Custom Socket Names

If you use custom socket names:

```bash
# Start neovim with custom socket
nvim --listen /tmp/my-project.sock

# Set environment variable for Claude
export NVIM_SOCKET=/tmp/my-project.sock
```

## Plugin Components

### Skills

- **open** - Open files at specific lines (primary skill)
- **status** - Show active neovim instance for current directory
- **list** - List all running neovim instances
- **workspace** - Discover current workspace context

### Utilities

- **nvr-discover** - Core socket discovery utility (shared by all skills)

## Contributing

Found a bug or have a feature request? Please open an issue in the marketplace repository.

## License

MIT License - See LICENSE file for details.

## Credits

Built for Claude Code by Mae (cadrianmae)

Uses [neovim-remote](https://github.com/mhinz/neovim-remote) by Marco Hinz
