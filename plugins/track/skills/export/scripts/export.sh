#!/bin/bash
# Export tracked data to various formats
# Part of Track Plugin v2.0 - called by /track:export skill

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

# Generate export based on format
case "$FORMAT" in
    bibliography)
        # Generate Markdown bibliography from sources
        {
            echo "# Bibliography"
            echo ""

            # Filter out preamble (everything before first ---)
            grep -v "^#" "$SOURCES_FILE" 2>/dev/null | grep -v "^$" | grep -v "^\*\*" | grep -v "^-" | grep -v "^\`" | grep "^\[" | nl -w1 -s'. '
        } > "${OUTPUT}"
        ;;

    methodology)
        # Generate methodology section from prompts
        {
            echo "# Methodology"
            echo ""
            echo "## Development Process"
            echo ""

            # Parse prompts file
            while IFS= read -r line; do
                if [[ "$line" =~ ^Prompt: ]]; then
                    PROMPT="${line#Prompt: }"
                    PROMPT="${PROMPT//\"/}"  # Remove quotes

                    # Read outcome (next line)
                    read -r outcome_line
                    OUTCOME="${outcome_line#Outcome: }"

                    # Read session (next line)
                    read -r session_line
                    SESSION="${session_line#Session: }"

                    # Output formatted section
                    echo "### ${PROMPT}"
                    echo "**Prompt:** \"${PROMPT}\""
                    echo ""
                    echo "**Outcome:** ${OUTCOME}"
                    echo ""
                    echo "**Session:** ${SESSION}"
                    echo ""
                    echo "---"
                    echo ""
                fi
            done < <(grep -A2 "^Prompt:" "$PROMPTS_FILE" 2>/dev/null)
        } > "${OUTPUT}"
        ;;

    bibtex)
        # Generate BibTeX entries from sources
        {
            counter=1
            while IFS= read -r line; do
                # Skip preamble
                [[ "$line" =~ ^# ]] && continue
                [[ "$line" =~ ^\*\* ]] && continue
                [[ "$line" =~ ^- ]] && continue
                [[ "$line" =~ ^\` ]] && continue
                [ -z "$line" ] && continue

                # Parse source line
                if [[ "$line" =~ WebSearch\(\"([^\"]+)\"\):\ (.+)$ ]]; then
                    query="${BASH_REMATCH[1]}"
                    url="${BASH_REMATCH[2]}"
                    key="ref_${counter}"

                    echo "@online{${key},"
                    echo "  title = {${query}},"
                    echo "  url = {${url}},"
                    echo "  urldate = {$(date +%Y-%m-%d)}"
                    echo "}"
                    echo ""

                    ((counter++))
                fi
            done < "$SOURCES_FILE"
        } > "${OUTPUT}"
        ;;

    citations)
        # Generate numbered citations
        {
            echo "# Citations"
            echo ""

            grep -v "^#" "$SOURCES_FILE" 2>/dev/null | grep -v "^$" | grep -v "^\*\*" | grep -v "^-" | grep -v "^\`" | grep "^\[" | nl -w1 -s'] '
        } > "${OUTPUT}"
        ;;

    timeline)
        # Generate chronological timeline
        {
            echo "# Development Timeline"
            echo ""
            echo "## $(date +%Y-%m-%d)"
            echo ""

            # Interleave sources and prompts (simplified - by line order)
            echo "### Research Sources"
            echo ""
            grep -v "^#" "$SOURCES_FILE" 2>/dev/null | grep -v "^$" | grep -v "^\*\*" | grep -v "^-" | grep -v "^\`" | grep "^\["
            echo ""

            echo "### Development Work"
            echo ""
            grep "^Prompt:" "$PROMPTS_FILE" 2>/dev/null | sed 's/^Prompt: /**Prompt:** /'
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
            ENTRY_COUNT=$(grep -c "^\[" "$SOURCES_FILE" 2>/dev/null || echo 0)
            ;;
        methodology)
            ENTRY_COUNT=$(grep -c "^Prompt:" "$PROMPTS_FILE" 2>/dev/null || echo 0)
            ;;
        bibtex)
            ENTRY_COUNT=$(grep -c "@online" "${OUTPUT}" 2>/dev/null || echo 0)
            ;;
        timeline)
            ENTRY_COUNT=$(($(grep -c "^\[" "$SOURCES_FILE" 2>/dev/null || echo 0) + $(grep -c "^Prompt:" "$PROMPTS_FILE" 2>/dev/null || echo 0)))
            ;;
    esac

    echo "✓ Export complete"
    echo ""
    echo "Format: $FORMAT"
    echo "Entries: $ENTRY_COUNT"
    echo "Output: $OUTPUT"
    echo ""
    echo "Preview:"
    head -10 "$OUTPUT"
fi
