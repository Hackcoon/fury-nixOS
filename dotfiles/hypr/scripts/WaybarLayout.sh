#!/usr/bin/env bash
# WaybarLayout.sh — cycle waybar config layouts
# Uses ~/.config/waybar/layouts/config-N.jsonc; active = ~/.config/waybar/config.jsonc
CONF="$HOME/.config/waybar"
LAYOUTS_DIR="$CONF/configs"
ACTIVE="$CONF/config.jsonc"

[[ -d "$LAYOUTS_DIR" ]] || { notify-send -u critical "Waybar" "No layouts dir: $LAYOUTS_DIR"; exit 1; }

# JaKooLit layouts have NO file extension (names like "[TOP] Default")
mapfile -t layouts < <(ls "$LAYOUTS_DIR" 2>/dev/null | grep -v "^\." | sed "s|^|$LAYOUTS_DIR/|" | sort)
((${#layouts[@]})) || { notify-send -u critical "Waybar" "No layouts found"; exit 1; }

cur=""
[[ -L "$ACTIVE" ]] && cur=$(readlink "$ACTIVE")
idx=0
for i in "${!layouts[@]}"; do
  [[ "${layouts[$i]}" == "$cur" ]] && idx=$i
done
next=$(( (idx + 1) % ${#layouts[@]} ))

ln -sf "${layouts[$next]}" "$ACTIVE"
ln -sf "${layouts[$next]}" "$CONF/config"   # waybar reads either; keep both fresh
# SHELL-AWARE: only (re)start waybar if waybar is the CURRENT shell —
# cycling layouts while fury-bar/tide runs just remembers the choice.
if pgrep -f "[w]aybar" >/dev/null 2>&1; then
  pkill -f "(^|/)[.]*waybar( |$)" 2>/dev/null
  sleep 0.3
  waybar >/dev/null 2>&1 & disown
else
  pkill -f "(^|/)[.]*waybar( |$)" 2>/dev/null   # sweep any stray, spawn none
fi
notify-send -t 1500 "Waybar layout" "$(basename "${layouts[$next]}")"
