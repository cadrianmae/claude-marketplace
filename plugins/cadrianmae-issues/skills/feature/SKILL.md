---
name: Feature Request
description: This skill should be used when the user asks to "file a feature", "request a feature", "log a feature request", "suggest an improvement", or mentions a marketplace plugin enhancement that should be tracked. Files feature requests as GitHub issues on cadrianmae/claude-marketplace.
allowed-tools: Bash, AskUserQuestion
argument-hint: <feature description>
---

# File a Feature Request

File a feature request as a GitHub issue on `cadrianmae/claude-marketplace`. This is for logging only — do NOT attempt to implement the feature in this session.

## Quick Example

```bash
/cadrianmae-issues:feature tts plugin - add volume control per-voice
```

## Workflow

1. Ask 1-2 clarifying questions if the description is unclear:
   - What is the use case? When would this be used?
   - What should the behaviour look like?
2. Determine which marketplace plugin is affected — infer from conversation context, the description, or ask the user
3. Compose the issue title and body using the template below
4. Create the issue with `gh issue create`
5. Confirm the issue URL and return to the user's current work

## Labels

- Always apply `enhancement`
- If a specific plugin is affected, also apply `plugin:<name>` (e.g. `plugin:cron`, `plugin:tts`)

## Issue Creation

After gathering details, compose the issue and file it:

```bash
gh issue create \
    --repo cadrianmae/claude-marketplace \
    --title "<concise feature title>" \
    --body "<issue body>" \
    --label enhancement \
    --label "plugin:<name>"
```

### Issue Body Template

```markdown
## Description
<clarified description>

## Use Case
<from clarifying questions, or 'Not specified' if user skipped>

## Proposed Behaviour
<from clarifying questions, or 'Not specified' if user skipped>

---
Plugin: <plugin name or n/a>
Date: <YYYY-MM-DD>
```

## After Filing

Respond with the issue URL, e.g.:
"Feature request filed: https://github.com/cadrianmae/claude-marketplace/issues/43. Continuing with your current work."

Return focus to whatever the user was working on before this command.
