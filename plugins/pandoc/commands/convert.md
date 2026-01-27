---
description: Convert markdown to PDF/DOCX/HTML with validation
argument-hint: <input> <output> [options]
allowed-tools: Bash, Read
disable-model-invocation: true
---

## Environment Check (Auto-Captured)

**Pandoc**: !`command -v pandoc >/dev/null && pandoc --version | head -1 || echo "✗ Not installed"`
**XeLaTeX**: !`command -v xelatex >/dev/null && echo "✓ Available" || echo "✗ Not found"`
**Current Directory**: !`pwd`

## Quick Example

```bash
/pandoc:convert research.md research.pdf
# ✅ research.pdf created successfully
```

# /pandoc:convert - Convert Document

Ask Claude to validate and convert your markdown file.

## Quick Reference

**Basic conversions:**
```bash
pandoc document.md -o document.pdf
pandoc document.md -o document.html --standalone
pandoc document.md -o document.docx
```

**With citations:**
```bash
pandoc paper.md -o paper.pdf --citeproc --number-sections
```

**Custom options:**
```bash
pandoc doc.md -o doc.pdf --pdf-engine=xelatex -V geometry:margin=1.5in
```

## Common Issues

- Missing LaTeX: `sudo dnf install texlive-scheme-medium`
- Unicode errors: Use `--pdf-engine=xelatex`
- Citations not showing: Add `--citeproc` flag

## Ask Claude

"Validate and convert paper.md to PDF with citations"
"Convert this document to HTML with table of contents"
"Help me convert to PDF - it's giving errors"
