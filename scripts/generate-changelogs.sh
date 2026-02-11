#!/bin/bash
# Generate CHANGELOG.md for all plugins from git history

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Generating CHANGELOGs for all plugins...${NC}\n"

for plugin_dir in plugins/*/; do
    plugin_name=$(basename "$plugin_dir")

    # Skip if CHANGELOG already exists (like feedback we just created)
    if [ -f "$plugin_dir/CHANGELOG.md" ]; then
        echo -e "${GREEN}✓${NC} $plugin_name - CHANGELOG.md already exists"
        continue
    fi

    # Get current version from plugin.json
    current_version=$(jq -r '.version // "1.0.0"' "$plugin_dir.claude-plugin/plugin.json")

    # Calculate next version (PATCH bump)
    IFS='.' read -r major minor patch <<< "$current_version"
    next_version="$major.$minor.$((patch + 1))"

    # Get git history for this plugin
    git_log=$(git log --format="%h|%ai|%s" --follow -- "$plugin_dir" 2>/dev/null || echo "")

    if [ -z "$git_log" ]; then
        echo "⚠ $plugin_name - No git history found, creating minimal CHANGELOG"
        next_version="$current_version"
    fi

    # Create CHANGELOG.md
    cat > "$plugin_dir/CHANGELOG.md" << EOF
# Changelog

All notable changes to the $plugin_name plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [$next_version] - $(date +%Y-%m-%d)
### Added
- CHANGELOG.md following Keep a Changelog format
$([ -f "$plugin_dir/LICENSE" ] || echo "- LICENSE file (MIT)")
$(jq -e '.repository' "$plugin_dir.claude-plugin/plugin.json" &>/dev/null || echo "- Repository field in plugin.json")

### Changed
- Updated README.md with version badge and license information

EOF

    # Parse git history and add to CHANGELOG
    if [ -n "$git_log" ]; then
        # Process git log in reverse chronological order
        while IFS='|' read -r commit_hash commit_date commit_msg; do
            commit_year=$(echo "$commit_date" | cut -d'-' -f1)
            commit_date_short=$(echo "$commit_date" | cut -d' ' -f1)

            # Extract version from commit message if present
            version_in_msg=$(echo "$commit_msg" | grep -oP 'v?\d+\.\d+\.\d+' | head -1 | sed 's/^v//')

            if [ -n "$version_in_msg" ]; then
                echo "## [$version_in_msg] - $commit_date_short" >> "$plugin_dir/CHANGELOG.md"
            fi

            # Categorize commit
            if echo "$commit_msg" | grep -iqE '^(add|added|new|create|initial)'; then
                echo "### Added" >> "$plugin_dir/CHANGELOG.md"
                echo "- $commit_msg" >> "$plugin_dir/CHANGELOG.md"
                echo "" >> "$plugin_dir/CHANGELOG.md"
            elif echo "$commit_msg" | grep -iqE '^(fix|fixed|resolve|repair)'; then
                echo "### Fixed" >> "$plugin_dir/CHANGELOG.md"
                echo "- $commit_msg" >> "$plugin_dir/CHANGELOG.md"
                echo "" >> "$plugin_dir/CHANGELOG.md"
            elif echo "$commit_msg" | grep -iqE '^(change|changed|update|updated|improve|refactor)'; then
                echo "### Changed" >> "$plugin_dir/CHANGELOG.md"
                echo "- $commit_msg" >> "$plugin_dir/CHANGELOG.md"
                echo "" >> "$plugin_dir/CHANGELOG.md"
            else
                echo "### Changed" >> "$plugin_dir/CHANGELOG.md"
                echo "- $commit_msg" >> "$plugin_dir/CHANGELOG.md"
                echo "" >> "$plugin_dir/CHANGELOG.md"
            fi
        done <<< "$git_log"
    fi

    # Add version comparison links at bottom
    cat >> "$plugin_dir/CHANGELOG.md" << EOF

[Unreleased]: https://github.com/cadrianmae/claude-marketplace/compare/${plugin_name}-v${next_version}...HEAD
[${next_version}]: https://github.com/cadrianmae/claude-marketplace/releases/tag/${plugin_name}-v${next_version}
EOF

    echo -e "${GREEN}✓${NC} $plugin_name - CHANGELOG.md generated (v$current_version → v$next_version)"
done

echo -e "\n${GREEN}All CHANGELOGs generated successfully!${NC}"
