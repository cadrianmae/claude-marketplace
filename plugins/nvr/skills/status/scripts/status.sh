#!/bin/bash
# Show status of nvim instance for current directory

set -euo pipefail

# Get plugin root (grandparent of grandparent of this script)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Discover socket
SOCKET=$("$PLUGIN_DIR/scripts/nvr-discover" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "No neovim instance found for current directory"
  echo ""
  echo "$SOCKET"
  exit 1
fi

# Query nvim information
PID=$(nvr --servername "$SOCKET" --remote-expr 'getpid()' 2>/dev/null)
CWD=$(nvr --servername "$SOCKET" --remote-expr 'getcwd()' 2>/dev/null)
BUFFERS=$(nvr --servername "$SOCKET" --remote-expr 'len(getbufinfo({"buflisted": 1}))' 2>/dev/null)

echo "✓ Neovim instance found"
echo ""
echo "Socket: $SOCKET"
echo "Process ID: $PID"
echo "Working Directory: $CWD"
echo "Open Buffers: $BUFFERS"
