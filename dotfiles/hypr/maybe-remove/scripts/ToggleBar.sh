#!/usr/bin/env bash
# ToggleBar.sh — hide/show whichever bar/shell is running (JaKooLit SUPER+CTRL+ALT+B parity,
# extended to all three shells). One keybind, works everywhere:
#   fury-bar  → quickshell ipc bar toggle
#   tide      → quickshell ipc island toggle (auto-hide remains available)
#   waybar    → pkill -SIGUSR1 (waybar's own toggle convention)
set -uo pipefail
FURY_QML="$HOME/.config/quickshell/fury-bar"

if pgrep -f "quickshell -p $FURY_QML" >/dev/null 2>&1; then
  quickshell ipc -p "$FURY_QML" call bar toggle >/dev/null 2>&1
  timeout 2 notify-send -t 1200 "fury-bar" "visibility toggled" 2>/dev/null >/dev/null < /dev/null & disown
elif pgrep -f "quickshell .*tide-island" >/dev/null 2>&1; then
  # tide island: toggle island visibility (island target, keep/auto subfunctions exist)
  quickshell ipc -p "$(readlink -f /run/current-system/sw/share/tide-island 2>/dev/null || echo /run/current-system/sw/share/tide-island)" call island toggle >/dev/null 2>&1 \
    && timeout 2 notify-send -t 1200 "Tide Island" "island toggled" 2>/dev/null >/dev/null < /dev/null & disown
elif pgrep -f "(^|/)[.]*waybar( |$)" >/dev/null 2>&1; then
  pkill -SIGUSR1 -f "(^|/)[.]*waybar( |$)"
  timeout 2 notify-send -t 1200 "waybar" "visibility toggled" 2>/dev/null >/dev/null < /dev/null & disown
else
  timeout 2 notify-send -t 1200 "No bar running" "SUPER+CTRL+ALT+T starts one" 2>/dev/null >/dev/null < /dev/null & disown
fi
