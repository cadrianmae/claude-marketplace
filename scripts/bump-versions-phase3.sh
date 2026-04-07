#!/bin/bash
# Phase 3: PATCH version bump for documentation enhancements

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Phase 3: PATCH version bumps for documentation...${NC}\n"

# All plugins get PATCH bump for docs improvements
for plugin_dir in plugins/*/; do
    plugin_name=$(basename "$plugin_dir")
    plugin_json="$plugin_dir/.claude-plugin/plugin.json"

    # Get current version
    current_version=$(jq -r '.version' "$plugin_json")

    # Calculate PATCH bump (x.y.Z → x.y.Z+1)
    IFS='.' read -r major minor patch <<< "$current_version"
    next_version="$major.$minor.$((patch + 1))"

    # Update version in plugin.json
    jq --arg version "$next_version" '.version = $version' "$plugin_json" > "${plugin_json}.tmp"
    mv "${plugin_json}.tmp" "$plugin_json"

    echo -e "${GREEN}✓${NC} $plugin_name: v$current_version → v$next_version (PATCH: docs)"
done

echo -e "\n${GREEN}Phase 3 version bumps complete!${NC}"
