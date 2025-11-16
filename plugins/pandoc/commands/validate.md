---
description: Validate YAML frontmatter and dependencies
argument-hint: <file>
allowed-tools: Bash
disable-model-invocation: true
---

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
