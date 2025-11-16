# Pandoc Document Conversion Plugin

Comprehensive Pandoc toolkit for converting markdown to PDF, DOCX, HTML, and presentations with smart defaults, template library, and YAML frontmatter validation.

## Features

- **Smart Validation** - Catch YAML syntax and dependency errors before conversion
- **Template Library** - Quick start templates for academic papers, theses, and presentations
- **Format Auto-Detection** - Automatically detect output format from file extension
- **Auto-Invoked Skill** - Claude automatically helps when you mention document conversion
- **Clear Error Messages** - Explicit next steps when conversion fails
- **Neurodivergent-Friendly** - Step-by-step workflows with validation at each stage

## Quick Start

### Convert Markdown to PDF

```bash
/pandoc:convert paper.md paper.pdf
```

### Start from Template

```bash
/pandoc:template academic-paper paper.md
# Edit paper.md
/pandoc:validate paper.md
/pandoc:convert paper.md paper.pdf
```

### Validate Before Converting

```bash
/pandoc:validate document.md
```

## Commands

- **`/pandoc:convert <input> [output] [options]`** - Convert markdown with smart defaults
- **`/pandoc:template <type> [file]`** - Generate template frontmatter
- **`/pandoc:validate <file>`** - Validate YAML and dependencies
- **`/pandoc:frontmatter <file>`** - Generate/update frontmatter
- **`/pandoc:defaults <format> [file]`** - Create defaults file for consistent conversions

## Templates

- `academic-paper` - Academic paper with citations
- `thesis` - Thesis/report with custom title page
- `presentation-beamer` - LaTeX Beamer slides
- `presentation-reveal` - reveal.js web presentations
- `article` - Simple article format
- `list` - Show all available templates

## Workflow Example

### Academic Paper

```bash
# 1. Create from template
/pandoc:template academic-paper proposal.md

# 2. Edit your markdown
# (Add your content, bibliography, etc.)

# 3. Validate before conversion
/pandoc:validate proposal.md

# 4. Convert to PDF
/pandoc:convert proposal.md proposal.pdf
```

### Project with Defaults

```bash
# 1. Create defaults file
/pandoc:defaults pdf .pandoc/defaults.yaml

# 2. Use for all conversions
pandoc chapter1.md --defaults=.pandoc/defaults.yaml -o chapter1.pdf
pandoc chapter2.md --defaults=.pandoc/defaults.yaml -o chapter2.pdf
```

## Auto-Invoked Skill

Claude will automatically assist when you:
- Mention converting markdown to PDF/DOCX/HTML
- Ask about citations or academic papers
- Show markdown with YAML frontmatter
- Ask "how do I convert this to..."

## Requirements

- Pandoc installed (`sudo dnf install pandoc` or `brew install pandoc`)
- XeLaTeX for PDF generation (`sudo dnf install texlive-xetex`)
- Python 3.8+ (for validation)
- Bibliography files (BibTeX) for citations

## Common Workflows

**Fix Existing Document:**
```bash
/pandoc:validate old-paper.md
/pandoc:frontmatter old-paper.md
/pandoc:validate old-paper.md
/pandoc:convert old-paper.md old-paper.pdf
```

**Web Presentation:**
```bash
/pandoc:template presentation-reveal slides.md
# Edit slides
/pandoc:convert slides.md slides.html
```

## Success Criteria

✅ Start academic paper from template in 1 command
✅ Validate before conversion (catch errors early)
✅ Convert with smart defaults (auto-add --citeproc, --pdf-engine)
✅ Fix frontmatter with guided assistance
✅ Create consistent conversions using defaults files

## License

MIT License - See LICENSE file for details

## Author

Mae Capacite (cadrianmae@users.noreply.github.com)
