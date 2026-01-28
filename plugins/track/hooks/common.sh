#!/bin/bash
# Common utilities for track plugin hooks

# Check if tracking is enabled for current project
is_tracking_enabled() {
    [ -f .claude/.ref-autotrack ]
}

# Read configuration value from .claude/.ref-config
get_config_value() {
    local key="$1"
    local default="$2"

    if [ -f .claude/.ref-config ]; then
        grep "^${key}=" .claude/.ref-config 2>/dev/null | cut -d= -f2
    else
        echo "$default"
    fi
}

# Ensure claude_usage directory exists
ensure_claude_usage_dir() {
    mkdir -p claude_usage
}

# Get current timestamp in ISO 8601 format
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Truncate text to max length
truncate_text() {
    local text="$1"
    local max_length="${2:-200}"

    if [ "${#text}" -gt "$max_length" ]; then
        echo "${text:0:$max_length}..."
    else
        echo "$text"
    fi
}

# Ensure file exists with preamble
ensure_file_with_preamble() {
    local file_path="$1"
    local file_type="$2"

    if [ -f "$file_path" ]; then
        return 0
    fi

    ensure_claude_usage_dir

    case "$file_type" in
        sources)
            cat > "$file_path" << 'EOF'
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
            ;;
        prompts)
            cat > "$file_path" << 'EOF'
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
            ;;
    esac
}
