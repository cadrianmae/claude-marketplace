#!/bin/bash
# Export tracked data to various formats
# Part of Track Plugin v2.1 - called by /track:export skill
# Supports both v2.0.5 (single-line) and v2.1.0 (multi-line) formats

# Parse arguments
FORMAT="$1"
OUTPUT="${2:-}"

# Validate format
case "$FORMAT" in
    bibliography|methodology|bibtex|citations|timeline)
        ;;
    *)
        echo "Error: Invalid format '$FORMAT'"
        echo ""
        echo "Valid formats:"
        echo "  - bibliography  : Markdown bibliography/works cited"
        echo "  - methodology   : Methodology section from prompts"
        echo "  - bibtex        : BibTeX entries for LaTeX"
        echo "  - citations     : Numbered citation list"
        echo "  - timeline      : Chronological timeline"
        exit 1
        ;;
esac

# Determine output path
if [ -z "$OUTPUT" ]; then
    # Use EXPORT_PATH from config
    EXPORT_PATH=$(grep "^EXPORT_PATH=" .claude/.ref-config 2>/dev/null | cut -d= -f2)
    EXPORT_PATH="${EXPORT_PATH:-exports/}"

    # Determine extension
    case "$FORMAT" in
        bibtex)
            EXT="bib"
            ;;
        *)
            EXT="md"
            ;;
    esac

    # Build output path
    OUTPUT="${EXPORT_PATH}${FORMAT}.${EXT}"

    # Create export directory if needed
    mkdir -p "$EXPORT_PATH"
elif [ "$OUTPUT" = "-" ]; then
    # Stdout mode
    OUTPUT="-"
else
    # User-specified path
    # Create parent directory if needed
    OUTPUT_DIR=$(dirname "$OUTPUT")
    mkdir -p "$OUTPUT_DIR"
fi

# Read tracked data
SOURCES_FILE="claude_usage/sources.md"
PROMPTS_FILE="claude_usage/prompts.md"

# Check if files exist
if [ ! -f "$SOURCES_FILE" ] && [ ! -f "$PROMPTS_FILE" ]; then
    echo "Error: No tracking files found. Run /track:init first."
    exit 1
fi

# Parse multi-line prompts.md entries (v2.1.0 format)
# Also handles v2.0.5 single-line format for backward compatibility
parse_prompts() {
    local file="$1"
    [ ! -f "$file" ] && return

    local in_entry=false
    local prompt=""
    local outcome=""
    local files=""
    local session=""

    while IFS= read -r line; do
        # Skip preamble
        [[ "$line" =~ ^# ]] && continue
        [[ "$line" =~ ^\*\* ]] && continue
        [[ "$line" =~ ^- ]] && continue
        [[ "$line" =~ ^\` ]] && continue

        if [[ "$line" =~ ^Prompt:\ \"(.*)\"$ ]]; then
            # New entry starts - output previous if exists
            if [ "$in_entry" = "true" ]; then
                echo "ENTRY|$prompt|$outcome|$files|$session"
            fi

            # Start new entry
            in_entry=true
            prompt="${BASH_REMATCH[1]}"
            outcome=""
            files=""
            session=""
        elif [[ "$line" =~ ^Outcome:\ (.*)$ ]]; then
            outcome="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Files:\ (.*)$ ]]; then
            files="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Session:\ (.*)$ ]]; then
            session="${BASH_REMATCH[1]}"
        elif [ -z "$line" ]; then
            # Blank line - end of entry
            if [ "$in_entry" = "true" ]; then
                echo "ENTRY|$prompt|$outcome|$files|$session"
                in_entry=false
            fi
        elif [ "$in_entry" = "true" ] && [ -n "$outcome" ]; then
            # Continuation of multi-line outcome
            outcome="$outcome $line"
        fi
    done < "$file"

    # Output last entry if exists
    if [ "$in_entry" = "true" ]; then
        echo "ENTRY|$prompt|$outcome|$files|$session"
    fi
}

# Parse multi-line sources.md entries (v2.1.0 format)
# Also handles v2.0.5 single-line format for backward compatibility
parse_sources() {
    local file="$1"
    [ ! -f "$file" ] && return

    local in_entry=false
    local attribution=""
    local tool=""
    local params=""
    local summary=""
    local links=""
    local files=""

    while IFS= read -r line; do
        # Skip preamble
        [[ "$line" =~ ^# ]] && continue
        [[ "$line" =~ ^\*\* ]] && continue
        [[ "$line" =~ ^- ]] && continue
        [[ "$line" =~ ^\` ]] && continue

        # v2.1.0 format: [Attribution] Tool(params)
        if [[ "$line" =~ ^\[([A-Za-z]+)\]\ ([A-Za-z]+)\((.*)\)$ ]]; then
            # New entry starts - output previous if exists
            if [ "$in_entry" = "true" ]; then
                echo "SOURCE|$attribution|$tool|$params|$summary|$links|$files"
            fi

            # Start new entry
            in_entry=true
            attribution="${BASH_REMATCH[1]}"
            tool="${BASH_REMATCH[2]}"
            params="${BASH_REMATCH[3]}"
            summary=""
            links=""
            files=""
        # v2.0.5 format: [Attribution] Tool("query"): Result
        elif [[ "$line" =~ ^\[([A-Za-z]+)\]\ ([A-Za-z]+)\(\"([^\"]+)\"\):\ (.+)$ ]]; then
            # Old format - convert to new
            attribution="${BASH_REMATCH[1]}"
            tool="${BASH_REMATCH[2]}"
            params="${BASH_REMATCH[3]}"
            summary="${BASH_REMATCH[4]}"
            links="$summary"  # In old format, result may contain URL
            files=""
            echo "SOURCE|$attribution|$tool|$params|$summary|$links|$files"
        elif [[ "$line" =~ ^Summary:\ (.*)$ ]]; then
            summary="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Links:\ (.*)$ ]]; then
            links="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Files:\ (.*)$ ]]; then
            files="${BASH_REMATCH[1]}"
        elif [ -z "$line" ]; then
            # Blank line - end of entry
            if [ "$in_entry" = "true" ]; then
                echo "SOURCE|$attribution|$tool|$params|$summary|$links|$files"
                in_entry=false
            fi
        elif [ "$in_entry" = "true" ] && [ -n "$summary" ]; then
            # Continuation of multi-line summary
            summary="$summary $line"
        fi
    done < "$file"

    # Output last entry if exists
    if [ "$in_entry" = "true" ]; then
        echo "SOURCE|$attribution|$tool|$params|$summary|$links|$files"
    fi
}

# Generate export based on format
case "$FORMAT" in
    bibliography)
        # Generate Markdown bibliography from sources
        {
            echo "# Bibliography"
            echo ""

            counter=1
            parse_sources "$SOURCES_FILE" | while IFS='|' read -r type attribution tool params summary links files; do
                if [ -n "$links" ] && [ "$links" != "NONE" ]; then
                    echo "${counter}. ${links}"
                    ((counter++))
                fi
            done
        } > "${OUTPUT}"
        ;;

    methodology)
        # Generate methodology section from prompts
        {
            echo "# Methodology"
            echo ""
            echo "## Development Process"
            echo ""

            parse_prompts "$PROMPTS_FILE" | while IFS='|' read -r type prompt outcome files session; do
                echo "### ${prompt}"
                echo ""
                echo "**Outcome:** ${outcome}"
                echo ""
                [ -n "$files" ] && [ "$files" != "NONE" ] && echo "**Files:** ${files}"
                [ -n "$files" ] && [ "$files" != "NONE" ] && echo ""
                echo "_Session: ${session}_"
                echo ""
                echo "---"
                echo ""
            done
        } > "${OUTPUT}"
        ;;

    bibtex)
        # Generate BibTeX entries from sources
        {
            counter=1
            parse_sources "$SOURCES_FILE" | while IFS='|' read -r type attribution tool params summary links files; do
                if [ -n "$links" ] && [ "$links" != "NONE" ]; then
                    key="ref_${counter}"

                    # Extract first URL if comma-separated
                    url=$(echo "$links" | cut -d, -f1 | xargs)

                    echo "@online{${key},"
                    echo "  title = {${params}},"
                    echo "  url = {${url}},"
                    echo "  urldate = {$(date +%Y-%m-%d)}"
                    echo "}"
                    echo ""

                    ((counter++))
                fi
            done
        } > "${OUTPUT}"
        ;;

    citations)
        # Generate numbered citations
        {
            echo "# Citations"
            echo ""

            counter=1
            parse_sources "$SOURCES_FILE" | while IFS='|' read -r type attribution tool params summary links files; do
                echo "[${counter}] ${summary}"
                [ -n "$links" ] && [ "$links" != "NONE" ] && echo "    ${links}"
                echo ""
                ((counter++))
            done
        } > "${OUTPUT}"
        ;;

    timeline)
        # Generate chronological timeline
        {
            echo "# Development Timeline"
            echo ""
            echo "## $(date +%Y-%m-%d)"
            echo ""

            echo "### Research Sources"
            echo ""
            parse_sources "$SOURCES_FILE" | while IFS='|' read -r type attribution tool params summary links files; do
                echo "- **[$attribution] $tool**: $summary"
            done
            echo ""

            echo "### Development Work"
            echo ""
            parse_prompts "$PROMPTS_FILE" | while IFS='|' read -r type prompt outcome files session; do
                echo "- **Prompt**: $prompt"
                echo "  - **Outcome**: $outcome"
                echo "  - **Session**: $session"
                echo ""
            done
        } > "${OUTPUT}"
        ;;
esac

# Show summary
if [ "$OUTPUT" = "-" ]; then
    cat "${OUTPUT}"
else
    ENTRY_COUNT=0
    case "$FORMAT" in
        bibliography|citations)
            ENTRY_COUNT=$(parse_sources "$SOURCES_FILE" | wc -l)
            ;;
        methodology)
            ENTRY_COUNT=$(parse_prompts "$PROMPTS_FILE" | wc -l)
            ;;
        bibtex)
            ENTRY_COUNT=$(grep -c "@online" "${OUTPUT}" 2>/dev/null || echo 0)
            ;;
        timeline)
            ENTRY_COUNT=$(($(parse_sources "$SOURCES_FILE" | wc -l) + $(parse_prompts "$PROMPTS_FILE" | wc -l)))
            ;;
    esac

    echo "✓ Export complete"
    echo ""
    echo "Format: $FORMAT"
    echo "Entries: $ENTRY_COUNT"
    echo "Output: $OUTPUT"
    echo ""
    echo "Preview:"
    head -20 "$OUTPUT"
fi
