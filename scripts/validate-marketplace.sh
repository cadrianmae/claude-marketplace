#!/bin/bash
# Comprehensive marketplace validation script

set -e

MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MARKETPLACE_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PHASE="${1:-all}"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Marketplace Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

validate_phase1() {
    echo -e "${BLUE}Phase 1: Documentation Gaps${NC}"
    echo "─────────────────────────────"

    for plugin in plugins/*/; do
        name=$(basename "$plugin")

        # Check CHANGELOG.md
        if [ ! -f "$plugin/CHANGELOG.md" ]; then
            echo -e "${RED}✗${NC} $name: Missing CHANGELOG.md"
            ((ERRORS++))
        else
            echo -e "${GREEN}✓${NC} $name: CHANGELOG.md exists"
        fi

        # Check LICENSE
        if [ ! -f "$plugin/LICENSE" ]; then
            echo -e "${RED}✗${NC} $name: Missing LICENSE"
            ((ERRORS++))
        else
            echo -e "${GREEN}✓${NC} $name: LICENSE exists"
        fi

        # Check repository link in plugin.json
        repo=$(jq -r '.repository // empty' "$plugin/.claude-plugin/plugin.json" 2>/dev/null)
        if [ -z "$repo" ]; then
            echo -e "${RED}✗${NC} $name: Missing repository field in plugin.json"
            ((ERRORS++))
        else
            echo -e "${GREEN}✓${NC} $name: repository field exists"
        fi
    done
    echo ""
}

validate_phase2() {
    echo -e "${BLUE}Phase 2: Dynamic Injection${NC}"
    echo "─────────────────────────────"

    # Plugins that should have dynamic injection
    DYNAMIC_PLUGINS=("datetime" "track" "semantic-search" "pandoc" "gencast")

    for plugin in "${DYNAMIC_PLUGINS[@]}"; do
        has_injection=false

        # Check commands for dynamic injection markers
        if find "plugins/$plugin/commands" -name "*.md" -exec grep -l '!`' {} \; 2>/dev/null | head -1 | grep -q .; then
            has_injection=true
        fi

        if [ "$has_injection" = true ]; then
            echo -e "${GREEN}✓${NC} $plugin: Dynamic injection implemented"
        else
            echo -e "${YELLOW}⚠${NC} $plugin: No dynamic injection found"
            ((WARNINGS++))
        fi
    done
    echo ""
}

validate_phase3() {
    echo -e "${BLUE}Phase 3: Documentation Enhancement${NC}"
    echo "─────────────────────────────────────"

    # Check frontmatter completeness
    missing_frontmatter=0
    for file in plugins/*/commands/*.md plugins/*/skills/*/SKILL.md; do
        [ ! -f "$file" ] && continue

        if ! grep -q "^allowed-tools:" "$file" 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Missing allowed-tools: $(basename "$(dirname "$(dirname "$file")")")/$(basename "$file")"
            ((missing_frontmatter++))
            ((WARNINGS++))
        fi
    done

    if [ "$missing_frontmatter" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All command/skill files have allowed-tools frontmatter"
    else
        echo -e "${YELLOW}⚠${NC} $missing_frontmatter files missing allowed-tools"
    fi

    # Check for Quick Example sections
    missing_examples=0
    total_files=0
    for file in plugins/*/commands/*.md plugins/*/skills/*/SKILL.md; do
        [ ! -f "$file" ] && continue
        [[ "$file" == *"/upstream/"* ]] && continue  # Skip upstream files

        ((total_files++))
        if ! grep -q "^## Quick Example" "$file" 2>/dev/null; then
            ((missing_examples++))
        fi
    done

    examples_percentage=$((100 - (missing_examples * 100 / total_files)))
    if [ "$missing_examples" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All $total_files files have Quick Example sections (100%)"
    else
        echo -e "${YELLOW}⚠${NC} ${examples_percentage}% coverage ($missing_examples/$total_files missing)"
        ((WARNINGS++))
    fi

    # Check README License sections
    missing_license=0
    for plugin in plugins/*/; do
        readme="$plugin/README.md"
        if [ -f "$readme" ] && ! grep -q "^## License" "$readme"; then
            ((missing_license++))
        fi
    done

    if [ "$missing_license" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All READMEs have License sections"
    else
        echo -e "${YELLOW}⚠${NC} $missing_license READMEs missing License sections"
        ((WARNINGS++))
    fi

    echo ""
}

validate_phase4() {
    echo -e "${BLUE}Phase 4: Structure Standardization${NC}"
    echo "────────────────────────────────────"

    # Check plugin.json metadata completeness
    for plugin in plugins/*/; do
        name=$(basename "$plugin")
        plugin_json="$plugin/.claude-plugin/plugin.json"

        # Check required fields
        for field in name version description author license keywords; do
            value=$(jq -r ".$field // empty" "$plugin_json" 2>/dev/null)
            if [ -z "$value" ] || [ "$value" = "null" ]; then
                echo -e "${RED}✗${NC} $name: Missing $field in plugin.json"
                ((ERRORS++))
            fi
        done
    done

    # Check skills structure for datetime and code-pointer
    for plugin in datetime code-pointer; do
        if [ -d "plugins/$plugin/skills/$plugin" ]; then
            echo -e "${GREEN}✓${NC} $plugin: Skills structure exists"
        else
            echo -e "${RED}✗${NC} $plugin: Missing skills structure"
            ((ERRORS++))
        fi
    done
    echo ""
}

validate_phase5() {
    echo -e "${BLUE}Phase 5: Progressive Disclosure${NC}"
    echo "─────────────────────────────────"

    # Check for references/ directories in complex plugins
    for plugin in pandoc semantic-search; do
        if [ -d "plugins/$plugin/skills/$plugin/references" ]; then
            ref_count=$(find "plugins/$plugin/skills/$plugin/references" -name "*.md" | wc -l)
            echo -e "${GREEN}✓${NC} $plugin: Progressive disclosure ($ref_count reference files)"
        else
            echo -e "${YELLOW}⚠${NC} $plugin: No references directory"
            ((WARNINGS++))
        fi
    done
    echo ""
}

validate_success_metrics() {
    echo -e "${BLUE}Success Metrics${NC}"
    echo "───────────────"

    # Count plugins dynamically (any directory containing .claude-plugin/plugin.json)
    total_plugins=$(find plugins -maxdepth 3 -path '*/.claude-plugin/plugin.json' | wc -l)
    [[ $total_plugins -eq 0 ]] && total_plugins=1  # avoid div-by-zero

    # Count plugins with CHANGELOG
    changelog_count=$(find plugins -maxdepth 2 -name "CHANGELOG.md" | wc -l)
    echo "CHANGELOG.md: $changelog_count/$total_plugins ($(($changelog_count * 100 / $total_plugins))%)"

    # Count plugins with LICENSE
    license_count=$(find plugins -maxdepth 2 -name "LICENSE" | wc -l)
    echo "LICENSE: $license_count/$total_plugins ($(($license_count * 100 / $total_plugins))%)"

    # Count plugins with dynamic injection
    dynamic_count=0
    for plugin in datetime track semantic-search pandoc gencast; do
        if find "plugins/$plugin/commands" -name "*.md" -exec grep -l '!`' {} \; 2>/dev/null | head -1 | grep -q .; then
            ((dynamic_count++))
        fi
    done
    echo "Dynamic injection: $dynamic_count/5 ($(($dynamic_count * 100 / 5))%)"

    echo ""
}

# Run validation
case "$PHASE" in
    1) validate_phase1 ;;
    2) validate_phase2 ;;
    3) validate_phase3 ;;
    4) validate_phase4 ;;
    5) validate_phase5 ;;
    metrics) validate_success_metrics ;;
    all)
        validate_phase1
        validate_phase2
        validate_phase3
        validate_phase4
        validate_phase5
        validate_success_metrics
        ;;
    *)
        echo "Usage: $0 [1|2|3|4|5|metrics|all]"
        exit 1
        ;;
esac

# Summary
echo -e "${BLUE}═══════════════════════════════════════${NC}"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ Validation passed!${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation passed with $WARNINGS warnings${NC}"
else
    echo -e "${RED}✗ Validation failed: $ERRORS errors, $WARNINGS warnings${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════${NC}"

exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
