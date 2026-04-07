#!/bin/bash
# List scheduled notifications helper script

set -euo pipefail

SCOPE="${1:-all}"

format_schedule() {
  local schedule="$1"
  local scope_label="$2"

  local id cron time days message command enabled catchup
  id=$(echo "$schedule" | jq -r '.id')
  cron=$(echo "$schedule" | jq -r '.cron // empty')
  time=$(echo "$schedule" | jq -r '.time // empty')
  days=$(echo "$schedule" | jq -r '(.days // []) | join(", ")')
  message=$(echo "$schedule" | jq -r '.message // empty')
  command=$(echo "$schedule" | jq -r '.command // empty')
  enabled=$(echo "$schedule" | jq -r '.enabled')
  catchup=$(echo "$schedule" | jq -r '.catchup // true')

  local status="[ENABLED]"
  [[ "$enabled" != "true" ]] && status="[DISABLED]"

  if [[ -n "$cron" ]]; then
    echo "[$scope_label] $status $id - cron: $cron (catchup: $catchup)"
  else
    echo "[$scope_label] $status $id - $time on $days (catchup: $catchup)"
  fi
  if [[ -n "$command" ]]; then
    echo "  Command: $command"
  else
    echo "  Message: $message"
  fi
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
