---
description: "Log a feature request for the marketplace"
allowed-tools: Bash, Read, Write, Edit
---

# /feedback:feature - Log a Marketplace Feature Request

Log a feature request for cadrianmae-claude-marketplace plugins to FEEDBACK.md.

## Usage

```
/feedback:feature <description>
```

## Arguments

- `description` - Brief description of the feature (required)

## Behavior

1. **Check for FEEDBACK.md** - Create in marketplace root if doesn't exist
2. **Get current date** - Use `date '+%Y-%m-%d'`
3. **Append feature entry** - Add to Features section

## FEEDBACK.md Location

`~/.claude/marketplaces/cadrianmae-claude-marketplace/FEEDBACK.md`

## FEEDBACK.md Format

```markdown
# Marketplace Feedback

Bugs and feature requests for cadrianmae-claude-marketplace plugins.

## Bugs

- [ ] [2025-12-07] Bug description here

## Features

- [ ] [2025-12-07] pandoc: Add beamer presentation template
- [ ] [2025-12-06] semantic-search: Support multiple index profiles
```

## Implementation

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

## Output

```
[OK] Feature logged to marketplace FEEDBACK.md

  - [ ] [2025-12-07] Add obsidian-style callout blocks to pandoc

View feedback: cat ~/.claude/marketplaces/cadrianmae-claude-marketplace/FEEDBACK.md
```

## Examples

```
/feedback:feature "pandoc: Add IEEE citation style template"
/feedback:feature "semantic-search: Add file type filtering"
/feedback:feature "session-management: Export session to markdown"
```
