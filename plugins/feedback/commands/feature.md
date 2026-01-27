---
description: "Log a feature request for the marketplace (logging only - implementation happens in dedicated sessions)"
allowed-tools: Bash
---

# /feedback:feature - Log a Marketplace Feature Request

## Quick Example

```bash
/feedback:feature Add --dry-run flag to all context commands to preview changes
# Logs the feature request to FEEDBACK.md for later review
```

IMPORTANT: This command logs feature requests for LATER review and implementation in a dedicated marketplace development session. Do NOT attempt to implement features in this session. You may ask clarifying questions to better understand the request, then log it and continue with the user's current work.

## Workflow

1. If the description is unclear, ask clarifying questions
2. Log the feature to FEEDBACK.md with the script below
3. Confirm it's logged and return to the user's work - DO NOT implement

## Script to Execute

```bash
MARKETPLACE_DIR=~/.claude/marketplaces/cadrianmae-claude-marketplace
FEEDBACK_FILE="$MARKETPLACE_DIR/FEEDBACK.md"
DATE=$(date '+%Y-%m-%d')
DESCRIPTION="$1"

# Create file if doesn't exist
if [[ ! -f "$FEEDBACK_FILE" ]]; then
    cat > "$FEEDBACK_FILE" << 'EOF'
# Marketplace Feedback

Bugs and feature requests for cadrianmae-claude-marketplace plugins.

## Bugs

## Features

EOF
fi

# Find the Features section and append after it
sed -i "/^## Features$/a - [ ] [$DATE] $DESCRIPTION" "$FEEDBACK_FILE"
```

## After Logging

Respond with: "Feature request logged to marketplace FEEDBACK.md for later review. Continuing with your current work."

Then return focus to whatever the user was working on before this command.
