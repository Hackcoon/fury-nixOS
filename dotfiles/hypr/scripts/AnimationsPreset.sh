#!/usr/bin/env bash
# AnimationsPreset.sh — animation STYLE preset switcher (ported from
# LinuxBeginnings/Hyprland-Dots Animations.sh, adapted to this setup).
# SUPER+SHIFT+A = speed on/off menu (AnimationsMenu.sh); THIS script on
# SUPER+ALT+A picks one of ~/.config/hypr/animations/*.lua and copies it to
# UserConfigs/user_animations.lua (loaded by hyprland.lua after the base
# animations, so it wins), then reloads Hyprland to apply.
set -u
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
ANIM_DIR="$HYPR_DIR/animations"
TARGET="$HYPR_DIR/UserConfigs/user_animations.lua"
ROFI_THEME="$HOME/.config/rofi/config-Animations.rasi"

pidof rofi >/dev/null 2>&1 && pkill rofi

list=$(find -L "$ANIM_DIR" -maxdepth 1 -type f -name "*.lua" | sed 's/.*\///; s/\.lua$//' | sort -V)
if [[ -z "$list" ]]; then
  notify-send "Animation presets" "No *.lua in $ANIM_DIR"
  exit 0
fi

chosen=$(echo "$list" | rofi -i -dmenu -config "$ROFI_THEME" -mesg "❗NOTE:❗ copies into UserConfigs/user_animations.lua" -p "Animations")
[[ -z "${chosen:-}" ]] && exit 0

if [[ -f "$ANIM_DIR/$chosen.lua" ]]; then
  cp "$ANIM_DIR/$chosen.lua" "$TARGET"
  notify-send -t 2000 "Animations" "$chosen loaded"
  sleep 1
  hyprctl reload >/dev/null 2>&1
else
  notify-send "Animations" "Preset not found: $chosen"
fi
