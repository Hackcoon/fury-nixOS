#!/usr/bin/env bash
# WallpaperRandom.sh — random wallpaper from library
WALLS_DIR="$HOME/Pictures/wallpapers"
[[ -d "$WALLS_DIR" ]] || WALLS_DIR="$HOME/Pictures"

sel=$(find "$WALLS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n1)
[[ -z "$sel" ]] && exit 0

awww img "$sel" --transition-type random --transition-duration 2
notify-send -t 1500 "Wallpaper" "$(basename "$sel")"
