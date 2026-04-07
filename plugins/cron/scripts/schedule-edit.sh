#!/bin/bash
# Edit fields of an existing schedule in place.
#
# Usage:
#   schedule-edit.sh <id> [global|project] [flags...]
#
# Flags (any combination, only listed fields are touched):
#   --cron "EXPR"          replace cron expression (clears time/days)
#   --time HH:MM           replace legacy time (clears cron)
#   --days DAYS            replace legacy days  (clears cron)
#   --message "TEXT"       replace static text  (clears command)
#   --command "CMD"        replace shell command (clears message)
#   --catchup true|false   replace catchup mode

set -euo pipefail

ID=""
SCOPE="project"
CRON=""
TIME=""
DAYS=""
MESSAGE=""
COMMAND=""
CATCHUP=""
HAS_MESSAGE=false
HAS_COMMAND=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --cron)    CRON="$2"; shift 2 ;;
    --time)    TIME="$2"; shift 2 ;;
    --days)    DAYS="$2"; shift 2 ;;
    --message) MESSAGE="$2"; HAS_MESSAGE=true; shift 2 ;;
    --command) COMMAND="$2"; HAS_COMMAND=true; shift 2 ;;
    --catchup) CATCHUP="$2"; shift 2 ;;
    global)    SCOPE="global"; shift ;;
    project)   SCOPE="project"; shift ;;
    *)
      [[ -z "$ID" ]] && ID="$1"
      shift
      ;;
  esac
done

if [[ -z "$ID" ]]; then
  echo "[ERROR] schedule id is required"
  exit 1
fi

# Validate mutually exclusive groups
if [[ -n "$CRON" && ( -n "$TIME" || -n "$DAYS" ) ]]; then
  echo "[ERROR] --cron and --time/--days are mutually exclusive"
  exit 1
fi
if $HAS_MESSAGE && $HAS_COMMAND; then
  echo "[ERROR] --message and --command are mutually exclusive"
  exit 1
fi
if [[ -n "$CATCHUP" && "$CATCHUP" != "true" && "$CATCHUP" != "false" ]]; then
  echo "[ERROR] --catchup must be 'true' or 'false'"
  exit 1
fi

# Validate cron via the matcher
if [[ -n "$CRON" ]]; then
  if ! python3 "$(dirname "$0")/cron-match.py" "$CRON" 0 >/dev/null 2>&1; then
    echo "[ERROR] Invalid cron expression: $CRON"
    python3 "$(dirname "$0")/cron-match.py" "$CRON" 0 || true
    exit 1
  fi
fi

if [[ -n "$TIME" && ! "$TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  echo "[ERROR] Invalid time format: $TIME (expected HH:MM 24-hour)"
  exit 1
fi

# Expand day keywords
if [[ -n "$DAYS" ]]; then
  case "$DAYS" in
    weekdays) DAYS="Mon,Tue,Wed,Thu,Fri" ;;
    weekends) DAYS="Sat,Sun" ;;
    daily)    DAYS="*" ;;
  esac
fi

DAYS_JSON="null"
if [[ -n "$DAYS" ]]; then
  if [[ "$DAYS" == "*" ]]; then
    DAYS_JSON='["*"]'
  else
    DAYS_JSON=$(echo "$DAYS" | jq -R 'split(",") | map(select(length > 0))')
  fi
fi

# Locate target file
if [[ "$SCOPE" == "global" ]]; then
  TARGET_FILE="$HOME/.claude/schedules.json"
else
  TARGET_FILE=".claude/schedules.json"
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "[ERROR] schedules file not found: $TARGET_FILE"
  exit 1
fi

# Find the schedule index (handles both flat-array global and {schedules:[]} project)
INDEX=$(jq --arg id "$ID" '
  if type == "object" and has("schedules") then .schedules else . end
  | to_entries | map(select(.value.id == $id)) | .[0].key // -1
' "$TARGET_FILE")

if [[ "$INDEX" == "-1" || "$INDEX" == "null" ]]; then
  echo "[ERROR] Schedule not found: $ID (scope: $SCOPE)"
  exit 1
fi

# Apply update via jq
TMP_FILE="${TARGET_FILE}.tmp"
jq \
  --argjson idx "$INDEX" \
  --arg cron "$CRON" \
  --arg time "$TIME" \
  --argjson days "$DAYS_JSON" \
  --arg message "$MESSAGE" \
  --argjson has_message "$HAS_MESSAGE" \
  --arg command "$COMMAND" \
  --argjson has_command "$HAS_COMMAND" \
  --arg catchup "$CATCHUP" \
  '
  def upd:
    (if $cron != "" then . + {cron: $cron} | del(.time) | del(.days) else . end)
    | (if $time != "" then . + {time: $time} | del(.cron) else . end)
    | (if $days != null then . + {days: $days} | del(.cron) else . end)
    | (if $has_message then . + {message: $message} | del(.command) else . end)
    | (if $has_command then . + {command: $command} | del(.message) else . end)
    | (if $catchup != "" then . + {catchup: ($catchup == "true")} else . end);
  if type == "object" and has("schedules") then .schedules[$idx] |= upd
  else .[$idx] |= upd
  end
  ' "$TARGET_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TARGET_FILE"
echo "[OK] Edited schedule: $ID (scope: $SCOPE)"
