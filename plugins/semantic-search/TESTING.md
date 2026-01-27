# Semantic Search Plugin Testing Guide

## Test Environments

Test in three environments:

1. **Indexed codebase** - `.odino` directory exists
2. **Unindexed codebase** - No `.odino` directory
3. **Non-git directory** - Not in a git repository

## Test Cases

### Indexing (`/semq:index`)

**Test 1: First-time indexing**
```bash
cd /path/to/project
/semq:index
# Expected: Index created in .odino/, file count displayed
```

**Test 2: Re-indexing existing index**
```bash
/semq:index
# Expected: Existing index updated, new file count shown
```

**Test 3: Empty directory**
```bash
mkdir empty-test && cd empty-test
/semq:index
# Expected: Warning about no files to index
```

### Searching (`/semq:search`)

**Test 4: Successful search**
```bash
/semq:search authentication middleware
# Expected: Ranked results with relevance scores
```

**Test 5: No matches**
```bash
/semq:search zxqwertasdfjkl
# Expected: "No results found" with suggestions
```

**Test 6: Search before indexing**
```bash
cd new-project
/semq:search query
# Expected: Error suggesting to run /semq:index first
```

### Status (`/semq:status`)

**Test 7: Index status**
```bash
/semq:status
# Expected: Index metadata (files, chunks, model, timestamp)
```

**Test 8: No index**
```bash
cd unindexed-project
/semq:status
# Expected: "Not initialized" message
```

### Here Command (`/semq:here`)

**Test 9: Search in current directory**
```bash
cd src/
/semq:here error handling
# Expected: Results filtered to src/ subdirectory
```

## Edge Cases

### Large Codebases
- Test with 10,000+ files
- Verify indexing doesn't timeout
- Check memory usage during search

### Special File Types
- Binary files (should be skipped)
- Large files (> 10MB)
- Non-UTF8 encodings

### Search Queries
- Single word queries
- Multi-word queries
- Technical terms (camelCase, snake_case)
- Code snippets

## Performance Benchmarks

| Operation | Small (< 100 files) | Medium (100-1000 files) | Large (1000+ files) |
|-----------|---------------------|-------------------------|---------------------|
| Indexing  | < 5s                | < 30s                   | < 2min              |
| Search    | < 1s                | < 2s                    | < 3s                |
| Status    | < 0.5s              | < 0.5s                  | < 0.5s              |

## Common Issues

### Issue: odino command not found
**Solution**: Verify odino is installed, provide installation instructions

### Issue: Index corruption
**Solution**: Remove `.odino/` and re-run `/semq:index`

### Issue: Poor search results
**Solution**: Check query phrasing, try synonyms, verify index is up-to-date

## Alternative Tools

Per FUTURE.md, consider evaluating:
- Sourcegraph's `src`
- Zoekt
- ripgrep + semantic layer
- Custom SQLite FTS5 + embeddings

## Automated Testing

Run validation script:
```bash
./scripts/validate-marketplace.sh 5
```

Expected output: All semantic-search progressive disclosure checks pass
