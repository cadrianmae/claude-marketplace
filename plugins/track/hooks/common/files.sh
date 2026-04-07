#!/bin/bash
# File and directory management functions

# Ensure claude_usage directory exists
ensure_claude_usage_dir() {
    mkdir -p claude_usage
}

# Ensure file exists with preamble
ensure_file_with_preamble() {
    local file_path="$1"
    local file_type="$2"

    if [ -f "$file_path" ]; then
        return 0
    fi

    ensure_claude_usage_dir

    # Read template file
    local template_file="$SCRIPT_DIR/templates/${file_type}.md"
    if [ -f "$template_file" ]; then
        cat "$template_file" > "$file_path"
    else
        # Fallback if template not found
        echo "# ${file_type^}" > "$file_path"
        echo "" >> "$file_path"
        echo "Template file not found: $template_file" >> "$file_path"
    fi
}
