#!/bin/bash
# Phase 2: MINOR version bump for plugins with dynamic injection

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Phase 2: MINOR version bumps for dynamic injection...${NC}\n"

# Plugins that received dynamic injection (MINOR bump)
PLUGINS_TO_BUMP=(
    "datetime"
    "track"
    "semantic-search"
    "pandoc"
    "gencast"
)

for plugin_name in "${PLUGINS_TO_BUMP[@]}"; do
    plugin_json="plugins/$plugin_name/.claude-plugin/plugin.json"

    # Get current version
    current_version=$(jq -r '.version' "$plugin_json")

    # Calculate MINOR bump (x.Y.z → x.Y+1.0)
    IFS='.' read -r major minor patch <<< "$current_version"
    next_version="$major.$((minor + 1)).0"

    # Update version in plugin.json
    jq --arg version "$next_version" '.version = $version' "$plugin_json" > "${plugin_json}.tmp"
    mv "${plugin_json}.tmp" "$plugin_json"

    echo -e "${GREEN}✓${NC} $plugin_name: v$current_version → v$next_version (MINOR: dynamic injection)"
done

echo -e "\n${GREEN}Phase 2 version bumps complete!${NC}"
