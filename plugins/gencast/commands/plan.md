---
description: "Generate podcast planning document without creating audio"
argument-hint: <input-file>
allowed-tools: Bash, Read
---

## Current Context (Auto-Captured)

**Working Directory**: !`pwd`
**Git Branch**: !`git branch --show-current 2>/dev/null || echo "Not in git repo"`
**Recent Files**: !`ls -1t | head -3 | tr '\n' ', ' | sed 's/,$//'`

# /gencast:plan - Generate Podcast Planning Document

## Quick Example

```bash
/gencast:plan lecture_notes.md
# Generates lecture_notes_plan.txt with document structure, key topics, and conversational flow
```

Generate a comprehensive planning document for a podcast without creating the audio file. Useful for reviewing coverage before committing to audio synthesis.

## Usage

```
/gencast:plan <input-file>
```

## Arguments

- `<input-file>` - Document to create podcast plan from (markdown, text, or PDF)

## Behavior

Runs gencast with:
- `--minimal` (always)
- `--with-planning` (generate plan)
- `--save-plan` (save to text file)
- Does NOT generate audio

## Implementation

```bash
# Check gencast installation
if ! command -v gencast &> /dev/null; then
    echo "[ERROR] gencast is not installed"
    echo "Install with: pip install gencast"
    exit 1
fi

# Validate input file
INPUT="$1"
if [[ ! -f "$INPUT" ]]; then
    echo "[ERROR] Input file not found: $INPUT"
    exit 1
fi

# Determine output plan file name
BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
PLAN_FILE="${BASENAME}_plan.txt"

# Run gencast for planning only (no audio generation)
# NOTE: gencast still generates audio, but we only care about the plan file
gencast "$INPUT" --minimal --with-planning --save-plan

# Report plan file location
echo ""
echo "[OK] Podcast plan generated"
echo ""
echo "Plan file: $PLAN_FILE"
echo ""
echo "Review the plan, then generate audio with:"
echo "  /gencast:podcast $INPUT --with-planning"
```

## Output

Creates a text file with the podcast planning document:

```
<input>_plan.txt
```

The plan includes:
- Document structure analysis
- Key topics to cover
- Conversational flow
- Transition points
- Comprehensive coverage strategy

## Examples

### Example 1: Plan for Lecture Notes

```
/gencast:plan lecture_notes.md
```

Creates `lecture_notes_plan.txt`

### Example 2: Plan for Research Paper

```
/gencast:plan research_paper.md
```

Creates `research_paper_plan.txt`

### Example 3: Plan for Tutorial

```
/gencast:plan tutorial.md
```

Creates `tutorial_plan.txt`

## Use Cases

1. **Review Coverage** - Check what topics will be covered before generating audio
2. **Iterate on Content** - Review plan, update source document, regenerate plan
3. **Long Documents** - Ensure comprehensive coverage of complex material
4. **Content Validation** - Verify podcast will cover all key points

## Workflow

```
/gencast:plan document.md
→ Review document_plan.txt
→ Make adjustments to document.md if needed
→ /gencast:podcast document.md --with-planning
```

## Edge Cases

### PDF Input

PDFs require MISTRAL_API_KEY:

```bash
if [[ "$INPUT" == *.pdf ]]; then
    if [[ -z "$MISTRAL_API_KEY" ]]; then
        echo "[WARN] PDF input requires MISTRAL_API_KEY environment variable"
        echo "Set with: export MISTRAL_API_KEY=your_key"
        exit 1
    fi
fi
```

### No Input File

```bash
if [[ -z "$1" ]]; then
    echo "[ERROR] No input file provided"
    echo "Usage: /gencast:plan <input-file>"
    exit 1
fi
```
