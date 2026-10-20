#!/usr/bin/env bash
# WaybarStyle.sh — cycle waybar CSS styles
# Uses your styles dir: ~/.config/waybar/styles/*.css  (style-N.css)
CONF="$HOME/.config/waybar"
STYLES_DIR="$CONF/styles"
CURRENT="$CONF/style.css"          # symlink → styles/style-N.css

[[ -d "$STYLES_DIR" ]] || { notify-send -u critical "Waybar" "No styles dir: $STYLES_DIR"; exit 1; }

mapfile -t styles < <(ls "$STYLES_DIR"/*.css 2>/dev/null | sort)
((${#styles[@]})) || { notify-send -u critical "Waybar" "No styles found"; exit 1; }

# find current index
cur=""
[[ -L "$CURRENT" ]] && cur=$(readlink "$CURRENT")
idx=0
for i in "${!styles[@]}"; do
  [[ "${styles[$i]}" == "$cur" ]] && idx=$i
done
next=$(( (idx + 1) % ${#styles[@]} ))

ln -sf "${styles[$next]}" "$CURRENT"
if pgrep -f "[w]aybar" >/dev/null 2>&1; then
  pkill -f "[w]aybar( |\$)" 2>/dev/null
  sleep 0.3
  waybar >/dev/null 2>&1 & disown
else
  pkill -f "[w]aybar( |\$)" 2>/dev/null
fi
notify-send -t 1500 "Waybar style" "$(basename "${styles[$next]}")"
