#!/bin/bash
# Initialize hooks-based tracking
# Part of Track Plugin v2.0 - called by /track:init skill

# Create claude_usage directory
mkdir -p claude_usage

# Create .claude directory
mkdir -p .claude
mkdir -p .claude/.track-tmp

# Create sources.md with preamble
if [ ! -f claude_usage/sources.md ]; then
    cat > claude_usage/sources.md << 'EOF'
# Research Sources

This file automatically tracks research sources discovered during development.

**Purpose:** Generate bibliographies, works cited, and maintain citation trail for academic work.

**Format:** Each line is a key-value entry:
```
[Attribution] Tool("Query"): Result
```

**Attribution:**
- `[User]` - Explicitly requested by user
- `[Claude]` - Autonomously discovered by Claude

**Tools tracked:** WebSearch, WebFetch, Read (documentation), Grep (documentation)

**Usage:**
- Export for academic papers: `/track:export bibliography`
- View recent sources: `tail claude_usage/sources.md`
- Search specific topic: `grep "topic" claude_usage/sources.md`

**Configuration:** `.claude/.ref-config` (SOURCES_VERBOSITY setting)

---

EOF
fi

# Create prompts.md with preamble
if [ ! -f claude_usage/prompts.md ]; then
    cat > claude_usage/prompts.md << 'EOF'
# Development Prompts and Outcomes

This file automatically tracks significant development work and decisions.

**Purpose:** Document methodology, implementation decisions, and project evolution for reports and retrospectives.

**Format:** Two-line entries with blank separator:
```
Prompt: "user request"
Outcome: what was accomplished
```

**Verbosity:** Controlled by PROMPTS_VERBOSITY setting
- `major` (default) - Significant multi-step work only
- `all` - Every user interaction
- `minimal` - Only when explicitly requested

**Usage:**
- Export for methodology section: `/track:export methodology`
- Review recent work: `tail claude_usage/prompts.md`
- Find specific feature: `grep "authentication" claude_usage/prompts.md`

**Configuration:** `.claude/.ref-config` (PROMPTS_VERBOSITY setting)

---

EOF
fi

# Create configuration file
if [ ! -f .claude/.ref-config ]; then
    cat > .claude/.ref-config << 'EOF'
PROMPTS_VERBOSITY=major
SOURCES_VERBOSITY=all
EXPORT_PATH=exports/
EOF
fi

# Create autotrack marker with metadata
cat > .claude/.ref-autotrack << EOF
# Track Plugin v2.0 - Automatic Tracking Enabled
#
# This marker file enables hooks-based automatic tracking for this project.
#
# Hooks configured:
# - PostToolUse: Tracks WebSearch, WebFetch, Read, Grep
# - UserPromptSubmit: Captures user prompts
# - SessionEnd: Pairs prompts with outcomes
#
# Verbosity settings: ./.claude/.ref-config
# Toggle tracking: /track:auto
# Disable tracking: rm .claude/.ref-autotrack
#
# Initialized: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# Detect old files and offer migration
if [ -f CLAUDE_SOURCES.md ] || [ -f CLAUDE_PROMPTS.md ]; then
    echo "Detected legacy tracking files!"
    echo ""
    echo "Migration available:"
    [ -f CLAUDE_SOURCES.md ] && echo "  - CLAUDE_SOURCES.md → claude_usage/sources.md"
    [ -f CLAUDE_PROMPTS.md ] && echo "  - CLAUDE_PROMPTS.md → claude_usage/prompts.md"
    echo ""
    echo "Run manually:"
    [ -f CLAUDE_SOURCES.md ] && echo "  cat CLAUDE_SOURCES.md >> claude_usage/sources.md"
    [ -f CLAUDE_PROMPTS.md ] && echo "  cat CLAUDE_PROMPTS.md >> claude_usage/prompts.md"
    echo ""
fi

# Show success summary
echo "✓ Track plugin v2.0 initialized"
echo ""
echo "Hooks-based tracking enabled:"
echo "  - PostToolUse: Automatic source tracking"
echo "  - UserPromptSubmit: Automatic prompt capture"
echo "  - SessionEnd: Automatic prompt-outcome pairing"
echo ""
echo "Configuration:"
echo "  - Prompts: major (significant work only)"
echo "  - Sources: all (every search)"
echo "  - Export: exports/ directory"
echo ""
echo "Next steps:"
echo "  - Work normally - hooks track automatically"
echo "  - Use /track:config to adjust verbosity"
echo "  - Use /track:export to generate outputs"
echo "  - Use /track:help for documentation"
