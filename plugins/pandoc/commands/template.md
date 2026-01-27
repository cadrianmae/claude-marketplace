---
description: Generate document template with frontmatter
argument-hint: <type> [output-file]
allowed-tools: Bash, Read
disable-model-invocation: true
---

## Environment Check (Auto-Captured)

**Pandoc**: !`command -v pandoc >/dev/null && pandoc --version | head -1 || echo "✗ Not installed"`
**XeLaTeX**: !`command -v xelatex >/dev/null && echo "✓ Available" || echo "✗ Not found"`
**Current Directory**: !`pwd`

## Quick Example

```bash
/pandoc:template academic-paper paper.md
# ✅ paper.md created from academic-paper template
# Ready to customize title, author, bibliography
```

# /pandoc:template - Document Templates

Ask Claude to create a document from template.

## Available Templates

- `academic-paper` - Paper with citations
- `thesis` - Thesis/report with title page
- `presentation-beamer` - PDF slides
- `presentation-reveal` - Web slides
- `article` - Simple article
- `bibtex` - Bibliography examples

## Quick Reference

**YAML Frontmatter Example:**
```yaml
---
title: "Paper Title"
author: "Your Name"
date: "November 2024"
bibliography: references.bib
csl: harvard.csl
documentclass: report
fontsize: 12pt
geometry: margin=1in
---
```

**BibTeX Entry Example:**
```bibtex
@article{smith2024,
  author  = {Smith, John},
  title   = {Paper Title},
  journal = {Journal Name},
  year    = {2024},
  volume  = {42},
  pages   = {123--145}
}
```

**Citation Syntax:**
```markdown
[@smith2024] or @smith2024 found that...
```

## Ask Claude

"Create an academic paper template"
"Show me the thesis template"
"Set up a new document with bibliography"
