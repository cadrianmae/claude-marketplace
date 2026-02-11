#!/bin/bash
# Phase 1: Bump versions (PATCH) and update plugin.json files

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Phase 1: Bumping plugin versions...${NC}\n"

for plugin_dir in plugins/*/; do
    plugin_name=$(basename "$plugin_dir")
    plugin_json="$plugin_dir.claude-plugin/plugin.json"

    # Get current version
    current_version=$(jq -r '.version // "1.0.0"' "$plugin_json")

    # Calculate next version (PATCH bump)
    IFS='.' read -r major minor patch <<< "$current_version"
    next_version="$major.$minor.$((patch + 1))"

    # Update plugin.json with new version
    jq --arg version "$next_version" '.version = $version' "$plugin_json" > "${plugin_json}.tmp"
    mv "${plugin_json}.tmp" "$plugin_json"

    echo -e "${GREEN}✓${NC} $plugin_name: v$current_version → v$next_version"
done

echo -e "\n${GREEN}All plugin versions bumped successfully!${NC}"
echo -e "${BLUE}Run ./scripts/update-readme-badges.sh to add badges to README files${NC}"
