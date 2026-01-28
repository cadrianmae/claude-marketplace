#!/bin/bash
# Discover workspace context

set -euo pipefail

# Get plugin root (grandparent of grandparent of this script)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

CWD=$(pwd)

echo "Workspace Context"
echo "================="
echo ""
echo "Working Directory: $CWD"

# Git info
if GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  GIT_BRANCH=$(git branch --show-current 2>/dev/null)
  echo "Git Repository: $GIT_ROOT"
  echo "Git Branch: $GIT_BRANCH"
else
  echo "Git Repository: Not in git repo"
fi

echo ""

# Neovim instance
SOCKET=$("$PLUGIN_DIR/scripts/nvr-discover" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  NVIM_CWD=$(nvr --servername "$SOCKET" --remote-expr 'getcwd()' 2>/dev/null || echo "Unknown")
  NVIM_PID=$(nvr --servername "$SOCKET" --remote-expr 'getpid()' 2>/dev/null || echo "Unknown")

  echo "Neovim Instance: Active"
  echo "  Socket: $SOCKET"
  echo "  PID: $NVIM_PID"
  echo "  Working Directory: $NVIM_CWD"
else
  echo "Neovim Instance: No active instance for this directory"
fi
