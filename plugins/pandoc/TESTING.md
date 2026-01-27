# Pandoc Plugin Testing Guide

## Test Environments

Test in three environments to ensure graceful fallbacks:

1. **Full environment** - pandoc + XeLaTeX installed
2. **Partial environment** - pandoc only (no XeLaTeX)
3. **Minimal environment** - No pandoc installed

## Test Cases

### Basic Conversion (`/pandoc:convert`)

**Test 1: Markdown to PDF (Full environment)**
```bash
echo "# Test Document" > test.md
/pandoc:convert test.md pdf
# Expected: test.pdf created successfully
```

**Test 2: Markdown to DOCX (No dependencies needed)**
```bash
/pandoc:convert test.md docx
# Expected: test.docx created successfully
```

**Test 3: Missing pandoc (Minimal environment)**
```bash
/pandoc:convert test.md pdf
# Expected: Error message suggesting pandoc installation
```

### Template Handling (`/pandoc:template`)

**Test 4: Valid template**
```bash
/pandoc:template academic-paper
# Expected: Template content displayed or applied
```

**Test 5: Invalid template**
```bash
/pandoc:template nonexistent
# Expected: Clear error message listing available templates
```

### Validation (`/pandoc:validate`)

**Test 6: Valid YAML frontmatter**
```bash
cat > valid.md << 'EOF'
---
title: Test
author: Mae
---
# Content
EOF
/pandoc:validate valid.md
# Expected: Validation passes
```

**Test 7: Invalid YAML frontmatter**
```bash
cat > invalid.md << 'EOF'
---
title: "Unclosed quote
author: Mae
---
# Content
EOF
/pandoc:validate invalid.md
# Expected: Clear YAML parsing error message
```

## Edge Cases

### Large Documents
- Test with 100+ page documents
- Verify memory handling
- Check conversion timeouts

### Special Characters
- Unicode in filenames and content
- LaTeX special characters (%, $, &, etc.)
- Path with spaces

### Citations and Bibliography
- BibTeX file handling
- CSL style application
- Citation rendering

## Performance Benchmarks

| Operation | Small (< 10 pages) | Medium (10-50 pages) | Large (50+ pages) |
|-----------|-------------------|---------------------|-------------------|
| MD → PDF  | < 3s              | < 10s               | < 30s             |
| MD → DOCX | < 2s              | < 5s                | < 15s             |
| MD → HTML | < 1s              | < 3s                | < 10s             |

## Common Issues

### Issue: XeLaTeX not found
**Solution**: Install texlive-xelatex or suggest alternative output format

### Issue: Template not found
**Solution**: Verify template directory exists, provide template list

### Issue: YAML parsing fails
**Solution**: Show exact line with error, suggest YAML validator

## Automated Testing

Run validation script:
```bash
./scripts/validate-marketplace.sh 5
```

Expected output: All pandoc progressive disclosure checks pass
