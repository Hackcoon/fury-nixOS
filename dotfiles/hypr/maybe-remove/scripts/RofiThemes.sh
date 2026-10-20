#!/usr/bin/env bash
# RofiThemes.sh — live-preview and apply rofi themes
# Themes live in the rofi package's share dir; applying writes ~/.config/rofi/config.rasi
set -euo pipefail

THEME_DIR=$(rofi -help 2>/dev/null | grep -o '/nix/store/[^ ]*/share/rofi/themes' | head -1 || true)
[[ -z "$THEME_DIR" ]] && THEME_DIR=$(dirname "$(readlink -f "$(command -v rofi)")/../share/rofi/themes")

[[ -d "$THEME_DIR" ]] || { notify-send -u critical "Rofi" "theme dir not found"; exit 1; }

mapfile -t themes < <(find "$THEME_DIR" -name "*.rasi" -printf "%f\n" | sed 's/\.rasi$//' | sort)
((${#themes[@]})) || { notify-send -u critical "Rofi" "no themes found"; exit 1; }

sel=$(printf '%s\n' "${themes[@]}" | rofi -dmenu -i -p "Rofi theme")
[[ -z "$sel" ]] && exit 0

mkdir -p "$HOME/.config/rofi"
cat > "$HOME/.config/rofi/config.rasi" <<EOF
configuration {
  modi: "drun,run,emoji,calc,window";
}
@theme "$sel"
EOF

notify-send -t 2000 "Rofi theme" "$sel applied (edit ~/.config/rofi/config.rasi to keep emoji+calc modi)"
