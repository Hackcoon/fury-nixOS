#!/usr/bin/env bash
# suspend-watch-lock.sh — lock on ANY suspend (DMS 1.6.2 misses PrepareForSleep).
# Watches logind for PrepareForSleep(true) and fires the single-locker chain
# (DMS lock, hyprlock fallback). Started from hyprland.lua autostart.
set -u
LOCK="pidof hyprlock >/dev/null || /run/current-system/sw/bin/dms ipc call lock lock || /run/current-system/sw/bin/hyprlock"
gdbus monitor --system --dest org.freedesktop.login1 \
  --object-path /org/freedesktop/login1 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    *PrepareForSleep*"(true"*)
      # shellcheck disable=SC2086
      eval "$LOCK" >/dev/null 2>&1
      ;;
  esac
done
