#!/usr/bin/env bash
# SwitchShell.sh — 4-WAY shell switcher: fury-bar ↔ tide-island ↔ waybar ↔ dms
# v8: with no args → cycle. Optional: fury|tide|waybar|dms
# DMS is ALSO the mango-session shell — starting it here runs it inside
# Hyprland intentionally (that's the "dank material on hyprland" mode).
set -uo pipefail

FURY_QML="$HOME/.config/quickshell/fury-bar"
export FURY_QML

TIDE_INSTALLED=0
[[ -x /run/current-system/sw/bin/tide-island ]] && TIDE_INSTALLED=1
DMS_INSTALLED=0
[[ -x /run/current-system/sw/bin/dms ]] && DMS_INSTALLED=1

QS_BIN="$(command -v quickshell || true)"
if [[ -z "$QS_BIN" ]]; then
  qs="$(grep -o '/nix/store/[a-z0-9]*-quickshell-[^:"]*/bin' \
        /run/current-system/sw/bin/tide-island 2>/dev/null | head -1)"
  [[ -n "$qs" ]] && QS_BIN="$qs/quickshell"
fi

fury_running()   { pgrep -f "quickshell -p $FURY_QML" >/dev/null 2>&1; }
tide_running()   { pgrep -f "quickshell .*tide-island" >/dev/null 2>&1; }
waybar_running() { pgrep -f "(^|/)[.]*waybar( |$)" >/dev/null 2>&1; }
dms_running()    { pgrep -f "dms run|quickshell .*dms" >/dev/null 2>&1; }

current_shell() {
  tide_running   && echo "tide"   && return
  dms_running    && echo "dms"    && return
  waybar_running && echo "waybar" && return
  fury_running   && echo "fury"   && return
  echo "none"
}

kill_all_shells() {
  # sweeps: shells take ~1.5s to register their names after fork
  for _ in 1 2 3; do
    pkill -f "quickshell .*tide-island" 2>/dev/null
    pkill -f "quickshell -p $FURY_QML" 2>/dev/null
    pkill -f "(^|/)[.]*waybar( |$)" 2>/dev/null
    pkill -f "dms run|quickshell .*dms" 2>/dev/null
    sleep 0.6
    pgrep -f "quickshell .*tide-island|quickshell -p $FURY_QML|dms run|quickshell .*dms" >/dev/null 2>&1 || break
  done
  pkill -f lyricsmpris 2>/dev/null || true
}

start_fury()   { "$QS_BIN" -p "$FURY_QML" >/dev/null 2>&1 & disown; }
start_tide()   { [[ $TIDE_INSTALLED -eq 1 ]] && { tide-island >/dev/null 2>&1 & disown; } }
start_waybar() { waybar >/dev/null 2>&1 & disown; }
start_dms()    { [[ $DMS_INSTALLED -eq 1 ]] && { dms run >/dev/null 2>&1 & disown; } }

# ── decide target ──
target="${1:-}"
if [[ -z "$target" ]]; then
  case "$(current_shell)" in
    fury)   target="tide" ;;
    tide)   target="waybar" ;;
    waybar) target="dms" ;;
    dms)    target="fury" ;;
    none)   target="fury" ;;
  esac
  # skip uninstalled shells in the cycle
  [[ "$target" == "tide"  && $TIDE_INSTALLED -eq 0 ]] && target="waybar"
  [[ "$target" == "dms"   && $DMS_INSTALLED -eq 0 ]] && target="fury"
fi

kill_all_shells
case "$target" in
  fury)    start_fury ;;
  tide)    start_tide ;;
  waybar)  start_waybar ;;
  dms)     start_dms ;;
  *)       start_fury ;;
esac

# detached reaper: kill late-registering strays (2s + 4s waves)
setsid bash -c '
  sleep 2; sleep 2
  case "$1" in
    fury)   pkill -f "quickshell .*tide-island"; pkill -f "(^|/)[.]*waybar( |$)"; pkill -f "dms run|quickshell .*dms"; pkill -f lyricsmpris ;;
    tide)   pkill -f "quickshell -p $FURY_QML"; pkill -f "(^|/)[.]*waybar( |$)"; pkill -f "dms run|quickshell .*dms" ;;
    waybar) pkill -f "quickshell .*tide-island"; pkill -f "quickshell -p $FURY_QML"; pkill -f "dms run|quickshell .*dms"; pkill -f lyricsmpris ;;
    dms)    pkill -f "quickshell .*tide-island"; pkill -f "quickshell -p $FURY_QML"; pkill -f "(^|/)[.]*waybar( |$)"; pkill -f lyricsmpris ;;
  esac
' _ "$target" >/dev/null 2>&1 </dev/null & disown

setsid bash -c 'sleep 1.2; timeout 2 notify-send -t 1500 "Shell" "→ $1" 2>/dev/null' _ "$target" >/dev/null 2>&1 < /dev/null & disown
