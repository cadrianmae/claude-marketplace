#!/bin/bash
# Modify scheduled notifications helper script (disable/enable/remove)

set -euo pipefail

OPERATION="$1"
SCHEDULE_ID="$2"
SCOPE="${3:-project}"

if [[ "$SCOPE" == "global" ]]; then
  TARGET_FILE="$HOME/.claude/schedules.json"
else
  TARGET_FILE=".claude/schedules.json"
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "[ERROR] No schedules file found at $TARGET_FILE"
  exit 1
fi

# Find schedule index
find_schedule_index() {
  local file="$1"
  local id="$2"

  if [[ "$SCOPE" == "global" ]]; then
    jq --arg id "$id" 'to_entries | map(select(.value.id == $id)) | .[0].key // -1' "$file"
  else
    jq --arg id "$id" '.schedules | to_entries | map(select(.value.id == $id)) | .[0].key // -1' "$file"
  fi
}

INDEX=$(find_schedule_index "$TARGET_FILE" "$SCHEDULE_ID")

if [[ "$INDEX" == "-1" ]] || [[ "$INDEX" == "null" ]]; then
  echo "[ERROR] Schedule not found: $SCHEDULE_ID (scope: $SCOPE)"
  exit 1
fi

TMP_FILE="${TARGET_FILE}.tmp"

case "$OPERATION" in
  disable)
    if [[ "$SCOPE" == "global" ]]; then
      jq --argjson idx "$INDEX" '.[$idx].enabled = false' "$TARGET_FILE" > "$TMP_FILE"
    else
      jq --argjson idx "$INDEX" '.schedules[$idx].enabled = false' "$TARGET_FILE" > "$TMP_FILE"
    fi
    mv "$TMP_FILE" "$TARGET_FILE"
    echo "[OK] Disabled schedule: $SCHEDULE_ID (scope: $SCOPE)"
    ;;

  enable)
    if [[ "$SCOPE" == "global" ]]; then
      jq --argjson idx "$INDEX" '.[$idx].enabled = true' "$TARGET_FILE" > "$TMP_FILE"
    else
      jq --argjson idx "$INDEX" '.schedules[$idx].enabled = true' "$TARGET_FILE" > "$TMP_FILE"
    fi
    mv "$TMP_FILE" "$TARGET_FILE"
    echo "[OK] Enabled schedule: $SCHEDULE_ID (scope: $SCOPE)"
    ;;

  remove)
    if [[ "$SCOPE" == "global" ]]; then
      jq --argjson idx "$INDEX" 'del(.[$idx])' "$TARGET_FILE" > "$TMP_FILE"
    else
      jq --argjson idx "$INDEX" 'del(.schedules[$idx])' "$TARGET_FILE" > "$TMP_FILE"
    fi
    mv "$TMP_FILE" "$TARGET_FILE"
    echo "[OK] Removed schedule: $SCHEDULE_ID (scope: $SCOPE)"
    ;;

  *)
    echo "[ERROR] Invalid operation: $OPERATION. Use: disable, enable, or remove"
    exit 1
    ;;
esac
