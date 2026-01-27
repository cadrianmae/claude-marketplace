---
description: Search from current directory upward to find indexed codebase
argument-hint: <query>
allowed-tools: Bash, Read
disable-model-invocation: true
---

# here - Semantic search with directory traversal

Search from current directory upward to find and search the nearest semantic index. Shows where the index was found for transparency.

## Usage

```
/semq:here <query>
```

**Arguments:**
- `query` - Natural language description of what to find (required)

## What It Does

1. Starts from current working directory
2. Traverses up the directory tree looking for `.odino/`
3. Shows where the index was found
4. Runs semantic search from that location
5. Displays results with scores and file paths

**Difference from `/semq:search`:**
- `/semq:search` - Assumes you know where the index is
- `/semq:here` - Explicitly shows index location (useful from subdirectories)

## Quick Example

```bash
/semq:here authentication middleware
# Output:
# ✓ Index found at: ../..
# Score: 0.89 | Path: src/auth/middleware.js
# Score: 0.82 | Path: src/auth/jwt.js
```

## Examples

**Search from subdirectory:**
```bash
cd src/utils/
/semq:here validation functions
```

**Find authentication from deep directory:**
```bash
cd src/routes/api/v1/
/semq:here authentication logic
```

## Implementation

```bash
# Helper function to find .odino directory with verbose output
find_odino_root_verbose() {
    local dir="$PWD"
    local depth=0

    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.odino" ]]; then
            echo "FOUND:$dir"
            return 0
        fi

        # Stop at git root as a boundary
        if [[ -d "$dir/.git" ]] && [[ ! -d "$dir/.odino" ]]; then
            echo "NOTFOUND:git-boundary:$dir"
            return 1
        fi

        dir="$(dirname "$dir")"
        depth=$((depth + 1))

        # Safety limit
        if [[ $depth -gt 20 ]]; then
            echo "NOTFOUND:max-depth"
            return 1
        fi
    done

    echo "NOTFOUND:filesystem-root"
    return 1
}

# Get query from arguments
QUERY="$*"

if [[ -z "$QUERY" ]]; then
    echo "Error: Query required"
    echo "Usage: /semq:here <query>"
    exit 1
fi

# Show current location
echo "Searching from: $PWD"
echo ""

# Find index with verbose output
RESULT=$(find_odino_root_verbose)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    ODINO_ROOT="${RESULT#FOUND:}"

    # Show where index was found
    if [[ "$ODINO_ROOT" == "$PWD" ]]; then
        echo "✓ Index found in current directory"
    else
        # Calculate relative path for clarity
        REL_PATH=$(realpath --relative-to="$PWD" "$ODINO_ROOT")
        echo "✓ Index found at: $REL_PATH"
    fi
    echo "  Location: $ODINO_ROOT"
    echo ""

    # Run search
    RESULTS=$(cd "$ODINO_ROOT" && odino query -q "$QUERY" 2>&1)

    if [[ $? -eq 0 ]]; then
        echo "$RESULTS"
        echo ""
        echo "💡 Tip: File paths are relative to: $ODINO_ROOT"
    else
        echo "Search failed:"
        echo "$RESULTS"
    fi
else
    # Parse failure reason
    REASON="${RESULT#NOTFOUND:}"

    echo "✗ No semantic search index found"
    echo ""

    case "$REASON" in
        git-boundary:*)
            GIT_ROOT="${REASON#git-boundary:}"
            echo "Searched up to git repository root: $GIT_ROOT"
            echo "The repository is not indexed."
            ;;
        filesystem-root)
            echo "Searched all the way to filesystem root"
            echo "No index found in any parent directory."
            ;;
        max-depth)
            echo "Reached maximum search depth (20 levels)"
            echo "Index might be higher up or doesn't exist."
            ;;
    esac

    echo ""
    echo "To create an index, navigate to your project root and run:"
    echo "  cd <project-root>"
    echo "  /semq:index"
fi
```

## Output Example

**From subdirectory:**
```
Searching from: /home/user/project/src/utils

✓ Index found at: ../..
  Location: /home/user/project

Score: 0.87 | Path: src/utils/validation.js
Score: 0.81 | Path: src/middleware/validate.js
Score: 0.74 | Path: src/schemas/user.js

💡 Tip: File paths are relative to: /home/user/project
```

**No index found:**
```
Searching from: /home/user/project/src/utils

✗ No semantic search index found
Searched up to git repository root: /home/user/project
The repository is not indexed.

To create an index, navigate to your project root and run:
  cd <project-root>
  /semq:index
```

## When to Use

Use `/semq:here` when:
- Working in a subdirectory
- Want to see where the index is located
- Unsure if directory is indexed
- Want explicit feedback about index location

Use `/semq:search` when:
- Already know the directory is indexed
- Don't need index location info
- Want simpler output

## Behavior

**Traversal stops at:**
1. `.odino/` directory found (success)
2. `.git/` directory without `.odino/` (git repository boundary)
3. Filesystem root `/` (no more parents)
4. 20 levels up (safety limit)

**Why stop at git root?**
- Projects are typically git repositories
- Prevents searching into parent projects
- Makes "not found" more meaningful

## Related Commands

- `/semq:search <query>` - Search without traversal info
- `/semq:status` - Check index status
- `/semq:index` - Create index

## Tips

1. **Use from subdirectories** - That's what this command is for
2. **Check the index location** - Helps understand project structure
3. **Git boundary** - Index should be at git root for best results
4. **Relative paths** - Results show paths relative to index location

## Troubleshooting

**"Searched up to git repository root"**
- The git repository is not indexed
- Solution: Run `/semq:index` from the git root

**"Searched all the way to filesystem root"**
- No index found anywhere in parent directories
- Not in a git repository
- Solution: Create index with `/semq:index`

**"Reached maximum search depth"**
- Very deep directory structure (>20 levels)
- Index might be higher up
- Solution: Navigate closer to project root and try again
