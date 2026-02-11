#!/bin/bash
# Add scheduled notification helper script

set -euo pipefail

# Parse arguments
MESSAGE=""
TIME=""
DAYS=""
SCOPE="project"
ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --time)
      TIME="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --id)
      ID="$2"
      shift 2
      ;;
    global)
      SCOPE="global"
      shift
      ;;
    *)
      if [[ -z "$MESSAGE" ]]; then
        MESSAGE="$1"
      fi
      shift
      ;;
  esac
done

# Validate time format (HH:MM)
validate_time() {
  local time="$1"
  if [[ ! "$time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "[ERROR] Invalid time format: $time. Expected HH:MM (24-hour)"
    return 1
  fi
}

# Expand special day values
expand_days() {
  local days="$1"
  case "$days" in
    weekdays)
      echo "Mon,Tue,Wed,Thu,Fri"
      ;;
    weekends)
      echo "Sat,Sun"
      ;;
    daily)
      echo "*"
      ;;
    *)
      echo "$days"
      ;;
  esac
}

# Generate ID from message (slugified)
generate_id() {
  local msg="$1"
  echo "$msg" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Validate inputs
if [[ -z "$MESSAGE" ]]; then
  echo "[ERROR] Message is required"
  exit 1
fi

if [[ -z "$TIME" ]]; then
  echo "[ERROR] Time is required (--time HH:MM)"
  exit 1
fi

if [[ -z "$DAYS" ]]; then
  echo "[ERROR] Days are required (--days Mon,Tue,Wed or weekdays/weekends/daily)"
  exit 1
fi

validate_time "$TIME" || exit 1

# Expand days
DAYS=$(expand_days "$DAYS")

# Generate ID if not provided
if [[ -z "$ID" ]]; then
  ID=$(generate_id "$MESSAGE")
fi

# Convert days to JSON array
if [[ "$DAYS" == "*" ]]; then
  DAYS_JSON='["*"]'
else
  DAYS_JSON=$(echo "$DAYS" | jq -R 'split(",") | map(select(length > 0))')
fi

# Determine target file
if [[ "$SCOPE" == "global" ]]; then
  TARGET_FILE="$HOME/.claude/schedules.json"
else
  # Project scope
  if [[ ! -d ".claude" ]]; then
    mkdir -p .claude
  fi
  TARGET_FILE=".claude/schedules.json"

  # Create with mode if doesn't exist
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo '{"mode":"add","schedules":[]}' > "$TARGET_FILE"
  fi
fi

# Create global file if doesn't exist
if [[ "$SCOPE" == "global" ]] && [[ ! -f "$TARGET_FILE" ]]; then
  mkdir -p "$(dirname "$TARGET_FILE")"
  echo '[]' > "$TARGET_FILE"
fi

# Build new schedule object
NEW_SCHEDULE=$(jq -n \
  --arg id "$ID" \
  --arg time "$TIME" \
  --arg message "$MESSAGE" \
  --argjson days "$DAYS_JSON" \
  '{
    id: $id,
    time: $time,
    message: $message,
    days: $days,
    enabled: true
  }')

# Add to appropriate file
if [[ "$SCOPE" == "global" ]]; then
  # Add to global array
  TMP_FILE="${TARGET_FILE}.tmp"
  jq --argjson new "$NEW_SCHEDULE" '. += [$new]' "$TARGET_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$TARGET_FILE"
else
  # Add to project schedules array
  TMP_FILE="${TARGET_FILE}.tmp"
  jq --argjson new "$NEW_SCHEDULE" '.schedules += [$new]' "$TARGET_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$TARGET_FILE"
fi

echo "[OK] Added schedule: $ID ($MESSAGE) at $TIME on ${DAYS} (scope: $SCOPE)"
