#!/usr/bin/env bash
# GameModeBinds.sh — toggle the keybind-passthrough submap (on|off).
# Lives in a script (not a Lua callback) so DMS's keybinds provider can read
# the action string and show it in SUPER+H. hyprctl dispatch is Lua-shimmed on
# this build, so submap changes go through `hyprctl eval`.
set -u

case "${1:-toggle}" in
    on)
        notify-send -t 3000 "Game Mode" "ON - binds off, ALT+\` to exit"
        hyprctl eval 'hl.dispatch(hl.dsp.submap("keybinds_disabled"))' >/dev/null
        ;;
    off)
        notify-send -t 2000 "Game Mode" "OFF - binds restored"
        hyprctl eval 'hl.dispatch(hl.dsp.submap("reset"))' >/dev/null
        ;;
    *)
        echo "usage: $0 {on|off}" >&2
        exit 2
        ;;
esac
