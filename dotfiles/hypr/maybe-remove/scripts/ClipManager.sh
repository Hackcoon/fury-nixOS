#!/usr/bin/env bash
# ClipManager.sh — clipboard history via cliphist + rofi
# (requires: wl-paste --watch cliphist store  running — hyprland.lua autostarts it)
sel=$(cliphist list | rofi -dmenu -i -p "Clipboard")
[[ -n "$sel" ]] && echo "$sel" | cliphist decode | wl-copy
