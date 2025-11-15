---
description: Index directory for semantic search
argument-hint: [path] [--force]
allowed-tools: Bash
---

# index - Create semantic search index

Index a directory for semantic search using odino with BGE embeddings.

## Usage

```
/semq:index [path] [--force]
```

**Arguments:**
- `path` - Directory to index (optional, defaults to current directory)
- `--force` - Force reindex even if index exists

## What It Does

1. Checks if directory already has an index
2. Runs `odino index` with BGE model (BAAI/bge-small-en-v1.5)
3. Creates `.odino/` directory with:
   - `config.json` - Configuration settings
   - `chroma_db/` - Vector database with embeddings
4. Shows progress and completion statistics

## Examples

**Index current directory:**
```
/semq:index
```

**Index specific directory:**
```
/semq:index ~/projects/myapp
```

**Force reindex:**
```
/semq:index --force
```

## Implementation

```bash
# Parse arguments
INDEX_PATH="."
FORCE_FLAG=""

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_FLAG="--force"
            ;;
        *)
            if [[ -d "$arg" ]]; then
                INDEX_PATH="$arg"
            else
                echo "Warning: Directory not found: $arg"
            fi
            ;;
    esac
done

# Convert to absolute path
INDEX_PATH="$(cd "$INDEX_PATH" && pwd)"

echo "Indexing directory: $INDEX_PATH"

# Check if already indexed
if [[ -d "$INDEX_PATH/.odino" ]] && [[ -z "$FORCE_FLAG" ]]; then
    echo ""
    echo "⚠️  Directory is already indexed"
    echo ""
    echo "To reindex, use: /semq:index --force"
    echo "To check status: /semq:status"
    exit 0
fi

# Create .odinoignore if it doesn't exist
if [[ ! -f "$INDEX_PATH/.odinoignore" ]]; then
    cat > "$INDEX_PATH/.odinoignore" << 'EOF'
# Build artifacts
build/
dist/
*.pyc
__pycache__/

# Dependencies
node_modules/
venv/
.venv/
.virtualenv/

# Config and secrets
.env
.env.local
*.secret
.git/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
    echo "Created .odinoignore file"
fi

# Run indexing with BGE model
echo ""
echo "Indexing with BGE model (this may take a moment)..."
echo ""

(cd "$INDEX_PATH" && odino index $FORCE_FLAG --model BAAI/bge-small-en-v1.5)

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✅ Indexing complete!"
    echo ""
    echo "You can now search with:"
    echo "  /semq:search <query>"
else
    echo ""
    echo "❌ Indexing failed"
    echo ""
    echo "Troubleshooting:"
    echo "- Ensure odino is installed: pipx install odino"
    echo "- Check disk space"
    echo "- Try again with --force flag"
fi
```

## Output Example

```
Indexing directory: /home/user/project
Created .odinoignore file

Indexing with BGE model (this may take a moment)...

Indexed 63 files
Generated 142 chunks (529.5 KB)
Model: BAAI/bge-small-en-v1.5

✅ Indexing complete!

You can now search with:
  /semq:search <query>
```

## When to Use

Use `/semq:index` when:
- Setting up semantic search for a new project
- Major code changes have been made
- Switching to a different embedding model
- Index is corrupted or outdated

## .odinoignore

The command automatically creates `.odinoignore` to exclude:
- Build artifacts (build/, dist/)
- Dependencies (node_modules/, venv/)
- Configuration files (.env, secrets)
- IDE files (.vscode/, .idea/)
- Version control (.git/)

**Customize `.odinoignore`** for your project:

```
# Project-specific ignores
generated/
*.min.js
vendor/
```

## Model Selection

The command uses **BAAI/bge-small-en-v1.5** by default:
- **Size:** 133MB (vs 600MB for default model)
- **Parameters:** 33M (vs 308M)
- **Quality:** ~62-63 MTEB score (vs ~69)
- **Speed:** Much faster indexing
- **Memory:** Lower RAM usage

**Why BGE?**
- 78% smaller download
- 90% fewer parameters
- Faster indexing and search
- Only ~7 point quality drop
- Better for most use cases

## Performance Tips

1. **Use .odinoignore** - Exclude unnecessary files
2. **GPU acceleration** - Indexing is much faster with CUDA
3. **Batch size** - Adjust in `.odino/config.json` (16 for GPU, 8 for CPU)
4. **Reindex periodically** - After major code changes

## Troubleshooting

**"Command not found: odino"**
```bash
pipx install odino
```

**GPU out of memory**
```bash
# Edit .odino/config.json after first index
{
  "embedding_batch_size": 8  # or 4
}
# Then reindex
/semq:index --force
```

**Slow indexing**
```bash
# BGE model is already the fastest option
# But you can reduce batch size if needed
# Edit .odino/config.json: "embedding_batch_size": 8
```

## Related Commands

- `/semq:status` - Check index status
- `/semq:search <query>` - Search the index
- `/semq:here <query>` - Search with traversal

## Configuration

After indexing, configuration is stored in `.odino/config.json`:

```json
{
  "model_name": "BAAI/bge-small-en-v1.5",
  "embedding_batch_size": 16,
  "chunk_size": 512,
  "chunk_overlap": 50
}
```

Edit this file to change settings, then reindex with `--force`.
