---
description: "Generate a podcast from document(s) with full control over style, audience, voices, and options"
argument-hint: <input-files...> [--style STYLE] [--audience AUDIENCE] [--with-planning] [--save-dialogue] [--save-plan] [-o OUTPUT]
allowed-tools: Bash, Read
---

# /gencast:podcast - Generate Podcast from Documents

Generate conversational podcasts from documents using gencast CLI with full control over options.

CRITICAL: Always uses `--minimal` flag to reduce context usage.

## Usage

```
/gencast:podcast <input-files...> [options]
```

## Arguments

- `<input-files...>` - One or more document files (markdown, text, or PDF)

## Options

- `--style <style>` - Podcast style: educational (default), interview, casual, debate
- `--audience <audience>` - Target audience: general (default), technical, academic, beginner
- `--with-planning` - Generate comprehensive planning document first
- `--save-dialogue` - Save generated dialogue script to text file
- `--save-plan` - Save planning document to text file (requires --with-planning)
- `-o, --output <path>` - Output podcast file path (default: podcast.mp3)
- `--host1-voice <voice>` - Voice for HOST1 (default: nova)
- `--host2-voice <voice>` - Voice for HOST2 (default: echo)

Available voices: alloy, echo, fable, onyx, nova, shimmer

## Workflow

1. Validate gencast is installed
2. Validate input files exist
3. Build gencast command with --minimal flag
4. Execute gencast
5. Report output location, duration, and any saved files

## Implementation

```bash
# Check gencast installation
if ! command -v gencast &> /dev/null; then
    echo "[ERROR] gencast is not installed"
    echo "Install with: pip install gencast"
    exit 1
fi

# Validate input files
for file in "$@"; do
    if [[ "$file" != -* && ! -f "$file" ]]; then
        echo "[ERROR] Input file not found: $file"
        exit 1
    fi
done

# Build gencast command from user options
# ALWAYS include --minimal flag
GENCAST_CMD="gencast --minimal"

# Add user-provided options
# Parse $@ for options and files
# Example construction:
# gencast input.md --minimal --style educational --audience general -o output.mp3

# Execute
eval "$GENCAST_CMD"

# Report results
echo ""
echo "[OK] Podcast generated successfully"
echo ""
echo "Output: <output-path>"
echo "Duration: <duration>"
echo "Style: <style>"
echo "Audience: <audience>"
if [[ -f "<output>_dialogue.txt" ]]; then
    echo ""
    echo "Additional files:"
    echo "  - <output>_dialogue.txt"
fi
if [[ -f "<output>_plan.txt" ]]; then
    echo "  - <output>_plan.txt"
fi
```

## Output Format

With `--minimal`, gencast shows:
- Milestone: Planning (if --with-planning)
- Milestone: Generating dialogue
- Milestone: Synthesizing audio
- Final: Output path and duration

## Examples

### Example 1: Basic Podcast

```
/gencast:podcast lecture_notes.md
```

Generates `podcast.mp3` with default educational style and general audience.

### Example 2: Interview Style for Technical Audience

```
/gencast:podcast api_docs.md --style interview --audience technical -o api_podcast.mp3
```

### Example 3: With Planning and Dialogue Saving

```
/gencast:podcast research_paper.md --with-planning --save-dialogue --save-plan -o research.mp3
```

Creates:
- `research.mp3` - Audio podcast
- `research_dialogue.txt` - Dialogue script
- `research_plan.txt` - Planning document

### Example 4: Multiple Files with Custom Voices

```
/gencast:podcast ch1.md ch2.md ch3.md --host1-voice alloy --host2-voice shimmer -o chapters_1-3.mp3
```

### Example 5: Casual Beginner-Friendly

```
/gencast:podcast intro.md --style casual --audience beginner -o intro_podcast.mp3
```

## Edge Cases

### PDF Input

PDFs require MISTRAL_API_KEY environment variable:

```bash
if [[ "$INPUT" == *.pdf ]]; then
    if [[ -z "$MISTRAL_API_KEY" ]]; then
        echo "[WARN] PDF input requires MISTRAL_API_KEY environment variable"
        echo "Set with: export MISTRAL_API_KEY=your_key"
        exit 1
    fi
fi
```

### Output File Exists

```bash
if [[ -f "$OUTPUT" ]]; then
    echo "[WARN] Output file $OUTPUT already exists and will be overwritten"
fi
```

### No Input Files

```bash
if [[ $# -eq 0 ]]; then
    echo "[ERROR] No input files provided"
    echo "Usage: /gencast:podcast <input-files> [options]"
    exit 1
fi
```

## Reference

See references/ for more details:
- `voices.md` - Voice options and characteristics
- `styles.md` - Style and audience combinations
