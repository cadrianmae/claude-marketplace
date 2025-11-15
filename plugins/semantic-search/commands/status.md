---
description: Show semantic search index status and statistics
argument-hint: [path]
allowed-tools: Bash
disable-model-invocation: true
---

# status - Check semantic search index status

Show indexing status, statistics, and configuration for current or specified directory.

## Usage

```
/semq:status [path]
```

**Arguments:**
- `path` - Directory to check (optional, defaults to current directory)

## What It Does

1. Finds `.odino` directory by traversing up from specified path
2. Runs `odino status` to show index information
3. Displays:
   - Number of indexed files
   - Total chunks generated
   - Model name
   - Index location
   - Last modified date

## Examples

**Check current directory:**
```
/semq:status
```

**Check specific directory:**
```
/semq:status ~/projects/myapp
```

## Implementation

```bash
# Helper function to find .odino directory
find_odino_root() {
    local start_dir="${1:-.}"
    local dir="$(cd "$start_dir" && pwd)"

    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.odino" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get path argument or use current directory
CHECK_PATH="${1:-.}"

# Find index and show status
if ODINO_ROOT=$(find_odino_root "$CHECK_PATH"); then
    echo "Index found at: $ODINO_ROOT"
    echo ""

    # Run status command
    (cd "$ODINO_ROOT" && odino status)
else
    echo "No semantic search index found"
    if [[ "$CHECK_PATH" != "." ]]; then
        echo "Searched from: $CHECK_PATH"
    fi
    echo ""
    echo "To create an index, run:"
    echo "  /semq:index"
fi
```

## Output Example

```
Index found at: /home/user/project

Indexed files: 63
Total chunks: 142 (529.5 KB)
Model: BAAI/bge-small-en-v1.5
Last updated: 2025-11-15 22:30:45
```

## When to Use

Use `/semq:status` to:
- Check if a directory is indexed
- See how many files are indexed
- Verify which model is being used
- Check when index was last updated
- Troubleshoot search issues

## Related Commands

- `/semq:search <query>` - Search the index
- `/semq:index [path]` - Create or update index
- `/semq:here <query>` - Search with traversal

## Tips

1. **Before searching** - Run status to verify index exists
2. **After major changes** - Check if reindexing is needed
3. **Troubleshooting** - Use status to diagnose search issues
4. **Model verification** - Confirm BGE model is being used

## Configuration

The index configuration is stored in `.odino/config.json`:

```json
{
  "model_name": "BAAI/bge-small-en-v1.5",
  "embedding_batch_size": 16,
  "chunk_size": 512,
  "chunk_overlap": 50
}
```

To change configuration:
1. Edit `.odino/config.json` in the indexed directory
2. Reindex with `/semq:index --force`
