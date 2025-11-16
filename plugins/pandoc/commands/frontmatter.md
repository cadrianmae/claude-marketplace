---
description: Add/update YAML frontmatter in markdown
argument-hint: <file> [template-type]
allowed-tools: Bash, Read, Write
disable-model-invocation: true
---

# /pandoc:frontmatter - Add Frontmatter

Ask Claude to add or update YAML frontmatter in your markdown file.

## Quick Reference

**Minimal Frontmatter:**
```yaml
---
title: "Document Title"
author: "Your Name"
date: "Date"
---
```

**Academic Paper:**
```yaml
---
title: "Research Paper"
author: "Student Name"
date: "November 2024"
bibliography: references.bib
csl: harvard.csl
documentclass: report
fontsize: 12pt
geometry: margin=1in
numbersections: true
toc: true
---
```

**Common Fields:**
- `title` - Document title
- `author` - Author name(s)
- `date` - Publication date
- `bibliography` - Path to .bib file
- `csl` - Citation style file
- `lang` - Language (en-GB, en-US)

## Ask Claude

"Add frontmatter to this markdown file"
"Update my document with academic template frontmatter"
"This file needs proper YAML frontmatter"
