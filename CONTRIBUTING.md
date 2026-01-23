# Contributing Guide

Guidelines for contributing to the Claude Code Marketplace.

## Overview

This marketplace contains plugins, agents, and skills for Claude Code. Contributions should follow these standards to ensure quality, consistency, and maintainability.

## Getting Started

### Prerequisites

- Claude Code installed and configured
- Git for version control
- Basic understanding of Claude Code plugin architecture
- Familiarity with YAML frontmatter and Markdown

### Project Structure

```
cadrianmae-claude-marketplace/
├── plugins/
│   ├── plugin-name/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   └── skill-name/
│   │   │       └── SKILL.md
│   │   ├── commands/         [Legacy, deprecated]
│   │   ├── agents/            [Optional]
│   │   └── README.md
│   └── ...
├── TESTING.md
├── CONTRIBUTING.md
└── README.md
```

## Contribution Workflow

### 1. Fork and Branch

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/claude-marketplace.git
cd claude-marketplace

# Create a feature branch
git checkout -b feature/plugin-name
# OR
git checkout -b fix/bug-description
```

### 2. Make Changes

Follow the guidelines below for your contribution type.

### 3. Test Thoroughly

**Required**: All contributions must pass testing procedures documented in [TESTING.md](TESTING.md).

**Minimum Testing Requirements**:
- [ ] All skills/commands tested individually
- [ ] Dynamic context injection verified (if applicable)
- [ ] Non-git directory fallbacks tested
- [ ] Edge cases tested (empty repos, missing files, etc.)
- [ ] Backward compatibility confirmed (for updates)
- [ ] Documentation updated

See [TESTING.md](TESTING.md) for detailed testing procedures.

### 4. Document Changes

- Update plugin README.md
- Update CHANGELOG.md (if exists)
- Add inline comments for complex logic
- Update version number following [Semantic Versioning](#version-management)

### 5. Commit and Push

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "Add feature: skill for X

- Implements Y functionality
- Adds Z capability
- Updates documentation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to your fork
git push origin feature/plugin-name
```

### 6. Create Pull Request

- Open PR against `main` branch
- Fill out PR template with:
  - Description of changes
  - Testing completed
  - Breaking changes (if any)
  - Related issues

## Plugin Development Guidelines

### Creating a New Plugin

#### 1. Plugin Structure

**Minimum Required Files**:
```
plugins/your-plugin/
├── .claude-plugin/
│   └── plugin.json       [REQUIRED]
├── skills/
│   └── skill-name/
│       └── SKILL.md      [REQUIRED for each skill]
└── README.md             [REQUIRED]
```

**Optional Files**:
```
plugins/your-plugin/
├── agents/
│   └── agent-name.md
├── commands/             [Legacy, use skills/ instead]
├── LICENSE
├── CHANGELOG.md
└── examples/
```

#### 2. plugin.json Format

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description of what this plugin does",
  "author": {
    "name": "Your Name",
    "email": "your.email@example.com"
  },
  "homepage": "https://github.com/username/repo",
  "repository": "https://github.com/username/repo",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2", "keyword3"]
}
```

**Fields**:
- `name`: Short identifier (kebab-case)
- `version`: [Semantic version](#version-management)
- `description`: Clear, concise description (1-2 sentences)
- `author`: Your contact information
- `homepage`: Plugin documentation or project page
- `repository`: Source code repository
- `license`: Open source license (MIT recommended)
- `keywords`: Searchable tags

#### 3. SKILL.md Format

**Frontmatter (YAML)**:
```yaml
---
name: skill-name
description: Clear description of what this skill does and when to use it
argument-hint: <required-arg> [optional-arg]
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
disable-model-invocation: true    # Optional: user-only skill
model: haiku                       # Optional: specify model
---
```

**Content Structure**:
```markdown
# Brief introduction

## What it does

Clear step-by-step description of skill behavior.

## Usage

```
/skill-name <arg1> [arg2]
```

## Examples

Multiple examples showing different use cases.

## When to use

Guidance on when this skill is appropriate.

## Related skills

Links to related skills or commands.
```

**Best Practices**:
- Keep SKILL.md under 500 lines (use supporting files for details)
- Use dynamic context injection: `` !`command` ``
- Provide graceful fallbacks: `|| echo "fallback message"`
- Include clear usage examples
- Document argument requirements
- Specify tool restrictions with `allowed-tools`

### Dynamic Context Injection

Use `` !`command` `` syntax for live data injection:

```yaml
---
name: example-skill
description: Example skill with dynamic context
---

## Current State

**Time**: !`date '+%Y-%m-%d %H:%M:%S'`
**Git Branch**: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Not in git repo"`
**Working Directory**: !`pwd`

---

Instructions for skill...
```

**Best Practices**:
- Always provide fallbacks: `|| echo "fallback"`
- Use `head`/`tail` to limit output
- Test token usage (<500 tokens per skill)
- Verify output in both git and non-git directories

### Invocation Control

**When to use `disable-model-invocation: true`**:

Use for skills that:
- Have side effects (write files, run commands, deploy)
- Require user confirmation (delete, commit, send)
- Are user workflows (help, configuration)

Examples:
```yaml
disable-model-invocation: true  # User must explicitly invoke
```

**When to allow auto-invocation**:

Allow for skills that:
- Are read-only (list, show, search)
- Provide information (status, help)
- Assist Claude in answering questions

Examples:
```yaml
# No disable-model-invocation field
```

### Tool Restrictions

Limit skills to specific tools for safety:

```yaml
allowed-tools: Read, Grep, Glob  # Read-only
```

**Tool Categories**:
- **Read-only**: `Read, Grep, Glob`
- **Write operations**: `Write, Edit`
- **Command execution**: `Bash`
- **User interaction**: `AskUserQuestion`

### Supporting Files

Organize complex skills with supporting files:

```
skills/skill-name/
├── SKILL.md              # Main skill file (<500 lines)
├── reference.md          # Detailed documentation
├── examples.md           # Extended examples
├── templates/            # File templates
│   └── template.md
└── scripts/              # Helper scripts
    └── helper.sh
```

Reference from SKILL.md:
```markdown
See [reference.md](reference.md) for detailed API documentation.
See [examples.md](examples.md) for more usage examples.
```

## Version Management

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes, incompatible API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Bump Guidelines

**PATCH (1.0.0 → 1.0.1)**:
- Bug fixes
- Documentation updates
- Performance improvements (no API changes)

**MINOR (1.0.0 → 1.1.0)**:
- New skills/commands
- New features (backward compatible)
- Deprecations (with backward compatibility)

**MAJOR (1.0.0 → 2.0.0)**:
- Removing skills/commands
- Breaking changes to existing skills
- Incompatible API changes

### Changelog

Document all changes in CHANGELOG.md:

```markdown
# Changelog

## [1.1.0] - 2026-01-23

### Added
- New skill: `/skill-name` for doing X
- Dynamic context injection for Y

### Changed
- Improved Z performance by 50%
- Updated documentation for clarity

### Fixed
- Bug where A didn't work in B scenario
- Fallback handling for non-git directories

### Deprecated
- `/old-command` - Use `/new-skill` instead

## [1.0.0] - 2026-01-15

### Added
- Initial release
- Skills: `/skill1`, `/skill2`
```

## Code Style

### YAML Frontmatter

```yaml
---
name: kebab-case-name
description: Sentence case description ending with period.
argument-hint: <required> [optional]
allowed-tools: Read, Write
disable-model-invocation: true
---
```

### Markdown Content

- Use ATX-style headers (`#` not underlines)
- Code blocks with language specifiers
- Bullet lists with `-` (not `*`)
- Consistent indentation (2 spaces)
- One blank line between sections

### Shell Commands

```bash
# Good: Graceful fallbacks
git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Not in git repo"

# Good: Output limiting
git log --oneline | head -5

# Bad: No fallback
git rev-parse --abbrev-ref HEAD

# Bad: Unlimited output
git log --oneline
```

## Documentation Standards

### README.md (Plugin Level)

Required sections:

```markdown
# Plugin Name

Brief description (1-2 sentences).

## Installation

```bash
# Installation instructions
```

## Skills

### `/skill-name`

Description and basic usage.

## Usage Examples

Common workflows and examples.

## Configuration

Optional configuration options.

## Troubleshooting

Common issues and solutions.

## License

MIT License
```

### Inline Documentation

- Document WHY, not WHAT
- Explain complex logic
- Note edge cases
- Reference related issues/PRs

## Testing Requirements

All contributions must include:

1. **Functional Testing**: All features work as intended
2. **Edge Case Testing**: Handle errors gracefully
3. **Backward Compatibility**: Existing users not impacted (for updates)
4. **Documentation Testing**: Examples work as documented
5. **Performance Testing**: No significant performance regression

See [TESTING.md](TESTING.md) for detailed procedures.

## Pull Request Process

### Before Submitting

- [ ] All tests pass (see TESTING.md)
- [ ] Documentation updated
- [ ] Version bumped appropriately
- [ ] Changelog updated (if exists)
- [ ] No merge conflicts with main
- [ ] Commits are clean and descriptive

### PR Template

```markdown
## Description

Brief description of changes.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing Completed

- [ ] All skills/commands tested individually
- [ ] Dynamic context injection verified
- [ ] Non-git directory fallbacks tested
- [ ] Edge cases tested
- [ ] Backward compatibility confirmed

See [testing notes below](#testing-notes).

## Testing Notes

Describe testing approach and results.

## Breaking Changes

List any breaking changes and migration guide.

## Related Issues

Fixes #123
Related to #456

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass
- [ ] No console errors/warnings
```

## Common Mistakes to Avoid

### ❌ Don't Do This

1. **Hardcoded paths**:
   ```bash
   cat ~/.claude/memory.md  # Bad: assumes home directory
   ```
   Use relative paths or dynamic paths.

2. **No fallbacks**:
   ```bash
   git rev-parse --abbrev-ref HEAD  # Bad: fails in non-git repos
   ```
   Always provide fallbacks.

3. **Unlimited output**:
   ```bash
   cat large-file.md  # Bad: could be huge
   ```
   Use `head`/`tail` limits.

4. **Generic names**:
   ```yaml
   name: helper  # Bad: too generic
   ```
   Use descriptive, specific names.

5. **Missing documentation**:
   ```yaml
   # Bad: no usage examples
   ```
   Always include examples.

### ✅ Do This Instead

1. **Dynamic paths**:
   ```bash
   cat .claude/memory.md  # Good: relative to project
   ```

2. **Graceful fallbacks**:
   ```bash
   git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Not in git repo"
   ```

3. **Limited output**:
   ```bash
   cat large-file.md | head -20
   ```

4. **Descriptive names**:
   ```yaml
   name: session-tracker
   ```

5. **Complete documentation**:
   ```markdown
   ## Examples

   Multiple examples showing different scenarios.
   ```

## Migration from Commands to Skills

### Converting Existing Commands

If migrating from `commands/*.md` to `skills/*/SKILL.md`:

1. **Create directory structure**:
   ```bash
   mkdir -p skills/skill-name
   ```

2. **Copy command file**:
   ```bash
   cp commands/command.md skills/skill-name/SKILL.md
   ```

3. **Update frontmatter**:
   ```yaml
   ---
   name: skill-name          # ADD
   description: ...
   argument-hint: ...
   allowed-tools: ...
   disable-model-invocation: true  # ADD if user-only
   ---
   ```

4. **Keep commands/ for compatibility**:
   - Don't delete `commands/` directory
   - Add deprecation notice to command files
   - Skills take precedence when both exist

5. **Test both paths**:
   - Verify skill works
   - Verify command still works as fallback
   - Update documentation

See session-management and context-handoff plugins (v1.3.0) for reference implementation.

## Getting Help

- **Issues**: Open an issue for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Pull Requests**: Submit PRs for contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Last Updated**: 2026-01-23
**Version**: 1.0
