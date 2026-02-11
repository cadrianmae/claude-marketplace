#!/bin/bash
# Configuration and state checking functions

# Check if tracking is enabled for current project
is_tracking_enabled() {
    [ "$(get_config_value "TRACKING_ENABLED" "false")" = "true" ]
}

# Read configuration value from .claude/.ref-config
get_config_value() {
    local key="$1"
    local default="$2"
    local value=""

    if [ -f .claude/.ref-config ]; then
        value=$(grep "^${key}=" .claude/.ref-config 2>/dev/null | cut -d= -f2-)
    fi

    echo "${value:-$default}"
}
