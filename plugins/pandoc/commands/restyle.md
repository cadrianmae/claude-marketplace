---
description: Transform document to match target template style
argument-hint: <input> <target-style>
allowed-tools: Bash, Read, Write
disable-model-invocation: true
---

## Environment Check (Auto-Captured)

**Pandoc**: !`command -v pandoc >/dev/null && pandoc --version | head -1 || echo "✗ Not installed"`
**XeLaTeX**: !`command -v xelatex >/dev/null && echo "✓ Available" || echo "✗ Not found"`
**Current Directory**: !`pwd`

## Quick Example

```bash
/pandoc:restyle draft.md thesis
# ✅ draft.md restyled to thesis format
# Added: supervisor, institution, department, toc, lof, lot
```

# /pandoc:restyle - Restyle Document

Ask Claude to transform a document's frontmatter and structure to match a target template style.

## Available Styles

- `academic-paper` - Academic paper with citations
- `thesis` - Thesis/report with title page
- `article` - Simple article
- `presentation-beamer` - PDF slides
- `presentation-reveal` - Web slides

## What It Does

1. Reads current document and analyzes frontmatter
2. Replaces frontmatter with target template style
3. Preserves all markdown content
4. Suggests structural improvements if needed

## Quick Reference

**OCR → Academic Paper:**
```yaml
# Before (OCR metadata)
---
title: "Document Title"
processed_date: "2025-11-15"
ocr_model: "model-name"
---

# After (Academic)
---
title: "Paper Title"
author: "Author Name"
date: "Month Year"
bibliography: references.bib
csl: harvard.csl
documentclass: report
fontsize: 12pt
geometry: margin=1in
numbersections: true
---
```

**Simple → Thesis:**
```yaml
# Before
---
title: "Document"
author: "Name"
---

# After
---
title: "Thesis Title"
author: "Student Name"
supervisor: "Supervisor Name"
institution: "University Name"
department: "Department Name"
degree: "Degree Name"
bibliography: references.bib
csl: harvard.csl
documentclass: report
toc: true
lof: true
lot: true
---
```

## Workflow

1. Backup: `cp document.md document.md.bak`
2. Ask Claude to restyle to target template
3. Review frontmatter changes
4. Edit custom fields (author, title, etc.)
5. Validate: Check document is ready
6. Convert: Generate output

## Ask Claude

"Restyle this document to match the thesis template"
"Transform this OCR output to academic paper format"
"Convert this to presentation style"
"Reformat this with proper academic frontmatter"

## Common Transformations

**Template from PDF/OCR:**
- Remove: `source`, `processed_date`, `ocr_model`, `processor`
- Add: `author`, `date`, `documentclass`, `geometry`
- Update: `title` to actual document title

**Blog/Draft → Academic:**
- Add: `bibliography`, `csl`, `documentclass`
- Add: `fontsize`, `geometry`, `numbersections`
- Structure: Academic section organization

**Article → Thesis:**
- Add: `supervisor`, `institution`, `department`, `degree`
- Add: `toc`, `lof`, `lot`
- Add: Abstract, Declaration, Acknowledgements sections
