#!/bin/bash
# List all neovim instances

set -euo pipefail

if ! command -v nvr &>/dev/null; then
  echo "Error: nvr not found"
  echo "Install with: pip install neovim-remote"
  exit 1
fi

mapfile -t SOCKETS < <(nvr --serverlist 2>/dev/null || true)

if [[ ${#SOCKETS[@]} -eq 0 ]]; then
  echo "No neovim instances found"
  exit 0
fi

echo "Active neovim instances:"
echo ""

for socket in "${SOCKETS[@]}"; do
  CWD=$(nvr --servername "$socket" --remote-expr 'getcwd()' 2>/dev/null || echo "Unknown")
  PID=$(nvr --servername "$socket" --remote-expr 'getpid()' 2>/dev/null || echo "Unknown")

  echo "[$CWD]"
  echo "  Socket: $socket"
  echo "  PID: $PID"
  echo ""
done
