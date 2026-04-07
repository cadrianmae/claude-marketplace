#!/bin/bash
# Common utilities loader for track plugin hooks
# Sources all modular utility files

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all common modules
source "$SCRIPT_DIR/common/config.sh"
source "$SCRIPT_DIR/common/files.sh"
source "$SCRIPT_DIR/common/utils.sh"
source "$SCRIPT_DIR/common/llm.sh"
