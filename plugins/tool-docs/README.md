# Tool Documentation Agents

Expert documentation agents for command-line tools and frameworks.

## Overview

This plugin provides specialized documentation agents that automatically trigger when you ask questions about command-line tools. Agents fetch official documentation, provide working examples, and troubleshoot common issues.

## Available Agents

### pandoc-guide

Expert pandoc documentation agent for document conversion, filters, and templates.

**Triggers automatically when:**
- You ask about pandoc conversions ("How do I convert markdown to PDF?")
- You're troubleshooting pandoc commands
- You mention pandoc filters, templates, or bibliography workflows
- You're working with academic papers and citations

**Capabilities:**
- Fetches official pandoc documentation via WebFetch
- Provides working command examples with detailed explanations
- Troubleshoots conversion issues with root cause analysis
- Explains filters, templates, and advanced features
- Suggests installation commands for missing dependencies

**Example usage:**
```
user: "How do I convert markdown to PDF with pandoc?"
→ Agent provides working command with explanation

user: "This pandoc command isn't working: pandoc input.md -o output.pdf"
→ Agent diagnoses issue and provides fix

user: "I need to convert my markdown paper with BibTeX citations to PDF"
→ Agent explains bibliography workflow with examples
```

## Skills

### /tool-lookup

Quick reference for common tool commands (offline access).

**Usage:**
```
/tool-lookup pandoc
```

**Provides:**
- Common conversions (MD→PDF, DOCX→MD, etc.)
- Academic writing commands (bibliography, templates)
- Filter usage examples
- Troubleshooting tips
- Resource links

## Installation

This plugin is part of the cadrianmae-claude-marketplace.

**To enable:**
```json
// In ~/.claude/settings.json
"enabledPlugins": {
  "tool-docs@cadrianmae-claude-marketplace": true
}
```

## Future Agents

Planned documentation agents for future releases:
- `postgres-guide` - PostgreSQL queries, administration, performance
- `git-guide` - Git workflows, branching, troubleshooting
- `docker-guide` - Container management, Compose, networking

## Contributing

To add new documentation agents:

1. Create `agents/tool-name-guide.md` with proper frontmatter
2. Include 3-4 triggering examples with commentary
3. Write comprehensive system prompt following pandoc-guide pattern
4. Add quick reference to `skills/tool-lookup/references/tool-name-quick-ref.md`
5. Update this README

See `agents/pandoc-guide.md` for reference implementation.

## Version

**1.0.0** - Initial release with pandoc-guide agent

## License

MIT
