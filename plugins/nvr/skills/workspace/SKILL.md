---
name: nvr-workspace
description: This skill should be used when the user asks to "show workspace", "what's my environment", "workspace context", "where am I working", "show current project context", or wants to understand their current development environment including directory, git info, and neovim instance.
version: 1.0.0
allowed-tools: Bash
user-invocable: false
---

# Discover Current Workspace Context

## Purpose

Display comprehensive workspace context including working directory, git repository information, and active neovim instance. Provides a complete picture of the current development environment.

## When to Use This Skill

Use this skill when the user wants to understand their full workspace context:

- "Show me my workspace"
- "What's my current environment?"
- "Where am I working?"
- "Show current project context"
- "What's my setup?"

## Workspace Discovery (Auto-Captured)

**Current Directory**: !```pwd```
**Git Repository**: !```git rev-parse --show-toplevel 2>/dev/null || echo "Not in git repo"```
**Neovim Socket**: !```$CLAUDE_PLUGIN_ROOT/scripts/nvr-discover 2>/dev/null || echo "No active instance"```

## How to Use

Invoke the workspace script:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/workspace/scripts/workspace.sh
```

No arguments needed - the script automatically gathers all workspace information.

### Success Output

Complete workspace context:
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

Present this information to help the user understand their current environment.

### Partial Information

The script shows available information even if some components are missing:

**No git repository:**
```
Workspace Context
=================

Working Directory: /home/user/documents
Git Repository: Not in git repo

Neovim Instance: No active instance for this directory
```

**No neovim instance:**
```
Workspace Context
=================

Working Directory: /home/user/project-A
Git Repository: /home/user/project-A
Git Branch: feature-branch

Neovim Instance: No active instance for this directory
```

## Use Cases

### Use Case 1: Session Initialization

**User**: "Show me where I'm working"
**Action**: Run workspace script
**Response**: Display complete environment context to orient the user

### Use Case 2: Debugging Environment Issues

**User**: "Why isn't this working?"
**Action**: Run workspace script to verify environment setup
**Response**: Check if directory, git branch, and neovim instance are correct

### Use Case 3: Confirming Project Context

**User**: "Am I in the right project?"
**Action**: Run workspace script
**Response**: Show project directory and git info for confirmation

### Use Case 4: Multi-Project Workflow

**User**: "Which project am I in now?"
**Action**: Run workspace script
**Response**: Display current project context including git branch

## Implementation Details

The workspace script gathers:

**Directory Information:**
- Current working directory: `pwd`

**Git Information:**
- Repository root: `git rev-parse --show-toplevel`
- Current branch: `git branch --show-current`

**Neovim Instance:**
- Socket discovery via `nvr-discover`
- If found, queries:
  - Working directory: `nvr --remote-expr 'getcwd()'`
  - Process ID: `nvr --remote-expr 'getpid()'`

## Interpreting Results

### Complete Environment

When all components are present:
- Working directory matches git repository
- Git branch is known
- Neovim instance matches directory

This indicates a well-configured development environment.

### Missing Components

**No git repository:**
- Working in non-git directory
- May be intentional (documents, scripts, etc.)
- Not an error unless git expected

**No neovim instance:**
- No editor running for this project
- Suggest starting neovim if file operations planned
- Not an error for read-only tasks

### Directory Mismatches

If neovim working directory differs from current directory:
```
Working Directory: /home/user/project-A/src
Neovim Instance: Active
  Working Directory: /home/user/project-A
```

This is normal when working in a subdirectory - socket discovery finds the parent project's neovim instance.

## Manual Invocation

Users can manually invoke this skill:

```bash
/nvr:workspace
```

Show the full workspace context directly.

## Related Skills

- **nvr:status** - Show only neovim instance information
- **nvr:list** - Show all neovim instances across projects
- **nvr:open** - Open files once environment confirmed

## Using Workspace Info

After displaying workspace context:
- Use directory info for file operations
- Reference git branch when discussing commits
- Note neovim status before file opening operations
- Suggest starting neovim if needed for editing

### Combining with Other Commands

After showing workspace:
- If user wants only neovim info, suggest `/nvr:status`
- If user wants to see all projects, suggest `/nvr:list`
- If user wants to open files, proceed with `/nvr:open`

## Error Handling

### Git Not Available

If git is not installed, show:
```
Git Repository: git command not available
```

Not an error - user may not need git.

### Directory Access Issues

If directory cannot be read:
```
Working Directory: Access denied
```

Inform user of permission issue.

### nvr Not Available

If nvr is not installed:
```
Neovim Instance: nvr not installed
```

Suggest installing if neovim integration needed.

## Summary

Use this skill to provide comprehensive workspace context. It's particularly useful at session start, when debugging environment issues, or when the user needs to verify their project setup before beginning work.
