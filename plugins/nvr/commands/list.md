---
description: This skill should be used when the user asks to "list neovim instances", "show all nvim", "what neovim processes are running", "list all editors", "show all active neovim", or wants to see all running neovim instances across all projects.
allowed-tools: Bash
---

# List All Neovim Instances

## Purpose

Display all running neovim instances with their working directories, socket paths, and process IDs. Useful for understanding which projects have active editors and troubleshooting multi-project setups.

## When to Use This Skill

Use this skill when the user wants to see all neovim instances across all projects:

- "List all neovim instances"
- "Show me all running nvim"
- "What neovim processes are active?"
- "Which projects have editors open?"
- "Show all active neovim sessions"

## Active Instances (Auto-Captured)

**Total Instances**: !```nvr --serverlist 2>/dev/null | wc -l```
**Current Directory**: !```pwd```

## How to Use

Invoke the list script:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/list/scripts/list.sh
```

No arguments needed - the script discovers and lists all active neovim instances.

### Success Output

When instances are found:
```
Active neovim instances:

[/home/user/project-A]
  Socket: /run/user/1000/nvim.123.0
  PID: 123

[/home/user/project-B]
  Socket: /run/user/1000/nvim.456.0
  PID: 456
```

Present this information to the user, optionally highlighting which instance corresponds to the current working directory.

### No Instances Output

When no instances are running:
```
No neovim instances found
```

Inform the user that no neovim processes are currently running and suggest starting neovim if needed.

## Use Cases

### Use Case 1: Multi-Project Overview

**User**: "Show me all my neovim instances"
**Action**: Run list script
**Response**: Display all instances with their project directories

### Use Case 2: Troubleshooting Wrong Instance

**User**: "Why is the wrong neovim opening my files?"
**Action**: Run list script to show all instances
**Response**: Help user identify which instance is for which project

### Use Case 3: Before Starting New Instance

**User**: "Should I start neovim for this project?"
**Action**: Run list script to check existing instances
**Response**: Show if an instance already exists for this project or directory

### Use Case 4: Understanding Project Layout

**User**: "Which projects am I working on?"
**Action**: Run list script to see all active projects
**Response**: Show all projects with open neovim instances

## Implementation Details

The list script:
1. Checks if nvr is installed
2. Queries all active sockets: `nvr --serverlist`
3. For each socket, queries:
   - Working directory: `nvr --remote-expr 'getcwd()'`
   - Process ID: `nvr --remote-expr 'getpid()'`
4. Formats and displays all instances

## Interpreting Results

### Identifying Current Project

When displaying results, indicate which instance corresponds to the current working directory:

```
Active neovim instances:

[/home/user/project-A] ← Current directory
  Socket: /run/user/1000/nvim.123.0
  PID: 123

[/home/user/project-B]
  Socket: /run/user/1000/nvim.456.0
  PID: 456
```

### Multiple Instances Same Directory

If multiple instances have the same working directory:
```
Active neovim instances:

[/home/user/project-A]
  Socket: /run/user/1000/nvim.123.0
  PID: 123

[/home/user/project-A]
  Socket: /run/user/1000/nvim.789.0
  PID: 789
```

Inform the user that multiple instances exist for the same directory. The `nvr-discover` utility will use the first match.

## Manual Invocation

Users can manually invoke this skill:

```bash
/nvr:list
```

Show the results directly in a clear, formatted manner.

## Related Skills

- **nvr:status** - Show only the active instance for current directory
- **nvr:open** - Open files in the discovered instance
- **nvr:workspace** - Show current workspace with neovim info

## Presenting Results

Format the output clearly:
1. Show total count first: "You have 3 neovim instances running:"
2. List each instance with its project directory
3. Highlight the current directory's instance if applicable
4. Note if no instances found

### Combining with Other Skills

After listing instances:
- If user wants details about current instance, suggest `/nvr:status`
- If user wants to open a file, proceed with `/nvr:open`
- If user wants full workspace context, suggest `/nvr:workspace`

## Error Handling

### nvr Not Installed

If nvr is not available:
```
Error: nvr not found
```

Inform the user they need to install neovim-remote:
```bash
pip install neovim-remote
```

### Socket Communication Failure

If a socket exists but doesn't respond:
- Skip that socket
- Continue listing other instances
- Note the issue to the user if all sockets fail

## Summary

Use this skill to provide a comprehensive overview of all running neovim instances. It's particularly useful for multi-project workflows and troubleshooting editor connectivity across different projects.
