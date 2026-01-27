[![Version](https://img.shields.io/badge/version-1.1.1-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# Semantic Search Plugin

Natural language semantic search for codebases and notes using [odino](https://github.com/andthattoo/odino) CLI with BGE embeddings.

## Features

- **Natural language search**: Find code by describing what it does, not exact text matching
- **Automatic directory traversal**: Works from any subdirectory (like git)
- **Auto-invoked skill**: Claude automatically uses semantic search for conceptual queries
- **Slash commands**: Explicit commands for indexing and searching
- **Lightweight**: Uses BAAI/bge-small-en-v1.5 model (~133MB, 33M parameters)
- **Fully local**: All processing happens on your machine

## Requirements

- **odino CLI**: Install via `pipx install odino`
- **BGE model**: Auto-downloaded on first use (~133MB)
- **Python 3.8+**: Required by odino
- **GPU recommended**: Much faster indexing (but CPU works)

## Commands

### `/semq:search <query>`
Search indexed codebase using natural language.

```bash
/semq:search "authentication logic"
/semq:search "database connection handling"
/semq:search "error handling patterns"
```

### `/semq:here <query>`
Search from current directory upward to find indexed codebase.

```bash
# Works from any subdirectory
cd src/utils/
/semq:here "validation functions"
```

### `/semq:index [path]`
Index a directory for semantic search.

```bash
/semq:index
/semq:index ~/projects/myapp
```

### `/semq:status [path]`
Show indexing status and statistics.

```bash
/semq:status
```

## Auto-Invoked Skill

Claude automatically uses semantic search when you ask conceptual questions:

- "Where is the authentication logic?"
- "How does the caching system work?"
- "Find code that handles file uploads"
- "Show me error handling patterns"

## How It Works

1. **Indexing**: odino chunks your code/notes and generates embeddings using BGE
2. **Storage**: Embeddings stored locally in `.odino/chroma_db/`
3. **Search**: Natural language queries matched against embeddings
4. **Results**: Relevant files ranked by semantic similarity

## Configuration

The plugin automatically uses the BGE model for efficiency. To customize:

```bash
# Edit .odino/config.json in your project
{
  "model_name": "BAAI/bge-small-en-v1.5",
  "embedding_batch_size": 16
}
```

## Directory Traversal

The plugin includes built-in directory traversal logic (like git), so you can run search commands from any subdirectory of an indexed project.

## Use Cases

- **Code exploration**: "Where is the database schema defined?"
- **Pattern discovery**: "Show me all API endpoint handlers"
- **Concept search**: "Find authentication middleware"
- **Documentation**: "Locate configuration documentation"
- **Notes search**: Semantic search across markdown notes

## Tips

- **Be conceptual**: Describe what the code does, not exact variable names
- **Combine tools**: Use semantic search to find the area, then grep for specifics
- **Reindex periodically**: After major code changes, run `/semq:index` again
- **Use `.odinoignore`**: Exclude build artifacts, dependencies, etc.

## Installation

```bash
# Install via Claude Code marketplace
/plugin install semantic-search@cadrianmae-claude-marketplace
```

## Related Tools

- **code-pointer**: Opens files at specific lines (auto-integrates with search results)
- **grep**: Exact text matching (complements semantic search)
- **glob**: File pattern matching

## Learn More

- [odino GitHub](https://github.com/andthattoo/odino)
- [BGE Model](https://huggingface.co/BAAI/bge-small-en-v1.5)

## License

MIT License - see [LICENSE](./LICENSE) for details.
