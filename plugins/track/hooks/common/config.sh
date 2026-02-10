#!/bin/bash
# Configuration and state checking functions

# Check if tracking is enabled for current project
is_tracking_enabled() {
    [ -f .claude/.ref-autotrack ]
}

# Read configuration value from .claude/.ref-config
get_config_value() {
    local key="$1"
    local default="$2"

    if [ -f .claude/.ref-config ]; then
        grep "^${key}=" .claude/.ref-config 2>/dev/null | cut -d= -f2
    else
        echo "$default"
    fi
}
