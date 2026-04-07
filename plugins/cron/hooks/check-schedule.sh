#!/bin/bash
# Check Schedule Hook - UserPromptSubmit event handler
#
# Evaluates each schedule's cron expression against the current time and
# fires notifications using anacron-style catch-up with per-tick dedup.
#
# Schedule fields:
#   id        - unique identifier
#   cron      - 5-field crontab(5) expression (preferred)
#   time/days - legacy: HH:MM + ["Mon","Tue",...] or ["*"]
#   message   - static notification text
#   command   - shell command, stdout becomes the notification text
#               (mutually exclusive with message)
#   catchup   - true (default): fire missed ticks on next prompt
#               false: only fire if tick is in the current minute
#   enabled   - boolean

set -euo pipefail

GLOBAL_SCHEDULES="$HOME/.claude/schedules.json"
PROJECT_SCHEDULES=".claude/schedules.json"
GLOBAL_STATE="$HOME/.claude/.schedule-state.json"
PROJECT_STATE=".claude/.schedule-state.json"
CRON_MATCH="$(dirname "$0")/../scripts/cron-match.py"

# Dependency checks
for dep in jq python3; do
  if ! command -v "$dep" &>/dev/null; then
    jq -n --arg ctx "[ERROR] cron plugin: $dep is required but not installed" \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
    exit 2
  fi
done

validate_json() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  jq empty "$file" 2>/dev/null || return 2
}

init_state() {
  local state_file="$1"
  if [[ ! -f "$state_file" ]]; then
    mkdir -p "$(dirname "$state_file")"
    echo "{}" > "$state_file"
  fi
}

get_last_shown() {
  jq -r --arg id "$2" '.[$id] // 0' "$1"
}

update_state() {
  local state_file="$1" id="$2" ts="$3"
  local tmp="${state_file}.tmp"
  jq --arg id "$id" --arg ts "$ts" '.[$id] = ($ts | tonumber)' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

# Convert legacy time+days schedule into a cron expression.
# days uses Mon-Sun abbreviations or ["*"]; cron dow: Sun=0..Sat=6.
legacy_to_cron() {
  local schedule="$1"
  local time days hour minute dow_csv
  time=$(echo "$schedule" | jq -r '.time // empty')
  [[ -z "$time" ]] && { echo ""; return; }
  hour="${time%%:*}"
  minute="${time##*:}"
  # Strip leading zeros to avoid base-8 confusion downstream
  hour=$((10#$hour))
  minute=$((10#$minute))
  days=$(echo "$schedule" | jq -r '.days | @json')
  if echo "$days" | jq -e 'index("*") != null' &>/dev/null; then
    dow_csv="*"
  else
    dow_csv=$(echo "$days" | jq -r '
      map({Sun:0,Mon:1,Tue:2,Wed:3,Thu:4,Fri:5,Sat:6}[.] | tostring) | join(",")
    ')
    [[ -z "$dow_csv" ]] && dow_csv="*"
  fi
  echo "$minute $hour * * $dow_csv"
}

load_schedules() {
  local schedules="[]"
  if validate_json "$GLOBAL_SCHEDULES"; then
    schedules=$(jq -c '.' "$GLOBAL_SCHEDULES")
  fi
  if [[ -d ".claude" ]] || git rev-parse --git-dir &>/dev/null 2>&1; then
    if validate_json "$PROJECT_SCHEDULES"; then
      local mode project_schedules
      mode=$(jq -r '.mode // "add"' "$PROJECT_SCHEDULES")
      project_schedules=$(jq -c '.schedules // []' "$PROJECT_SCHEDULES")
      if [[ "$mode" == "replace" ]]; then
        schedules="$project_schedules"
      else
        schedules=$(echo "$schedules" | jq -c --argjson p "$project_schedules" '. + $p')
      fi
    fi
  fi
  echo "$schedules"
}

# Resolve a schedule's notification text. Echoes the text on stdout.
resolve_text() {
  local schedule="$1"
  local cmd msg
  cmd=$(echo "$schedule" | jq -r '.command // empty')
  if [[ -n "$cmd" ]]; then
    local out err rc=0
    out=$(bash -c "$cmd" 2>/tmp/.cron-cmd-err) || rc=$?
    err=$(cat /tmp/.cron-cmd-err 2>/dev/null || true)
    rm -f /tmp/.cron-cmd-err
    if [[ $rc -ne 0 ]]; then
      echo "[cron error] command exited $rc: ${err:-no stderr}"
    else
      printf '%s' "$out"
    fi
    return
  fi
  msg=$(echo "$schedule" | jq -r '.message // "(no message)"')
  printf '%s' "$msg"
}

main() {
  local current_ts current_minute_floor
  current_ts=$(date '+%s')
  current_minute_floor=$(( current_ts - current_ts % 60 ))

  local schedules
  schedules=$(load_schedules)

  init_state "$GLOBAL_STATE"
  if [[ -d ".claude" ]]; then
    init_state "$PROJECT_STATE"
  fi

  local notifications=""
  local schedule_count
  schedule_count=$(echo "$schedules" | jq 'length')

  for i in $(seq 0 $((schedule_count - 1))); do
    [[ $i -lt 0 ]] && continue
    local schedule enabled schedule_id cron_expr catchup
    schedule=$(echo "$schedules" | jq -c ".[$i]")
    # jq's // also triggers on false, so test explicitly for != false
    enabled=$(echo "$schedule" | jq -r 'if .enabled == false then "false" else "true" end')
    [[ "$enabled" != "true" ]] && continue

    schedule_id=$(echo "$schedule" | jq -r '.id')
    cron_expr=$(echo "$schedule" | jq -r '.cron // empty')
    if [[ -z "$cron_expr" ]]; then
      cron_expr=$(legacy_to_cron "$schedule")
    fi
    [[ -z "$cron_expr" ]] && continue

    # Compute most recent matching tick
    local tick
    tick=$(python3 "$CRON_MATCH" "$cron_expr" "$current_ts" 2>/dev/null || true)
    [[ -z "$tick" ]] && continue

    # Catchup toggle (default true)
    catchup=$(echo "$schedule" | jq -r '.catchup // true')
    if [[ "$catchup" != "true" ]]; then
      # Strict mode: tick must be in the current minute
      [[ "$tick" -ne "$current_minute_floor" ]] && continue
    fi

    # Pick state file (project schedule -> project state)
    local state_file="$GLOBAL_STATE"
    if [[ -d ".claude" ]] && validate_json "$PROJECT_SCHEDULES"; then
      if jq -e --arg id "$schedule_id" '.schedules[]? | select(.id == $id)' "$PROJECT_SCHEDULES" &>/dev/null; then
        state_file="$PROJECT_STATE"
      fi
    fi

    # Dedup: fire only if this tick is newer than last fired
    local last_shown
    last_shown=$(get_last_shown "$state_file" "$schedule_id")
    if [[ "$tick" -gt "$last_shown" ]]; then
      local text
      text=$(resolve_text "$schedule")
      notifications="${notifications}${text}"$'\n'
      update_state "$state_file" "$schedule_id" "$tick"
    fi
  done

  if [[ -n "$notifications" ]]; then
    # Strip trailing newline
    notifications="${notifications%$'\n'}"
    jq -n --arg msg "$notifications" \
      '{systemMessage:$msg,hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$msg}}'
  fi
  exit 0
}

main "$@"
