#!/usr/bin/env bash
# Zoom.sh — screen magnifier via Hyprland's built-in zoom (cursor zoom_factor)
# --in increments, --out decrements, clamps 1.0..10.0
STATE_FILE="/tmp/hypr-zoom-factor"

get_current() {
  hyprctl getoption cursor:zoom_factor -j 2>/dev/null | jq -r '.set // .float // 1.0' 2>/dev/null || echo 1.0
}

cur=$(get_current)
cur=${cur:-1.0}

case "${1:-}" in
  --in)  next=$(python3 -c "print(min(10.0, round($cur + 0.5, 2)))") ;;
  --out) next=$(python3 -c "print(max(1.0, round($cur - 0.5, 2)))") ;;
  *)     next="1.0" ;;
esac

hyprctl eval "hl.config({ cursor = { zoom_factor = $next } })" >/dev/null 2>&1 \
  || hyprctl keyword cursor:zoom_factor "$next" >/dev/null 2>&1

echo "$next" > "$STATE_FILE"
# only toast when fully zoomed out (avoid spam while scrolling)
if (( $(python3 -c "print(1 if $next <= 1.001 else 0)") )); then
  notify-send -t 1000 "Zoom" "reset"
fi
