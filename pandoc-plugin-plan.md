# Pandoc Document Conversion Plugin - Implementation Plan

**Date:** 2025-11-16
**Context:** Child session research on Pandoc completed
**Status:** Ready for implementation

---

## User Preferences

- **Scope:** General Pandoc (all formats: PDF, DOCX, HTML, presentations)
- **Templates:** Include template library as assets
- **Location:** Marketplace plugin (shareable)
- **Zotero:** No integration (start simple, maybe later)

---

## Plugin Structure

Following the semantic-search plugin pattern:

```
plugins/pandoc/
├── .claude-plugin/
│   └── plugin.json                    # Plugin metadata
├── commands/
│   ├── convert.md                     # /pandoc:convert
│   ├── template.md                    # /pandoc:template
│   ├── frontmatter.md                 # /pandoc:frontmatter
│   ├── validate.md                    # /pandoc:validate
│   └── defaults.md                    # /pandoc:defaults
├── skills/
│   └── pandoc/
│       ├── SKILL.md                   # Main skill definition
│       ├── references/
│       │   ├── conversion_guide.md    # Format-specific conversion
│       │   ├── yaml_reference.md      # YAML variables reference
│       │   ├── templates_guide.md     # Template usage guide
│       │   └── troubleshooting.md     # Common issues & fixes
│       └── assets/
│           └── templates/
│               ├── academic-paper.yaml         # Academic paper template
│               ├── thesis-report.yaml          # Thesis/report template
│               ├── presentation-beamer.yaml    # Beamer presentation
│               ├── presentation-revealjs.yaml  # reveal.js presentation
│               ├── article-simple.yaml         # Simple article
│               └── defaults-pdf.yaml           # Basic PDF defaults
├── README.md                          # User-facing documentation
└── LICENSE                            # MIT license
```

---

## Commands to Implement (5 total)

### 1. `/pandoc:convert <input> [output] [options]`

**Purpose:** Convert markdown files to various formats with validation

**Examples:**
```bash
/pandoc:convert proposal.md proposal.pdf
/pandoc:convert notes.md slides.html --to revealjs
/pandoc:convert paper.md paper.pdf --pdf-engine=xelatex --citeproc
```

**Features:**
- Auto-detect format from extension
- Auto-add `--citeproc` if bibliography detected
- Auto-add `--pdf-engine=xelatex` for PDF
- Validate before conversion
- Clear error messages

**Frontmatter:**
```yaml
---
description: Convert markdown to various formats with validation
argument-hint: <input> [output] [options]
allowed-tools: Bash, Read, Write
disable-model-invocation: true
---
```

### 2. `/pandoc:template <template-type> [output-file]`

**Purpose:** Generate frontmatter template for document types

**Template types:**
- `academic-paper` - Academic paper with citations
- `thesis` - Thesis/report with custom title page
- `presentation-beamer` - LaTeX Beamer slides
- `presentation-reveal` - reveal.js web slides
- `article` - Simple article format
- `list` - Show all available templates

**Examples:**
```bash
/pandoc:template academic-paper paper.md
/pandoc:template thesis
/pandoc:template list
```

**Features:**
- Shows template with inline explanations
- Optionally creates file
- Includes common YAML for document type

### 3. `/pandoc:validate <file>`

**Purpose:** Validate markdown file before conversion

**Checks:**
- YAML frontmatter syntax (spaces, not tabs)
- Bibliography file exists
- CSL file exists
- Image paths are valid
- Required fields present

**Example output:**
```
✓ YAML syntax valid
✓ Bibliography found: references.bib
✓ CSL file found: harvard.csl
✓ All images exist (3 checked)
⚠ Warning: Date format could be standardized
✓ Required fields present

Validation passed with 1 warning.
```

### 4. `/pandoc:frontmatter <file>`

**Purpose:** Generate or update frontmatter for existing markdown

**Features:**
- Detects existing frontmatter
- Validates YAML syntax
- Suggests missing fields
- Offers to add/update
- Preserves content

### 5. `/pandoc:defaults <format> [output-file]`

**Purpose:** Generate defaults file for consistent conversions

**Formats:** pdf, docx, html, beamer, revealjs

**Generated file example (PDF):**
```yaml
from: markdown
to: pdf
pdf-engine: xelatex
citeproc: true
number-sections: true
standalone: true
metadata:
  lang: en-GB
  fontsize: 12pt
  geometry: margin=1in
```

Usage: `pandoc document.md --defaults=defaults.yaml`

---

## Template Library (6 templates)

### 1. academic-paper.yaml
```yaml
---
title: "Your Paper Title"
author: "Your Name"
date: "Month Year"
student-id: "C21348423"
lang: en-GB

bibliography: references.bib
csl: harvard.csl
link-citations: true

documentclass: report
fontsize: 12pt
geometry: margin=1in
linestretch: 1.5
numbersections: true
toc: true
toc-depth: 3

header-includes: |
  \usepackage{graphicx}
---
```

### 2. thesis-report.yaml
Extended academic template with:
- Custom title page (LaTeX)
- Declaration section
- Supervisor field
- Institution details
- Chapter numbering
- List of figures/tables

### 3. presentation-beamer.yaml
Beamer presentation with:
- Theme selection
- Slide formatting
- Code highlighting
- Incremental lists

### 4. presentation-revealjs.yaml
reveal.js web presentation with:
- Theme and transitions
- Slide backgrounds
- Speaker notes
- Responsive design

### 5. article-simple.yaml
Minimal article template:
- Basic metadata
- Simple formatting
- Quick start

### 6. defaults-pdf.yaml
Reusable defaults file for consistent project-wide conversions

---

## Reference Documentation (4 files)

### 1. conversion_guide.md
Format-specific conversion instructions:
- PDF (XeLaTeX vs pdfLaTeX, Unicode support)
- DOCX (reference templates, style mapping)
- HTML (standalone, CSS, self-contained)
- Presentations (Beamer vs reveal.js)

### 2. yaml_reference.md
Comprehensive YAML variables:
- Core metadata (title, author, date)
- Bibliography (bibliography, csl, link-citations)
- PDF output (documentclass, geometry, fonts)
- Table of contents (toc, toc-depth)
- Numbering (numbersections, secnumdepth)
- Custom LaTeX (header-includes)

### 3. templates_guide.md
How to use and customize templates:
- Using templates
- Creating custom templates
- Template inheritance
- Defaults files for consistency

### 4. troubleshooting.md
Common issues and solutions:
- YAML issues (tabs vs spaces, indentation)
- PDF generation (missing packages, fonts)
- Citations (BibTeX errors, CSL not found)
- Performance (large documents, memory)

---

## Auto-Invoked Skill (SKILL.md)

**Frontmatter:**
```yaml
---
name: pandoc
description: Automatically assist with Pandoc document conversions when user mentions converting markdown to PDF/DOCX/HTML or other formats. Validate YAML frontmatter, check dependencies (bibliography, images), and provide format-specific conversion guidance. Use when user asks about citations, academic papers, or document generation.
allowed-tools: Bash, Read, Write
---
```

**When to invoke:**
- User mentions "convert to PDF", "generate PDF", "export to Word"
- User asks about "pandoc", "markdown to PDF", "citations"
- User shows markdown with YAML frontmatter
- User asks "how do I convert this to..."

**What NOT to auto-invoke for:**
- General markdown questions
- When user mentions other converters
- Simple markdown rendering

**Behavior:**
1. Check if file has frontmatter (validate)
2. Suggest adding frontmatter if missing
3. Explain conversion command
4. Offer to convert if validated

---

## Implementation Steps (10 steps, ~2-3 hours)

### Phase 1: Structure & Metadata (~15 min)

1. **Initialize with skill-creator**
   - Run `init_skill.py pandoc`
   - Create plugin directory structure

2. **Create plugin metadata**
   - plugin.json with description and keywords
   - README.md with features and quick start
   - LICENSE (MIT)

### Phase 2: Template Library (~30 min)

3. **Create 6 template files**
   - academic-paper.yaml
   - thesis-report.yaml
   - presentation-beamer.yaml
   - presentation-revealjs.yaml
   - article-simple.yaml
   - defaults-pdf.yaml
   - Include inline comments explaining fields

### Phase 3: Commands (~1.5 hours)

4. **Implement /pandoc:template** (~20 min)
   - List available templates
   - Display template with explanations
   - Optionally create file from template
   - Add `disable-model-invocation: true`

5. **Implement /pandoc:validate** (~30 min)
   - Python validation script
   - Check YAML syntax (spaces not tabs)
   - Verify bibliography/CSL files exist
   - Check image paths
   - Clear error/warning messages

6. **Implement /pandoc:convert** (~25 min)
   - Bash wrapper with smart defaults
   - Auto-detect format from extension
   - Auto-add --citeproc if bibliography
   - Run validation before conversion
   - Handle errors gracefully

7. **Implement /pandoc:frontmatter** (~15 min)
   - Detect existing frontmatter
   - Suggest missing fields
   - Add/update YAML block

8. **Implement /pandoc:defaults** (~15 min)
   - Generate format-specific defaults files
   - Support PDF, DOCX, HTML, Beamer, reveal.js

### Phase 4: Documentation (~30 min)

9. **Write SKILL.md and references**
   - Auto-invocation triggers and patterns
   - conversion_guide.md - Format-specific instructions
   - yaml_reference.md - All YAML variables
   - templates_guide.md - Template usage
   - troubleshooting.md - Common errors

### Phase 5: Integration (~20 min)

10. **Test, register, commit**
    - Test with FYP proposal file
    - Register in marketplace.json
    - Commit and push to GitHub

---

## Validation Logic (Python)

```python
#!/usr/bin/env python3
"""Validate Pandoc markdown file"""

import yaml
import sys
import os

def validate_file(filepath):
    """Validate markdown file with YAML frontmatter"""
    issues = []
    warnings = []

    # Check file exists
    if not os.path.exists(filepath):
        return False, [f"File not found: {filepath}"], []

    # Read and parse YAML frontmatter
    with open(filepath, 'r') as f:
        content = f.read()

    if not content.startswith('---'):
        issues.append("No YAML frontmatter found")
        return False, issues, warnings

    try:
        yaml_end = content.index('---', 3)
        yaml_content = content[3:yaml_end]
        metadata = yaml.safe_load(yaml_content)
    except ValueError:
        issues.append("YAML not properly closed (missing second ---)")
        return False, issues, warnings
    except yaml.YAMLError as e:
        issues.append(f"YAML syntax error: {e}")
        return False, issues, warnings

    # Check for tabs
    if '\t' in yaml_content:
        issues.append("YAML contains tabs - use spaces")

    # Validate files
    if 'bibliography' in metadata:
        if not os.path.exists(metadata['bibliography']):
            issues.append(f"Bibliography not found: {metadata['bibliography']}")

    if 'csl' in metadata:
        if not os.path.exists(metadata['csl']):
            issues.append(f"CSL file not found: {metadata['csl']}")

    # Check required fields
    for field in ['title', 'author']:
        if field not in metadata:
            warnings.append(f"Missing recommended field: {field}")

    return len(issues) == 0, issues, warnings
```

---

## Conversion Helper (Bash)

```bash
#!/bin/bash
# Pandoc conversion with smart defaults

INPUT="$1"
OUTPUT="$2"
shift 2
EXTRA_ARGS="$@"

# Auto-detect format
EXT="${OUTPUT##*.}"
case "$EXT" in
    pdf) PDF_ENGINE="--pdf-engine=xelatex" ;;
    html|htm) HTML_OPTS="--standalone --self-contained" ;;
esac

# Check for bibliography
if grep -q "^bibliography:" "$INPUT"; then
    CITEPROC="--citeproc"
fi

# Run conversion
pandoc "$INPUT" -o "$OUTPUT" \
    $PDF_ENGINE \
    $HTML_OPTS \
    $CITEPROC \
    $EXTRA_ARGS

[[ $? -eq 0 ]] && echo "✓ Conversion successful: $OUTPUT" || echo "✗ Conversion failed"
```

---

## Plugin Metadata (plugin.json)

```json
{
  "name": "pandoc",
  "version": "1.0.0",
  "description": "Document conversion toolkit for Pandoc with templates, validation, and format-specific helpers. Convert markdown to PDF, DOCX, HTML, and presentations with smart defaults and YAML frontmatter validation.",
  "author": {
    "name": "Mae Capacite",
    "email": "cadrianmae@users.noreply.github.com"
  },
  "homepage": "https://github.com/cadrianmae/claude-marketplace",
  "repository": "https://github.com/cadrianmae/claude-marketplace",
  "license": "MIT",
  "keywords": [
    "pandoc",
    "markdown",
    "pdf",
    "conversion",
    "academic",
    "documents",
    "latex",
    "citations",
    "bibliography"
  ]
}
```

---

## Common Workflows

### Workflow 1: Quick Academic Paper
```bash
/pandoc:template academic-paper paper.md
# Edit paper.md
/pandoc:validate paper.md
/pandoc:convert paper.md paper.pdf
```

### Workflow 2: Project with Defaults
```bash
/pandoc:defaults pdf .pandoc/defaults.yaml
# Create documents with simple frontmatter
pandoc chapter1.md --defaults=.pandoc/defaults.yaml -o chapter1.pdf
```

### Workflow 3: Fix Existing Document
```bash
/pandoc:validate old-paper.md
/pandoc:frontmatter old-paper.md --fix
/pandoc:validate old-paper.md
/pandoc:convert old-paper.md old-paper.pdf
```

### Workflow 4: Web Presentation
```bash
/pandoc:template presentation-reveal slides.md
# Edit slides
/pandoc:convert slides.md slides.html
```

---

## Success Criteria

A user should be able to:

✅ Start new academic paper from template in 1 command
✅ Validate document before conversion (catch errors early)
✅ Convert markdown to PDF with smart defaults
✅ Fix frontmatter issues with guided assistance
✅ Create consistent conversions using defaults files
✅ Get helpful error messages when conversion fails
✅ Use templates for common document types
✅ Have Claude automatically assist with conversions

---

## Key Features

- **Smart validation** - Catch errors before conversion
- **Template library** - Quick start for common documents
- **Format auto-detection** - Less thinking, more converting
- **Clear error messages** - Explicit next steps
- **Auto-invoked skill** - Claude helps automatically
- **Neurodivergent-friendly** - Step-by-step, validated, templated

---

## Test Plan

Test with user's existing file:
- `/home/cadrianmae/git/github.com/cadrianmae/snappy-fyp/proposal/FYP_Proposal_Mae.md`
- Validate against best practices identified in research
- Ensure conversion works with existing setup

---

## Future Enhancements (Post-v1.0)

- Zotero integration (use zotero-local skill)
- Watch mode (auto-convert on save)
- Multi-file projects (combine chapters)
- Custom template creator
- Citation style switcher
- Image optimization
- Accessibility checker

---

## Estimated Time: 2-3 hours

**Ready for implementation when you are!** 💜
