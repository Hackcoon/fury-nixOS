#!/usr/bin/env bash
# WallpaperEffects.sh — apply awww (awww) transition effects to the CURRENT wallpaper
# Cycles through transition styles as a quick demo/ricer toy.
EFFECTS=(none simple fade left right top bottom wipe grow center any outer random)
sel=$(printf '%s\n' "${EFFECTS[@]}" | rofi -dmenu -i -p "Effect")
[[ -z "$sel" ]] && exit 0

CURRENT=$(awww query | awk -F'image: ' '{print $2}' | awk '{print $1}')
[[ -z "$CURRENT" ]] && { notify-send -u critical "awww" "No current wallpaper (is awww-daemon running?)"; exit 1; }

awww img "$CURRENT" --transition-type "$sel" --transition-duration 2
notify-send -t 1500 "Wallpaper effect" "$sel"
