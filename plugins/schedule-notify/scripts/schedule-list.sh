#!/bin/bash
# List scheduled notifications helper script

set -euo pipefail

SCOPE="${1:-all}"

format_schedule() {
  local schedule="$1"
  local scope_label="$2"

  local id=$(echo "$schedule" | jq -r '.id')
  local time=$(echo "$schedule" | jq -r '.time')
  local message=$(echo "$schedule" | jq -r '.message')
  local days=$(echo "$schedule" | jq -r '.days | join(", ")')
  local enabled=$(echo "$schedule" | jq -r '.enabled')

  local status="[ENABLED]"
  if [[ "$enabled" != "true" ]]; then
    status="[DISABLED]"
  fi

  echo "[$scope_label] $status $id - $time on $days"
  echo "  Message: $message"
}

list_global() {
  local global_file="$HOME/.claude/schedules.json"

  if [[ ! -f "$global_file" ]]; then
    echo "[INFO] No global schedules found"
    return
  fi

  local count=$(jq 'length' "$global_file")
  if [[ "$count" -eq 0 ]]; then
    echo "[INFO] No global schedules found"
    return
  fi

  echo "=== Global Schedules ==="
  for i in $(seq 0 $((count - 1))); do
    local schedule=$(jq -c ".[$i]" "$global_file")
    format_schedule "$schedule" "GLOBAL"
    echo
  done
}

list_project() {
  local project_file=".claude/schedules.json"

  if [[ ! -f "$project_file" ]]; then
    echo "[INFO] No project schedules found"
    return
  fi

  local mode=$(jq -r '.mode // "add"' "$project_file")
  local count=$(jq '.schedules | length' "$project_file")

  if [[ "$count" -eq 0 ]]; then
    echo "[INFO] No project schedules found"
    return
  fi

  echo "=== Project Schedules (mode: $mode) ==="
  for i in $(seq 0 $((count - 1))); do
    local schedule=$(jq -c ".schedules[$i]" "$project_file")
    format_schedule "$schedule" "PROJECT"
    echo
  done
}

# Main
case "$SCOPE" in
  global)
    list_global
    ;;
  project)
    list_project
    ;;
  all)
    list_global
    echo
    list_project
    ;;
  *)
    echo "[ERROR] Invalid scope: $SCOPE. Use: global, project, or all"
    exit 1
    ;;
esac
