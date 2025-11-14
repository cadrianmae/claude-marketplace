# code-pointer Plugin

Enables Claude to open files at specific lines in VSCode when explaining code, debugging, or guiding users to exact locations.

## Overview

This is a **Claude-only skill** that automatically activates when Claude needs to show you exactly where to look in a file. No slash commands—Claude invokes it automatically using the VSCode CLI.

**Auto-invoked when:**
- Explaining code at specific lines
- Debugging errors at particular locations
- Pointing to TODO sections or task markers
- Guiding through code reviews
- Referencing specific sections in config files or documentation
- Teaching with hands-on code examples

## Installation

```bash
# From within Claude Code
/mcp install code-pointer@cadrianmae-claude-marketplace
```

## How It Works

When Claude needs to show you a specific location in a file, it automatically runs:

```bash
code -g path/to/file.js:42
```

This opens VSCode with the cursor positioned exactly at line 42. Column positions are also supported:

```bash
code -g path/to/file.js:42:10  # Line 42, column 10
```

## Use Cases

### Explaining Code

**User:** "How does the MQTT publisher work?"

**Claude:** "The publisher connects to the broker at line 36. Let me open that for you:"
```bash
code -g PiPico/publisher.py:36
```

### Debugging

**User:** "I'm getting an error in main.py at line 100"

**Claude:** "Let's look at that line:"
```bash
code -g main.py:100
```

### TODO Navigation

**User:** "Show me the next TODO I need to implement"

**Claude:** "The next TODO is in the publisher at line 65:"
```bash
code -g PiPico/publisher.py:65
```

### Code Reviews

**User:** "Review my authentication logic"

**Claude:** "I notice a potential security issue at line 42. Opening it now:"
```bash
code -g src/auth.js:42
```

## Requirements

**VSCode CLI (`code` command) must be installed:**

1. Open VSCode
2. Open Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
3. Run: "Shell Command: Install 'code' command in PATH"

## Technical Details

### Line and Column Numbering

- **Lines**: 1-indexed (line 1 is the first line)
- **Columns**: 0-indexed (column 0 is the first character)

### Path Handling

- Relative paths work from current working directory
- Absolute paths are more reliable
- Paths with spaces must be quoted

### Window Behavior

By default, files open in the existing VSCode window. The skill handles this automatically based on context.

## Skill Structure

This plugin provides a skill that Claude loads when needed:

```
skills/code-pointer/
├── SKILL.md              # Core usage patterns for Claude
└── references/
    └── vscode_cli.md     # Complete technical documentation
```

The skill uses **progressive disclosure**:
1. **Metadata** - Always in context (when to use the skill)
2. **SKILL.md** - Loaded when skill activates (essential patterns)
3. **references/** - Loaded by Claude when needed (detailed docs)

## Benefits

- **Reduces friction**: No manual file navigation
- **Precise guidance**: Exact line and column positioning
- **Context-aware**: Claude uses it automatically when relevant
- **Time-saving**: Jump directly to relevant code sections
- **Teaching-friendly**: Perfect for Learning mode and hands-on tutorials

## Examples from Real Usage

**Learning Mode (from original use case):**
```
User: "Open first step in code using code with line number"
Claude: *Opens file at exact TODO(human) location*
code -g /path/to/publisher.py:36
```

**Code Explanation:**
```
User: "Explain how the error handling works"
Claude: "The try-catch block starts at line 88. Let me show you:"
code -g src/app.js:88
```

**Multiple Locations:**
```
Claude: "There are TODO sections in both files. Opening them now:"
code -g publisher.py:36 -g subscriber.py:45
```

## Author

Created by Mae Capacite for the cadrianmae-claude-marketplace.

## License

MIT License - see LICENSE file for details.
