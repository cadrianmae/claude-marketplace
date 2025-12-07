---
description: "Log a bug report for the marketplace"
allowed-tools: Bash, Read, Write, Edit
---

# /feedback:bug - Log a Marketplace Bug

Log a bug for cadrianmae-claude-marketplace plugins to FEEDBACK.md.

## Usage

```
/feedback:bug <description>
```

## Arguments

- `description` - Brief description of the bug (required)

## Behavior

1. **Check for FEEDBACK.md** - Create in marketplace root if doesn't exist
2. **Get current date** - Use `date '+%Y-%m-%d'`
3. **Append bug entry** - Add to Bugs section

## FEEDBACK.md Location

`~/.claude/marketplaces/cadrianmae-claude-marketplace/FEEDBACK.md`

## FEEDBACK.md Format

```markdown
# Marketplace Feedback

Bugs and feature requests for cadrianmae-claude-marketplace plugins.

## Bugs

- [ ] [2025-12-07] pandoc: Template validation fails on empty frontmatter
- [ ] [2025-12-06] semantic-search: Index command hangs on large repos

## Features

- [ ] [2025-12-05] Add export to PDF for session notes
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

# Find the Bugs section and append after it
sed -i "/^## Bugs$/a - [ ] [$DATE] $DESCRIPTION" "$FEEDBACK_FILE"
```

## Output

```
[OK] Bug logged to marketplace FEEDBACK.md

  - [ ] [2025-12-07] pandoc: restyle command fails on thesis template

View feedback: cat ~/.claude/marketplaces/cadrianmae-claude-marketplace/FEEDBACK.md
```

## Examples

```
/feedback:bug "pandoc: LaTeX comments break compilation"
/feedback:bug "semantic-search: Query inference misses Go code"
/feedback:bug "datetime: Parsing 'next month' returns wrong date"
```
