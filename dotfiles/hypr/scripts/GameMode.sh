#!/usr/bin/env bash
# GameMode.sh — toggle performance mode: animations + blur off, notifications DND
STATE_FILE="/tmp/hypr-gamemode"
BAR_IPC="quickshell ipc -p $HOME/.config/quickshell/fury-bar"
if [[ -f "$STATE_FILE" ]]; then
  # ── disable gamemode ──
  hyprctl eval 'hl.config({ animations = { enabled = true } })' >/dev/null
  hyprctl eval 'hl.config({ ["decoration.blur.enabled"] = true })' >/dev/null
  $BAR_IPC call notif toggleDnd >/dev/null 2>&1   # DND off (fury-bar)
  rm -f "$STATE_FILE"
  notify-send -t 2000 "GameMode" "OFF — animations + blur restored"
else
  # ── enable gamemode ──
  hyprctl eval 'hl.config({ animations = { enabled = false } })' >/dev/null
  hyprctl eval 'hl.config({ ["decoration.blur.enabled"] = false })' >/dev/null
  $BAR_IPC call notif toggleDnd >/dev/null 2>&1    # DND on (fury-bar)
  touch "$STATE_FILE"
  notify-send -t 2000 "GameMode" "ON — animations off, blur off, DND on"
fi
