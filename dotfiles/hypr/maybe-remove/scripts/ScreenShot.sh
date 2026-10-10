#!/usr/bin/env bash
# ScreenShot.sh — grim/slurp/satty screenshot tool with modes
# --now      full screen → clipboard + file + satty annotate
# --area     select region → clipboard + file
# --swappy   select region → satty editor
# --in5/--in10  delayed full screen
# --active   current window (slurp a window)
set -euo pipefail

SHOT_DIR="$HOME/.config/hypr/screenshots"
TIME="$(date +%Y%m%d_%H%M%S)"
FILE="$SHOT_DIR/screenshot_${TIME}.png"

case "$1" in
  --now)
    grim - | tee "$FILE" | wl-copy
    notify-send -t 2000 "Screenshot" "Full screen → clipboard + $FILE"
    ;;
  --area)
    grim -g "$(slurp)" - | tee "$FILE" | wl-copy
    notify-send -t 2000 "Screenshot" "Area → clipboard + $FILE"
    ;;
  --swappy)
    grim -g "$(slurp)" - | satty --filename - --copy-command wl-copy \
      --output-filename "$SHOT_DIR/satty_${TIME}.png" --initial-tool brush
    ;;
  --in5)  sleep 5;  grim - | tee "$FILE" | wl-copy ;;
  --in10) sleep 10; grim - | tee "$FILE" | wl-copy ;;
  --active)
    # capture the window under the cursor: slurp in window mode
    grim -g "$(slurp -d -f '%x %y %w %h')" - | tee "$FILE" | wl-copy
    ;;
  *)
    echo "usage: ScreenShot.sh --now|--area|--swappy|--in5|--in10|--active" >&2
    exit 1
    ;;
esac
