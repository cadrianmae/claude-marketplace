#!/bin/bash
# Add scheduled notification helper script.
#
# Two ways to specify timing:
#   --cron "MIN HOUR DOM MONTH DOW"   (preferred, crontab(5) syntax)
#   --time HH:MM --days <days>        (legacy)
#
# Two ways to specify the notification text:
#   <message>     (positional, static string)
#   --command "<shell command>"  (executed; stdout becomes the text)
#
# Other flags:
#   --id <id>          explicit id (otherwise slugified from message)
#   --catchup <bool>   true (default) or false; controls anacron-style catchup
#   global             write to ~/.claude/schedules.json instead of project

set -euo pipefail

MESSAGE=""
COMMAND=""
TIME=""
DAYS=""
CRON=""
CATCHUP="true"
SCOPE="project"
ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --time)    TIME="$2";    shift 2 ;;
    --days)    DAYS="$2";    shift 2 ;;
    --cron)    CRON="$2";    shift 2 ;;
    --command) COMMAND="$2"; shift 2 ;;
    --catchup) CATCHUP="$2"; shift 2 ;;
    --id)      ID="$2";      shift 2 ;;
    global)    SCOPE="global"; shift ;;
    *)
      [[ -z "$MESSAGE" ]] && MESSAGE="$1"
      shift
      ;;
  esac
done

if [[ -n "$MESSAGE" && -n "$COMMAND" ]]; then
  echo "[ERROR] Provide either a positional message OR --command, not both"
  exit 1
fi
if [[ -z "$MESSAGE" && -z "$COMMAND" ]]; then
  echo "[ERROR] Message or --command is required"
  exit 1
fi

if [[ -n "$CRON" && ( -n "$TIME" || -n "$DAYS" ) ]]; then
  echo "[ERROR] Use --cron OR --time/--days, not both"
  exit 1
fi
if [[ -z "$CRON" && ( -z "$TIME" || -z "$DAYS" ) ]]; then
  echo "[ERROR] Provide --cron or both --time and --days"
  exit 1
fi

if [[ "$CATCHUP" != "true" && "$CATCHUP" != "false" ]]; then
  echo "[ERROR] --catchup must be 'true' or 'false'"
  exit 1
fi

# Validate cron via the matcher (parse-only check)
if [[ -n "$CRON" ]]; then
  if ! python3 "$(dirname "$0")/cron-match.py" "$CRON" 0 >/dev/null 2>&1; then
    echo "[ERROR] Invalid cron expression: $CRON"
    python3 "$(dirname "$0")/cron-match.py" "$CRON" 0 || true
    exit 1
  fi
fi

if [[ -n "$TIME" ]]; then
  if [[ ! "$TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "[ERROR] Invalid time format: $TIME (expected HH:MM 24-hour)"
    exit 1
  fi
fi

expand_days() {
  case "$1" in
    weekdays) echo "Mon,Tue,Wed,Thu,Fri" ;;
    weekends) echo "Sat,Sun" ;;
    daily)    echo "*" ;;
    *)        echo "$1" ;;
  esac
}

generate_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' \
    | sed 's/^-//' | sed 's/-$//'
}

if [[ -z "$ID" ]]; then
  if [[ -n "$MESSAGE" ]]; then
    ID=$(generate_id "$MESSAGE")
  else
    ID=$(generate_id "$COMMAND")
  fi
fi

DAYS_JSON="null"
if [[ -n "$DAYS" ]]; then
  DAYS=$(expand_days "$DAYS")
  if [[ "$DAYS" == "*" ]]; then
    DAYS_JSON='["*"]'
  else
    DAYS_JSON=$(echo "$DAYS" | jq -R 'split(",") | map(select(length > 0))')
  fi
fi

if [[ "$SCOPE" == "global" ]]; then
  TARGET_FILE="$HOME/.claude/schedules.json"
  mkdir -p "$(dirname "$TARGET_FILE")"
  [[ -f "$TARGET_FILE" ]] || echo '[]' > "$TARGET_FILE"
else
  [[ -d ".claude" ]] || mkdir -p .claude
  TARGET_FILE=".claude/schedules.json"
  [[ -f "$TARGET_FILE" ]] || echo '{"mode":"add","schedules":[]}' > "$TARGET_FILE"
fi

NEW_SCHEDULE=$(jq -n \
  --arg id "$ID" \
  --arg cron "$CRON" \
  --arg time "$TIME" \
  --argjson days "$DAYS_JSON" \
  --arg message "$MESSAGE" \
  --arg command "$COMMAND" \
  --argjson catchup "$CATCHUP" \
  '{id: $id, enabled: true, catchup: $catchup}
   + (if $cron != "" then {cron: $cron} else {time: $time, days: $days} end)
   + (if $command != "" then {command: $command} else {message: $message} end)')

TMP_FILE="${TARGET_FILE}.tmp"
if [[ "$SCOPE" == "global" ]]; then
  jq --argjson new "$NEW_SCHEDULE" '. += [$new]' "$TARGET_FILE" > "$TMP_FILE"
else
  jq --argjson new "$NEW_SCHEDULE" '.schedules += [$new]' "$TARGET_FILE" > "$TMP_FILE"
fi
mv "$TMP_FILE" "$TARGET_FILE"

if [[ -n "$CRON" ]]; then
  echo "[OK] Added schedule: $ID (cron: $CRON, catchup: $CATCHUP, scope: $SCOPE)"
else
  echo "[OK] Added schedule: $ID ($TIME on $DAYS, catchup: $CATCHUP, scope: $SCOPE)"
fi
