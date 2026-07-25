#!/bin/bash
# List all neovim instances.

set -euo pipefail

if ! command -v nvr &>/dev/null; then
    echo "Error: nvr not found"
    echo "Install with: pip install neovim-remote"
    exit 1
fi

mapfile -t SOCKETS < <(nvr --serverlist 2>/dev/null | sort -u || true)

if [[ ${#SOCKETS[@]} -eq 0 ]]; then
    echo "No neovim instances found"
    exit 0
fi

echo "Active neovim instances:"
echo ""

for socket in "${SOCKETS[@]}"; do
    CWD=$(timeout 2 nvr --servername "$socket" --remote-expr 'getcwd()' 2>&1) || continue
    # Skip stale/broken sockets.
    [[ -z "$CWD" || "$CWD" == *"No valid"* || "$CWD" == *"[!]"* || "$CWD" == *"failed to attach"* ]] && continue
    PID=$(timeout 2 nvr --servername "$socket" --remote-expr 'getpid()' 2>&1 || echo "Unknown")

    echo "[$CWD]"
    echo "  Socket: $socket"
    echo "  PID: $PID"
    echo ""
done
