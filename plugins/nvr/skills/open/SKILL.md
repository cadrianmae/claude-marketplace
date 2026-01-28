---
name: nvr-open
description: This skill should be used when the user asks to "open a file", "show me the file", "navigate to line", "jump to line", "view the code", "edit file", "go to line", "open at line", "use nvr", "open in neovim", "open in my editor", or requests opening any file in their editor. Automatically discovers the correct neovim instance based on working directory and opens files at specific lines.
version: 1.0.0
allowed-tools: Bash
user-invocable: false
argument-hint: <file> [line]
---

# Open Files in Neovim Remote

## Purpose

Open files at specific lines in the correct neovim instance for the current project. This skill automatically discovers which neovim socket corresponds to the current working directory and opens the requested file.

## When to Use This Skill

Use this skill whenever the user requests opening, viewing, or navigating to a file or specific line:

- "Open database.py at line 45"
- "Show me the TODO in config.yaml"
- "Navigate to the error on line 23 of server.js"
- "View the code at src/utils/helper.py"
- "Open that file we just talked about"

To handle file opening requests, parse the user's intent to extract the file path and line number (if provided), then invoke this skill.

## Current Workspace (Auto-Captured)

**Working Directory**: !```pwd```
**Discovered Socket**: !```$CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null || echo "None"```
**Socket Valid**: !```[[ -S "$($CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null)" ]] && echo "✓" || echo "✗"```
**Active Instances**: !```nvr --serverlist 2>/dev/null | wc -l``` neovim process(es)

## How to Use

### Basic Usage

When the user requests opening a file, invoke the implementation script:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh <file> [line]
```

**Arguments:**
- `<file>` - File path (absolute or relative to working directory)
- `[line]` - Optional line number (defaults to 1)

**Examples:**

Open file at specific line:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh database.py 45
```

Open file at beginning:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh config.yaml
```

Open with absolute path:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh /home/user/project/src/main.py 10
```

### Natural Language Interpretation

To extract file and line from user requests:

**User**: "Open database.py at the next TODO"
**Implementation steps**:
1. Search database.py for TODO comments
2. Identify line number (e.g., line 67)
3. Invoke: `bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh database.py 67`

**User**: "Show me where we defined the User class"
**Implementation steps**:
1. Search codebase for "class User"
2. Find file and line (e.g., models.py:23)
3. Invoke: `bash $CLAUDE_PLUGIN_ROOT/skills/open/scripts/open.sh models.py 23`

### Success Response

When successful, the script outputs:
```
✓ Opened <file>:<line> in neovim (socket: <socket-path>)
```

Acknowledge to the user:
```
I've opened database.py at line 45 in your neovim editor.
```

### Error Handling

#### No neovim instance found

**Output:**
```
Error: No neovim instance found for directory: /home/user/project-A

Available instances:
  - /home/user/project-B (socket: /run/user/1000/nvim.456.0)
```

Inform the user that no neovim instance was found for this project, show available instances, and suggest:
1. Starting neovim in the current project directory
2. Using one of the available instances if appropriate
3. Showing the file location as fallback

**Example:**
```
I couldn't find a neovim instance for this project. You have neovim running in project-B.

Would you like me to:
1. Show you the file location (database.py:45)
2. Wait while you start neovim in this project
```

#### nvr not installed

**Output:**
```
Error: nvr (neovim-remote) not found. Install: pip install neovim-remote
```

Inform the user they need to install neovim-remote and provide installation command.

#### File doesn't exist

Handle file-not-found errors gracefully. If the file doesn't exist, inform the user and offer to:
1. Search for similar filenames
2. List files in the expected directory
3. Create the file if appropriate

## Implementation Details

### Socket Discovery Process

The skill uses `nvr-discover` utility for automatic socket discovery:

1. Check `$NVIM_SOCKET` environment variable (override)
2. Query all active sockets: `nvr --serverlist`
3. For each socket, get working directory: `nvr --remote-expr 'getcwd()'`
4. Match socket where working directory matches current directory or is a parent
5. Use the matched socket for opening the file

### File Opening Command

Once socket is discovered, open file with:
```bash
nvr --servername <socket> --remote +<line> <file>
```

This opens the file in neovim and positions cursor at the specified line.

## Interpreting User Intent

### Intent Patterns

- **"Open X"** - Open file at line 1
- **"Open X at line Y"** - Open file at specific line
- **"Show me the TODO in X"** - Search file for TODO, then open at that line
- **"Navigate to the error on line Y"** - Open current file at line Y
- **"View that file"** - Open most recently mentioned file

### Finding Files

If user doesn't provide full path:
1. Check if file exists in current directory
2. Search subdirectories if needed
3. Ask user to clarify if multiple matches

### Finding Line Numbers

When user mentions "the TODO" or "the error" without line number:
1. Use Grep tool to search the file
2. Identify the relevant line number
3. Open at that line

### Multiple Projects

If the user has multiple neovim instances running:
- Socket discovery automatically selects the instance matching the current working directory
- No manual socket selection needed
- Each Claude session works with its respective neovim instance

## Manual Invocation

Users can manually invoke this skill:

```bash
/nvr:open database.py 45
```

When invoked manually:
1. Validate the file path
2. Execute the skill
3. Report the result

## Environment Override

Users can force a specific socket using environment variable:

```bash
export NVIM_SOCKET=/run/user/1000/nvim.custom.0
```

When set, the skill uses this socket instead of auto-discovery.

## Related Skills

- **nvr:status** - Check which neovim instance is active
- **nvr:list** - List all running neovim instances
- **nvr:workspace** - Show current workspace context

Suggest these skills when troubleshooting or when user asks about their editor setup.

## Common Patterns

### Pattern 1: User mentions file without path

**User**: "Open main.py at line 50"
**Action**: Search for main.py in current directory and subdirectories, then open

### Pattern 2: User references previous conversation

**User**: "Open that config file we discussed"
**Action**: Review conversation for mentioned config file, then open

### Pattern 3: User wants to see error location

**User**: "Show me line 123 in server.js"
**Action**: Open server.js at line 123

### Pattern 4: User searches then wants to open

**User**: "Find all TODOs in utils/"
[Shows grep results]
**User**: "Open the first one"
**Action**: Open the file at the first TODO line

## Summary

Use this skill to seamlessly open files in the user's neovim editor based on their working directory. The skill handles socket discovery automatically, so focus on understanding user intent and determining the correct file and line number to open.
