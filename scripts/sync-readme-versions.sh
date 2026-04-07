#!/bin/bash
# Sync README badge versions with plugin.json versions

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Syncing README badge versions...${NC}\n"

for plugin_dir in plugins/*/; do
    plugin_name=$(basename "$plugin_dir")
    readme="$plugin_dir/README.md"
    plugin_json="$plugin_dir/.claude-plugin/plugin.json"

    if [ ! -f "$readme" ]; then
        echo "⚠️  $plugin_name: No README.md found"
        continue
    fi

    # Get version from plugin.json
    version=$(jq -r '.version' "$plugin_json")

    # Update README badge
    if grep -q "version-[0-9.]*-blue" "$readme"; then
        sed -i "s/version-[0-9.]*-blue/version-$version-blue/" "$readme"
        echo -e "${GREEN}✓${NC} $plugin_name: Updated to v$version"
    else
        echo "⚠️  $plugin_name: No version badge found"
    fi
done

echo -e "\n${GREEN}README versions synchronized!${NC}"
