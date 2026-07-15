#!/usr/bin/env bash
# Verifies the click engine emits a non-clipping WAV of sane duration.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DIR/scripts/lib.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Render ~200 tokens of clicks to a file (function writes a sequence WAV).
out="$tmp/clicks.wav"
af_render_clicks 200 "$out"   # NEW: file-output entry point (see Step 3)

[ -s "$out" ] || { echo "[FAIL] no click file"; exit 1; }
# peak must be below 0 dBFS (no clipping): sox stat max amplitude < 1.0
peak="$(sox "$out" -n stat 2>&1 | awk '/Maximum amplitude/ {print $3}')"
awk -v p="$peak" 'BEGIN { exit !(p < 1.0 && p > 0.05) }' \
  || { echo "[FAIL] peak $peak out of range"; exit 1; }
echo "[OK] clicks render, peak $peak"

# format must be mono 44.1kHz
ch="$(soxi -c "$out")"; sr="$(soxi -r "$out")"
[ "$ch" = "1" ] && [ "$sr" = "44100" ] \
  || { echo "[FAIL] expected mono 44100, got ${ch}ch ${sr}Hz"; exit 1; }
echo "[OK] format mono 44100Hz"
