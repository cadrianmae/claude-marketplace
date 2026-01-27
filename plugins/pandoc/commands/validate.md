---
description: Validate YAML frontmatter and dependencies
argument-hint: <file>
allowed-tools: Bash
disable-model-invocation: true
---

## Environment Check (Auto-Captured)

**Pandoc**: !`command -v pandoc >/dev/null && pandoc --version | head -1 || echo "✗ Not installed"`
**XeLaTeX**: !`command -v xelatex >/dev/null && echo "✓ Available" || echo "✗ Not found"`
**Current Directory**: !`pwd`

## Quick Example

```bash
/pandoc:validate document.md
# ✅ YAML frontmatter valid (spaces, no tabs)
# ✅ bibliography.bib exists
# ✅ Ready to convert
```

# /pandoc:validate - Validate Document

Ask Claude to check your document for errors before converting.

## What It Checks

- ✅ YAML syntax (spaces not tabs)
- ✅ Bibliography file exists
- ✅ CSL file exists
- ✅ Image files exist
- ✅ Required fields present

## Quick Reference

**Common YAML Errors:**
```yaml
# ❌ Wrong (tabs)
title:→"Paper"

# ✅ Correct (spaces)
title: "Paper"

# ❌ Wrong (missing quotes)
title: Paper: A Study

# ✅ Correct
title: "Paper: A Study"
```

**Required Structure:**
```yaml
---
title: "Title"
author: "Name"
---

# Content here
```

## Ask Claude

"Validate my document before converting"
"Check if this is ready to convert to PDF"
"Why won't my document convert?"
