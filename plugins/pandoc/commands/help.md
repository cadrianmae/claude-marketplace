---
description: "Get help with the Pandoc plugin - available commands and quick start guide"
disable-model-invocation: true
---

# Pandoc Plugin Help

Quick reference for the Pandoc document conversion plugin.

## Available Commands

- `/pandoc:help` - This help message
- `/pandoc:template` - Generate document templates (academic, thesis, presentations)
- `/pandoc:validate` - Validate YAML frontmatter and dependencies
- `/pandoc:convert` - Convert documents with smart defaults
- `/pandoc:frontmatter` - Add or update document metadata
- `/pandoc:restyle` - Transform document to match different template styles
- `/pandoc:defaults` - Generate reusable defaults files

## Quick Start

### Ask Claude to help with:

**Simple conversion:**
> "Convert this markdown file to PDF"

**Academic papers:**
> "Format this as an academic paper with citations"

**Presentations:**
> "Turn this into a presentation"

**Document transformation:**
> "Restyle this document to match thesis format"

**Validation:**
> "Check if my document is ready to convert"

## Common Tasks

### Convert to PDF
Just ask: "Convert document.md to PDF"

### Add Bibliography
Just ask: "Add bibliography support to this document"

### Fix Errors
Just ask: "This conversion failed, what's wrong?"

### Apply Template
Just ask: "Format this as [academic paper / thesis / presentation]"

## When Things Go Wrong

Common issues and what to ask:

**YAML errors:**
> "The YAML frontmatter has errors, can you fix it?"

**Missing files:**
> "It says bibliography file is missing, help me set this up"

**LaTeX errors:**
> "The PDF conversion failed with a LaTeX error"

**Citation issues:**
> "Citations aren't showing up in the output"

## Templates Available

- **academic-paper** - Research papers with citations
- **thesis-report** - Thesis/dissertation with custom title page
- **article-simple** - Simple article format
- **presentation-beamer** - LaTeX Beamer slides
- **presentation-revealjs** - Web-based reveal.js slides

## How It Works

The plugin auto-activates when you ask about:
- Document conversion
- PDF generation
- Bibliography/citations
- Academic formatting
- Templates

Just describe what you want to do - no need to know Pandoc syntax!

## Examples

> "I have a markdown file about my research, can you convert it to PDF?"

> "This needs to be formatted as an academic paper with Harvard citations"

> "Can you check if this document is ready to convert?"

> "Transform this into thesis format with table of contents"

## Need More Help?

For detailed information, use specific commands:
- `/pandoc:template` - Template details
- `/pandoc:convert` - Conversion options
- `/pandoc:validate` - Validation guide
- `/pandoc:restyle` - Document transformation

Or just ask Claude naturally about what you're trying to accomplish!
