#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# for changing Hyprland Layouts (Master or Dwindle) on the fly

notif="$HOME/.config/swaync/images/ja.png"

# Serialize rapid presses: queue behind any running instance so every
# press reads post-eval state (without this, two overlapping presses read
# the same layout and jump to the same target -> looks "stuck").
exec 9>/tmp/changelayout.lock
flock 9

# Per-workspace cycle: dwindle -> master -> scrolling -> hy3 -> dwindle.
# Pins the ACTIVE workspace via workspace_rule, so a pinned WS1 can still
# be changed later with SUPER+L. (hy3 = plugin, needs hl.plugin.load;
# unknown layouts fall to dwindle.)
WS=$(hyprctl -j activeworkspace | jq -r '.id')
CUR=$(hyprctl -j workspaces | jq -r --argjson id "$WS" '.[] | select(.id==$id) | .tiledLayout // "dwindle"')

case $CUR in
"dwindle")
  NEXT="master"
  LABEL=" Master Layout"
  ;;
"master")
  NEXT="scrolling"
  LABEL=" Scrolling Layout"
  ;;
"scrolling")
  NEXT="hy3"
  LABEL=" Hy3 Layout"
  ;;
"hy3")
  NEXT="dwindle"
  LABEL=" Dwindle Layout"
  ;;
*)
  NEXT="dwindle"
  LABEL=" Dwindle Layout"
  ;;
esac

hyprctl eval "hl.workspace_rule({ workspace = \"$WS\", layout = \"$NEXT\" })"
notify-send -e -u low -i "$notif" "$LABEL"
