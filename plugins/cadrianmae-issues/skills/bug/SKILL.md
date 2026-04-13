---
name: Bug Report
description: This skill should be used when the user asks to "file a bug", "report a bug", "log a bug", "create a bug issue", or mentions a marketplace plugin bug that should be tracked. Files bug reports as GitHub issues on cadrianmae/claude-marketplace.
allowed-tools: Bash, AskUserQuestion
argument-hint: <bug description>
---

# File a Bug Report

File a bug report as a GitHub issue on `cadrianmae/claude-marketplace`. This is for logging only — do NOT attempt to fix the bug in this session.

## Quick Example

```bash
/cadrianmae-issues:bug cron plugin - schedule matching fails for weekly expressions
```

## Workflow

1. Ask 1-2 clarifying questions if the description is unclear:
   - What were the steps to reproduce?
   - What was expected vs what actually happened?
2. Determine which marketplace plugin is affected — infer from conversation context, the description, or ask the user
3. Compose the issue title and body using the template below
4. Create the issue with `gh issue create`
5. Confirm the issue URL and return to the user's current work

## Labels

- Always apply `bug`
- If a specific plugin is affected, also apply `plugin:<name>` (e.g. `plugin:cron`, `plugin:tts`)

## Issue Creation

After gathering details, compose the issue and file it:

```bash
gh issue create \
    --repo cadrianmae/claude-marketplace \
    --title "<concise bug title>" \
    --body "<issue body>" \
    --label bug \
    --label "plugin:<name>"
```

### Issue Body Template

```markdown
## Description
<clarified description>

## Steps to Reproduce
<from clarifying questions, or 'Not specified' if user skipped>

## Expected Behaviour
<from clarifying questions, or 'Not specified' if user skipped>

---
Plugin: <plugin name or n/a>
Date: <YYYY-MM-DD>
```

## After Filing

Respond with the issue URL, e.g.:
"Bug filed: https://github.com/cadrianmae/claude-marketplace/issues/42. Continuing with your current work."

Return focus to whatever the user was working on before this command.
