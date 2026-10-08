#!/usr/bin/env bash
# RofiBeats.sh — lofi/radio music picker via mpv (streams, no install needed)
# Streams: lofi, synthwave, jazz, classical, piano, ambient, deathmetal(!)
menu() {
  printf "Lofi Girl - lofi hip hop radio\n\
Synthwave - Nightride FM\n\
Jazz - SomaFM Groove Salad\n\
Classical - SomaFM Classical\n\
Piano - SomaFM Drone Zone\n\
Ambient - SomaFM Deep Space One\n\
Stop playback\n" | rofi -dmenu -i -p "Beats"
}

choice=$(menu)
[[ -z "$choice" ]] && exit 0

# kill previous stream
pkill -f "mpv.*--no-video" 2>/dev/null || true

case "$choice" in
  "Lofi Girl"*)      URL="https://www.youtube.com/watch?v=jfKfPfyJRdk" ;;
  "Synthwave"*)       URL="https://nightride.fm/play/nightride" ;;
  "Jazz"*)            URL="https://ice1.somafm.com/groovesalad-128-mp3" ;;
  "Classical"*)       URL="https://ice1.somafm.com/classical-128-mp3" ;;
  "Piano"*)           URL="https://ice1.somafm.com/dronezone-128-mp3" ;;
  "Ambient"*)         URL="https://ice1.somafm.com/deepspaceone-128-mp3" ;;
  "Stop playback")    pkill -f "mpv.*--no-video" 2>/dev/null; notify-send -t 1500 "Beats" "stopped"; exit 0 ;;
  *) exit 0 ;;
esac

notify-send -t 2000 "Beats" "$choice"
mpv --no-video --really-quiet "$URL" >/dev/null 2>&1 & disown
