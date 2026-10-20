#!/usr/bin/env bash
# ToggleKeyboard.sh — toggle typd floating on-screen keyboard (mouse-usable).
#
# No physical keyboard? Launch with MOUSE only:
#   SUPER+SPACE (DMS spotlight) or SUPER+D launcher -> type/click "ToggleKeyboard"
#   or click Waybar/DMS tray -> terminal -> run this script.
# Toggle behavior: running -> hide (kill); stopped -> show floating keyboard.
# typd = layer-shell surface: never steals focus, keys clickable with mouse,
# drag the top bar to move anywhere, drag edges/corners to resize, red X closes.
# NOTE: Hyprland SUPER+LMB/RMB move+resize do NOT apply — those only grab real
# windows, and typd is a layer surface. Use its own drag bar / edges.
# Fallback (docked, no drag): `wvkbd-mobintl -H 220 -L 320 &` (pkgs.wvkbd).
set -u

BIN="$(command -v typd 2>/dev/null || echo /run/current-system/sw/bin/typd)"

if pgrep -x typd >/dev/null; then
    pkill -x typd
    notify-send "Keyboard" "On-screen keyboard hidden" 2>/dev/null || true
    exit 0
fi

# setsid so it survives the launcher.
setsid "$BIN" >/tmp/typd.log 2>&1 < /dev/null &
notify-send "Keyboard" "On-screen keyboard shown (SUPER+SHIFT+K to hide)" 2>/dev/null || true
