---
name: nvr-status
description: This skill should be used when the user asks "what neovim is active", "which editor am I using", "show nvim status", "what's my active editor", "check neovim instance", or wants to know which neovim instance is connected to the current project.
version: 1.0.0
allowed-tools: Bash
user-invocable: false
---

# Show Active Neovim Instance Status

## Purpose

Display the active neovim instance for the current working directory, including socket path, process ID, working directory, and buffer information.

## When to Use This Skill

Use this skill when the user wants to verify their editor setup or troubleshoot neovim connection issues:

- "What neovim instance is active?"
- "Show me my editor status"
- "Which nvim am I connected to?"
- "Check if neovim is running"
- "What's my active editor?"

## Workspace Status (Auto-Captured)

**Working Directory**: !```pwd```
**Active Socket**: !```$CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null || echo "None found"```
**Neovim PID**: !```$CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null | xargs -I{} nvr --servername {} --remote-expr 'getpid()' 2>/dev/null || echo "N/A"```
**Workspace Root**: !```$CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null | xargs -I{} nvr --servername {} --remote-expr 'getcwd()' 2>/dev/null || echo "N/A"```

## How to Use

Invoke the status script:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/status/scripts/status.sh
```

No arguments needed - the script automatically detects the neovim instance for the current working directory.

### Success Output

When an instance is found:
```
✓ Neovim instance found

Socket: /run/user/1000/nvim.123.0
Process ID: 123
Working Directory: /home/user/project-A
Open Buffers: 5
```

Present this information to the user in a clear format, confirming their active neovim setup.

### Error Output

When no instance is found:
```
No neovim instance found for current directory

Error: No neovim instance found for directory: /home/user/project-A

Available instances:
  - /home/user/project-B (socket: /run/user/1000/nvim.456.0)
```

Inform the user that no neovim instance was detected for their current project and suggest:
1. Starting neovim in the current directory
2. Checking available instances (listed in the error)
3. Verifying they're in the correct project directory

## Use Cases

### Use Case 1: Verify Connection

**User**: "Is neovim running?"
**Action**: Run status script and show results
**Response**: Confirm whether neovim is active and provide details

### Use Case 2: Troubleshooting

**User**: "Why can't you open files in my editor?"
**Action**: Run status script to diagnose connection
**Response**: Show current status and identify issues (no instance, wrong directory, etc.)

### Use Case 3: Multiple Projects

**User**: "Which project's neovim am I using?"
**Action**: Run status script to show working directory
**Response**: Confirm the neovim instance's working directory matches expectations

### Use Case 4: Before File Operations

When preparing to open files, run status check first to verify connectivity:
1. Check status
2. If instance found, proceed with file opening
3. If no instance, inform user before attempting file operations

## Implementation Details

The status script:
1. Uses `nvr-discover` to find the socket for current directory
2. Queries neovim via nvr for instance information:
   - Process ID: `nvr --remote-expr 'getpid()'`
   - Working directory: `nvr --remote-expr 'getcwd()'`
   - Open buffers: `nvr --remote-expr 'len(getbufinfo({"buflisted": 1}))'`
3. Formats and displays the information

## Manual Invocation

Users can manually invoke this skill:

```bash
/nvr:status
```

Show the results directly without additional interpretation.

## Related Skills

- **nvr:open** - Open files once status is confirmed
- **nvr:list** - See all neovim instances if troubleshooting
- **nvr:workspace** - Get full workspace context including git info

## Tips for Interpretation

### When to Suggest This Skill

Proactively suggest running status check when:
- User reports file opening issues
- User asks about editor setup
- Starting a new session in unfamiliar project
- User mentions multiple neovim instances

### Interpreting Results

**Good status** (instance found):
- Proceed with file operations
- Confirm setup is working

**No instance found**:
- Suggest starting neovim
- List available instances
- Verify user is in correct directory

**Multiple instances available**:
- Confirm user is in correct project directory
- Suggest using `/nvr:list` to see all instances

## Summary

Use this skill to verify the active neovim instance for the current project. It provides quick confirmation of editor connectivity and helps troubleshoot issues before attempting file operations.
