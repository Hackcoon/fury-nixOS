#!/usr/bin/env bash
# Help.sh — searchable cheat sheet of your keybinds (rofi)
# Reads ~/.config/hypr/KEYBINDS (simple "key  |  description" lines)
HELP_FILE="$HOME/.config/hypr/KEYBINDS"

if [[ ! -f "$HELP_FILE" ]]; then
  cat > "$HELP_FILE" <<'EOF'
SUPER + H         | This help
SUPER + D         | Vicinae launcher (black/white)
SUPER SHIFT + D   | App launcher (rofi)
SUPER + Return    | Terminal (kitty)
SUPER + Q         | Close window
SUPER SHIFT + Q   | Kill window (force)
SUPER + E         | Thunar file manager
SUPER + F         | Fullscreen toggle
SUPER SHIFT + F   | Maximize (layout-aware fullscreen)
SUPER + SPACE     | Toggle floating
SUPER ALT + SPACE | Float all tiled windows
SUPER + G         | Toggle window group
SUPER + U         | Toggle scratchpad (special:magic)
SUPER SHIFT + U   | Move window to scratchpad
SUPER + 1..9,0    | Workspace 1..10
SUPER SHIFT + 1..0| Move window to workspace
SUPER + Tab       | Next workspace
SUPER SHIFT + Tab | Previous workspace
SUPER + arrows    | Focus direction
SUPER CTRL + arrows | Move window direction
SUPER SHIFT + arrows | Resize window ±20px
SUPER + mouse     | Drag window (LMB) / resize (RMB)
ALT + Tab         | Cycle windows
Print             | Full screenshot
SHIFT + Print     | Area screenshot
SUPER SHIFT + S   | Area → satty annotate
CTRL ALT + L      | Lock screen
CTRL ALT + P      | Power menu (wlogout)
CTRL ALT + Delete | Exit Hyprland
SUPER SHIFT + N   | Toggle notification center (swaync)
SUPER + W         | Wallpaper select
SUPER ALT + V     | Clipboard history
SUPER ALT + C     | Calculator (rofi-calc)
SUPER ALT + E     | Emoji picker
SUPER + A         | Tide Island overview (see binds.lua note)
EOF
fi

rofi -dmenu -i -p "Keybinds" < "$HELP_FILE"
