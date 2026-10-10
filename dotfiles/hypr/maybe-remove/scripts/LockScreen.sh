#!/usr/bin/env bash
# LockScreen.sh — lock via DMS (DankMaterialShell) lockscreen, fallback hyprlock
#
# Priority:
#   1. dms ipc call lock lock  — DMS 1.6 lock module (only works when
#      the DMS shell is running and its IPC socket is up, e.g. mango)
#   2. hyprlock                — Hyprland session lock (ext-session-lock)
#   3. loginctl lock-session   — last resort (kde-lockscreen etc.)
#
# NOTE: on Hyprland, DMS is not running (fury-bar is the shell there),
# so the dms call fails fast and hyprlock takes over. On mango, DMS
# answers and its own lockscreen shows.

if command -v dms >/dev/null 2>&1 && dms ipc call lock lock >/dev/null 2>&1; then
  exit 0
fi

if command -v hyprlock >/dev/null 2>&1; then
  exec hyprlock
fi

exec loginctl lock-session
