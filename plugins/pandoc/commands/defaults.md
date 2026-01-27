---
description: Generate defaults file for consistent conversions
argument-hint: <format> [output-file]
allowed-tools: Bash, Write
disable-model-invocation: true
---

## Environment Check (Auto-Captured)

**Pandoc**: !`command -v pandoc >/dev/null && pandoc --version | head -1 || echo "✗ Not installed"`
**XeLaTeX**: !`command -v xelatex >/dev/null && echo "✓ Available" || echo "✗ Not found"`
**Current Directory**: !`pwd`

## Quick Example

```bash
/pandoc:defaults pdf defaults.yaml
# ✅ defaults.yaml created with PDF settings
# Use: pandoc doc.md --defaults=defaults.yaml -o output.pdf
```

# /pandoc:defaults - Defaults File

Ask Claude to create a defaults file for project-wide settings.

## Quick Reference

**PDF Defaults:**
```yaml
from: markdown
to: pdf
pdf-engine: pdflatex
citeproc: true
number-sections: true
metadata:
  fontsize: 12pt
  geometry: margin=1in
```

**Use defaults:**
```bash
pandoc doc.md --defaults=defaults.yaml -o output.pdf
```

**Makefile Integration:**
```makefile
%.pdf: %.md defaults.yaml
	pandoc $< --defaults=defaults.yaml -o $@
```

## Available Formats

- `pdf` - PDF with pdflatex
- `html` - Standalone HTML
- `docx` - Word documents
- `beamer` - PDF presentations
- `revealjs` - Web presentations

## Ask Claude

"Create a PDF defaults file for my project"
"Set up defaults for consistent conversions"
"Generate defaults for HTML output"
