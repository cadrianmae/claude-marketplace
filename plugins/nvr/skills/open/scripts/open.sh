#!/bin/bash
# Open file at line in discovered nvim instance

set -euo pipefail

FILE="${1:-}"
LINE="${2:-1}"

if [[ -z "$FILE" ]]; then
  echo "Error: File argument required"
  echo "Usage: open.sh <file> [line]"
  exit 1
fi

# Get plugin root (grandparent of grandparent of this script)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Discover socket
SOCKET=$("$PLUGIN_DIR/scripts/nvr-discover" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  # Socket discovery failed - show error
  echo "$SOCKET"
  exit 1
fi

# Open file at line
if nvr --servername "$SOCKET" --remote +"$LINE" "$FILE" 2>/dev/null; then
  echo "✓ Opened $FILE:$LINE in neovim (socket: $SOCKET)"
  exit 0
else
  echo "✗ Failed to open $FILE in neovim"
  echo "Socket: $SOCKET"
  echo "File: $FILE"
  echo "Line: $LINE"
  exit 1
fi
