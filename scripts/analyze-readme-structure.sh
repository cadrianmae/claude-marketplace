#!/bin/bash
# Analyze README structure to identify what needs standardization

cd "$(dirname "$0")/.."

echo "README Structure Analysis"
echo "========================="
echo ""

for plugin in plugins/*/; do
    name=$(basename "$plugin")
    readme="$plugin/README.md"

    if [ ! -f "$readme" ]; then
        echo "❌ $name - No README.md"
        continue
    fi

    echo "📄 $name"

    # Check for target sections
    has_overview=$(grep -c "^## Overview" "$readme" || echo 0)
    has_quickstart=$(grep -c "^## Quick Start" "$readme" || echo 0)
    has_commands=$(grep -Ec "^## (Commands|Skills|Usage)" "$readme" || echo 0)
    has_examples=$(grep -c "^## Examples" "$readme" || echo 0)
    has_config=$(grep -c "^## Configuration" "$readme" || echo 0)
    has_license=$(grep -c "^## License" "$readme" || echo 0)

    # Count total sections
    total_sections=$(grep -c "^## " "$readme")

    echo "  Sections: $total_sections total"
    [ "$has_overview" -gt 0 ] && echo "  ✓ Overview" || echo "  ✗ Overview"
    [ "$has_quickstart" -gt 0 ] && echo "  ✓ Quick Start" || echo "  ✗ Quick Start"
    [ "$has_commands" -gt 0 ] && echo "  ✓ Commands/Skills" || echo "  ✗ Commands/Skills"
    [ "$has_examples" -gt 0 ] && echo "  ✓ Examples" || echo "  ✗ Examples"
    [ "$has_license" -gt 0 ] && echo "  ✓ License" || echo "  ✗ License"
    echo ""
done
