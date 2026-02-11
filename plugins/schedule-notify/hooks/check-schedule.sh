#!/bin/bash
# Check Schedule Hook - UserPromptSubmit event handler
# Checks for scheduled notifications and displays pending reminders

set -euo pipefail

# Configuration
GLOBAL_SCHEDULES="$HOME/.claude/schedules.json"
PROJECT_SCHEDULES=".claude/schedules.json"
GLOBAL_STATE="$HOME/.claude/.schedule-state.json"
PROJECT_STATE=".claude/.schedule-state.json"
DEDUP_WINDOW=60  # seconds

# Dependency check
if ! command -v jq &>/dev/null; then
  jq -n \
    --arg ctx "[ERROR] jq is required but not installed. Install with: sudo dnf install jq" \
    '{
      additionalContext: $ctx,
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit"
      }
    }'
  exit 2
fi

# Validate JSON file
validate_json() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 1  # File doesn't exist
  fi
  if ! jq empty "$file" 2>/dev/null; then
    return 2  # Invalid JSON
  fi
  return 0
}

# Initialize state file if missing
init_state() {
  local state_file="$1"
  if [[ ! -f "$state_file" ]]; then
    mkdir -p "$(dirname "$state_file")"
    echo "{}" > "$state_file"
  fi
}

# Get last shown timestamp for schedule ID
get_last_shown() {
  local state_file="$1"
  local schedule_id="$2"
  jq -r --arg id "$schedule_id" '.[$id] // 0' "$state_file"
}

# Update state with current timestamp
update_state() {
  local state_file="$1"
  local schedule_id="$2"
  local timestamp="$3"

  local tmp_file="${state_file}.tmp"
  jq --arg id "$schedule_id" --arg ts "$timestamp" \
    '.[$id] = ($ts | tonumber)' "$state_file" > "$tmp_file"
  mv "$tmp_file" "$state_file"
}

# Load and merge schedules
load_schedules() {
  local schedules="[]"

  # Load global schedules
  if validate_json "$GLOBAL_SCHEDULES"; then
    schedules=$(jq -c '.' "$GLOBAL_SCHEDULES")
  fi

  # Check if we're in a project (has .claude/ directory or is a git repo)
  if [[ -d ".claude" ]] || git rev-parse --git-dir &>/dev/null 2>&1; then
    if validate_json "$PROJECT_SCHEDULES"; then
      local mode=$(jq -r '.mode // "add"' "$PROJECT_SCHEDULES")
      local project_schedules=$(jq -c '.schedules // []' "$PROJECT_SCHEDULES")

      if [[ "$mode" == "replace" ]]; then
        # Replace global with project schedules
        schedules="$project_schedules"
      else
        # Merge (add) project schedules to global
        # Use stdin to avoid command line length issues
        schedules=$(echo "$schedules" | jq -c --argjson project "$project_schedules" \
          '. + $project')
      fi
    fi
  fi

  echo "$schedules"
}

# Check if schedule matches current time and day
matches_schedule() {
  local schedule="$1"
  local current_time="$2"
  local current_day="$3"

  local enabled=$(echo "$schedule" | jq -r '.enabled')
  local sched_time=$(echo "$schedule" | jq -r '.time')
  local sched_days=$(echo "$schedule" | jq -r '.days | @json')

  # Check enabled
  if [[ "$enabled" != "true" ]]; then
    return 1
  fi

  # Check time match - current time must be >= scheduled time
  if [[ "$current_time" < "$sched_time" ]]; then
    return 1
  fi

  # Check day match
  if echo "$sched_days" | jq -e --arg day "$current_day" 'index($day) != null' &>/dev/null; then
    return 0
  fi

  # Check for wildcard (daily)
  if echo "$sched_days" | jq -e 'index("*") != null' &>/dev/null; then
    return 0
  fi

  return 1
}

# Main logic
main() {
  # Get current time and day
  local current_time=$(date '+%H:%M')
  local current_day=$(date '+%a')
  local current_ts=$(date '+%s')

  # Load schedules
  local schedules=$(load_schedules)

  # Initialize state files
  init_state "$GLOBAL_STATE"
  if [[ -d ".claude" ]]; then
    init_state "$PROJECT_STATE"
  fi

  # Collect notifications
  local notifications=""
  local schedule_count=$(echo "$schedules" | jq 'length')

  for i in $(seq 0 $((schedule_count - 1))); do
    local schedule=$(echo "$schedules" | jq -c ".[$i]")

    if matches_schedule "$schedule" "$current_time" "$current_day"; then
      local schedule_id=$(echo "$schedule" | jq -r '.id')
      local message=$(echo "$schedule" | jq -r '.message')

      # Determine which state file to use
      local state_file="$GLOBAL_STATE"
      if [[ -d ".claude" ]] && validate_json "$PROJECT_SCHEDULES"; then
        # Check if this schedule is from project
        if jq -e --arg id "$schedule_id" '.schedules[] | select(.id == $id)' "$PROJECT_SCHEDULES" &>/dev/null; then
          state_file="$PROJECT_STATE"
        fi
      fi

      # Check deduplication - only show once per day after scheduled time
      local last_shown=$(get_last_shown "$state_file" "$schedule_id")
      local sched_time=$(echo "$schedule" | jq -r '.time')
      local today_scheduled=$(date -d "today $sched_time" +%s)

      # Show if: never shown before OR last shown was before today's scheduled time
      if [[ $last_shown -lt $today_scheduled ]]; then
        # Add to notifications
        notifications="${notifications}${message}\n"

        # Update state
        update_state "$state_file" "$schedule_id" "$current_ts"
      fi
    fi
  done

  # Output notifications if any
  if [[ -n "$notifications" ]]; then
    jq -n \
      --arg msg "$(echo -e "$notifications" | sed 's/\\n$//')" \
      '{
        systemMessage: $msg,
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: $msg
        }
      }'
  fi

  exit 0
}

main "$@"
