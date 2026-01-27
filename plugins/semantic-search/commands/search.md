---
description: Search indexed codebase using natural language semantic search
argument-hint: <query>
allowed-tools: Bash, Read
disable-model-invocation: true
---

# search - Semantic search in current directory

Search the current directory's semantic index using natural language queries.

## Usage

```
/semq:search <query>
```

**Arguments:**
- `query` - Natural language description of what to find (required)

## What It Does

1. Finds `.odino` directory by traversing up from current directory
2. Runs `odino query` from the index location
3. Parses and formats results with scores and file paths
4. Optionally reads top results for context
5. Suggests using code-pointer to open relevant files

## Quick Example

```bash
/semq:search validation functions
# Output:
# Searching in: /home/user/project
# Score: 0.87 | Path: src/utils/validation.js
# Score: 0.81 | Path: src/middleware/validate.js
# Score: 0.74 | Path: src/schemas/user.js
```

## Examples

**Find error handling (conceptual):**
```
User: /semq:search error handling

Claude infers: "error handling exception management try catch validation"

Results:
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ File                            ┃ Score    ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ knowledge/Error Handling.md     │ 0.876    │
│ → "Error handling is the process of..."
│ → Shows: Key Concepts, Best Practices
│
│ middleware/errorHandler.js      │ 0.745    │
│ → Shows: Global error handler implementation
└─────────────────────────────────┴──────────┘

Claude reads top result and summarizes key concepts.
```

**Find database code:**
```
User: /semq:search DB connection code

Claude infers query with Python example:
"database connection pooling setup
import mysql.connector
pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name='mypool',
    pool_size=5,
    host='localhost'
)
connection = pool.get_connection()"

Results:
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ File                            ┃ Score    ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ src/db/connection.js            │ 0.924    │
│ → const pool = mysql.createPool({...})
│ → Shows: Connection pooling config with env vars
│ → Includes: Error handling and testing
└─────────────────────────────────┴──────────┘

Claude shows code snippet and explains pooling strategy.
```

**Find algorithms:**
```
User: /semq:search BFS algorithm Python

Claude infers query with code:
"breadth first search BFS graph traversal
def bfs(graph, start):
    visited = set()
    queue = [start]
    while queue:
        node = queue.pop(0)
        if node not in visited:
            visited.add(node)
            queue.extend(graph[node])"

Results:
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ File                            ┃ Score    ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ knowledge/Search Algorithms.md  │ 0.891    │
│ → Types: Uninformed (BFS, DFS) vs Informed (A*, Greedy)
│ → When to use each algorithm
│ → Includes mermaid diagram
└─────────────────────────────────┴──────────┘

Claude reads note and explains algorithm categories.
```

## Implementation

Use the directory traversal helper to find the index, then run the search:

```bash
# Helper function to find .odino directory
find_odino_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.odino" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get query from arguments
QUERY="$*"

if [[ -z "$QUERY" ]]; then
    echo "Error: Query required"
    echo "Usage: /semq:search <query>"
    exit 1
fi

# Find index and search
if ODINO_ROOT=$(find_odino_root); then
    echo "Searching in: $ODINO_ROOT"
    echo ""

    # Run search
    RESULTS=$(cd "$ODINO_ROOT" && odino query -q "$QUERY" 2>&1)

    if [[ $? -eq 0 ]]; then
        echo "$RESULTS"
        echo ""
        echo "💡 Tip: Use code-pointer to open files at specific lines"
    else
        echo "Search failed:"
        echo "$RESULTS"
    fi
else
    echo "No semantic search index found in current path."
    echo ""
    echo "To create an index, run:"
    echo "  /semq:index"
    echo ""
    echo "This will index the current directory for semantic search."
fi
```

## Output Format

Results are shown with similarity scores and file paths:

```
Searching in: /home/user/project

Score: 0.89 | Path: src/auth/middleware.js
Score: 0.82 | Path: src/auth/jwt.js
Score: 0.75 | Path: src/middleware/passport.js

💡 Tip: Use code-pointer to open files at specific lines
```

## Score Interpretation

- **0.85-1.0**: Highly relevant, definitely check this
- **0.70-0.84**: Likely relevant, worth reviewing
- **0.60-0.69**: Possibly relevant, may contain related concepts
- **<0.60**: Weakly related, probably not useful

## When to Use

Use `/semq:search` when:
- You know the directory is indexed
- You want to find code by describing what it does
- You're exploring an unfamiliar codebase
- Grep/glob aren't working (too literal)

Use `/semq:here` instead when:
- You're in a subdirectory and want automatic traversal
- You want to see where the index was found

## Related Commands

- `/semq:here <query>` - Search with directory info
- `/semq:status` - Check if directory is indexed
- `/semq:index` - Create a new index

## Tips

1. **Be conceptual** - Describe what the code does, not exact names
2. **Use natural language** - "authentication logic" not "auth"
3. **Check top 3-5 results** - Sometimes #3 is the best match
4. **Combine with grep** - Use semantic search to find area, grep for specifics
5. **Read files** - Use Read tool on top results for context
