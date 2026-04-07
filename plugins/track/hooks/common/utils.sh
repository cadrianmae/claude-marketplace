#!/bin/bash
# Utility functions

# Get current timestamp in ISO 8601 format
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Truncate text to max length
truncate_text() {
    local text="$1"
    local max_length="${2:-200}"

    if [ "${#text}" -gt "$max_length" ]; then
        echo "${text:0:$max_length}..."
    else
        echo "$text"
    fi
}

# Extract field from LLM output
extract_field() {
    local field_name="$1"
    local llm_output="$2"
    echo "$llm_output" | grep "^${field_name}:" | cut -d: -f2- | xargs
}
