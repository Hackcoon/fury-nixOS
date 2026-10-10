#!/usr/bin/env bash
# WallpaperSelect.sh — pick a wallpaper via rofi, apply with awww (awww fork)
WALLS_DIR="$HOME/Pictures/wallpapers"
[[ -d "$WALLS_DIR" ]] || WALLS_DIR="$HOME/Pictures"

# stop awww-daemon? no — it keeps running; just queue the image
sel=$(find "$WALLS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort | rofi -dmenu -i -p "Wallpaper")
[[ -z "$sel" ]] && exit 0

awww img "$sel" --transition-type grow --transition-pos "$(hyprctl cursorpos | awk '{print $1","$2}')" --transition-duration 2
notify-send -t 1500 "Wallpaper" "$(basename "$sel")"
