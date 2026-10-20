#!/usr/bin/env bash
# SwitchLayout.sh — cycle Hyprland layouts (dwindle → master → scrolling)
CURRENT=$(hyprctl getoption general:layout -j | jq -r '.str' 2>/dev/null || echo "dwindle")
case "$CURRENT" in
  dwindle)    NEXT="master" ;;
  master)     NEXT="scrolling" ;;
  *)          NEXT="dwindle" ;;
esac
hyprctl eval "hl.config({ general = { layout = \"$NEXT\" } })" >/dev/null 2>&1 \
  || hyprctl keyword general:layout "$NEXT" >/dev/null 2>&1
notify-send -t 1500 "Layout" "$CURRENT → $NEXT"
