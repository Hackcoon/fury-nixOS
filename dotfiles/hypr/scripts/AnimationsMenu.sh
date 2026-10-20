#!/usr/bin/env bash
# AnimationsMenu.sh — Hyprland animations quick control (full Lua config era)
# Options: on / off / fast / slow — applied via hyprctl eval (runtime, resets on reload)
menu() {
  printf "Animations ON\nAnimations OFF\nFast\nSlow\n" | rofi -dmenu -i -p "Animations"
}

choice=$(menu)
[[ -z "$choice" ]] && exit 0

case "$choice" in
  "Animations ON")
    hyprctl eval 'hl.config({ animations = { enabled = true } })' >/dev/null ;;
  "Animations OFF")
    hyprctl eval 'hl.config({ animations = { enabled = false } })' >/dev/null ;;
  "Fast")
    # ~60% of default durations
    hyprctl eval 'hl.config({ animations = { enabled = true } })' >/dev/null
    for leaf in windows workspaces layers; do
      hyprctl eval "hl.animation({ leaf = \"$leaf\", enabled = true, speed = 3, curve = \"default\" })" >/dev/null
    done ;;
  "Slow")
    hyprctl eval 'hl.config({ animations = { enabled = true } })' >/dev/null
    for leaf in windows workspaces layers; do
      hyprctl eval "hl.animation({ leaf = \"$leaf\", enabled = true, speed = 10, curve = \"default\" })" >/dev/null
    done ;;
esac
notify-send -t 1500 "Animations" "$choice"
