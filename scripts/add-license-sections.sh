#!/bin/bash
# Add License sections to READMEs missing them

cd "$(dirname "$0")/.."

PLUGINS_MISSING_LICENSE=(
    "cadrianmae-integration"
    "semantic-search"
)

for plugin in "${PLUGINS_MISSING_LICENSE[@]}"; do
    readme="plugins/$plugin/README.md"

    if [ ! -f "$readme" ]; then
        echo "⚠️  $plugin: README.md not found"
        continue
    fi

    # Check if License section already exists
    if grep -q "^## License" "$readme"; then
        echo "✓ $plugin: License section already exists"
        continue
    fi

    # Add License section at the end
    cat >> "$readme" << 'EOF'

## License

MIT License - see [LICENSE](./LICENSE) for details.
EOF

    echo "✓ $plugin: Added License section"
done

echo ""
echo "License sections added successfully!"
