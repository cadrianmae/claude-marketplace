#!/bin/bash
# Add version and license badges to README.md files

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Adding badges to README.md files...${NC}\n"

for plugin_dir in plugins/*/; do
    plugin_name=$(basename "$plugin_dir")
    readme="$plugin_dir/README.md"
    plugin_json="$plugin_dir.claude-plugin/plugin.json"

    if [ ! -f "$readme" ]; then
        echo -e "${YELLOW}⚠${NC} $plugin_name - No README.md found, skipping"
        continue
    fi

    # Get version and license
    version=$(jq -r '.version' "$plugin_json")
    license=$(jq -r '.license // "MIT"' "$plugin_json")

    # Check if badges already exist
    if grep -q "img.shields.io/badge/version" "$readme"; then
        echo -e "${GREEN}✓${NC} $plugin_name - Badges already present"
        continue
    fi

    # Read current README content
    readme_content=$(cat "$readme")

    # Create badges
    badges="[![Version](https://img.shields.io/badge/version-${version}-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

"

    # Prepend badges to README
    echo -e "${badges}${readme_content}" > "$readme"

    echo -e "${GREEN}✓${NC} $plugin_name - Badges added (v$version, $license)"
done

echo -e "\n${GREEN}All README badges updated successfully!${NC}"
