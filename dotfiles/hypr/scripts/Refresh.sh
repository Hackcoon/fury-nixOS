#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Refresh bars/menus/rofi — SHELL-AWARE (fury-bar / tide / waybar).
# Never spawns a bar that isn't the currently-selected shell.
SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts
FURY_QML="$HOME/.config/quickshell/fury-bar"

# ── which shell is active? ──
fury_running()   { pgrep -f "quickshell -p $FURY_QML" >/dev/null 2>&1; }
tide_running()   { pgrep -f "quickshell .*tide-island" >/dev/null 2>&1; }
waybar_running() { pgrep -f "(^|/)[.]*waybar( |$)" >/dev/null 2>&1; }

file_exists() { [ -e "$1" ]; }

# Kill stale rofi (menu leftovers) — harmless for all shells
if pidof rofi >/dev/null; then pkill rofi; fi

# ── refresh the ACTIVE shell only ──
if fury_running; then
    pkill -SIGUSR2 -f "(^|/)[.]*waybar( |$)" 2>/dev/null || true   # no-op when waybar absent
    pkill -f "quickshell -p $FURY_QML" 2>/dev/null
    sleep 0.4
    quickshell -p "$FURY_QML" >/dev/null 2>&1 & disown
elif tide_running; then
    TIDE_QML="$(readlink -f /run/current-system/sw/share/tide-island 2>/dev/null || echo /run/current-system/sw/share/tide-island)"
    pkill -f "quickshell .*tide-island" 2>/dev/null
    sleep 0.4
    tide-island >/dev/null 2>&1 & disown
elif waybar_running; then
    # waybar's own reload (SIGUSR2 = refresh css; kill+respawn for full reload)
    pkill -f "(^|/)[.]*waybar( |$)" 2>/dev/null
    sleep 0.4
    waybar >/dev/null 2>&1 & disown
fi

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    ${UserScripts}/RainbowBorders.sh &
fi

exit 0
