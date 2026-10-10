#!/usr/bin/env bash
# KooLSettings.sh — settings menu: system config tools + this rice's docs
menu() {
  printf "Keybinds (searchable)\n\
Tide Island Settings\n\
Hyprland config (hyprland.lua)\n\
Binds config (binds.lua)\n\
Wallpaper picker\n\
Zsh theme switcher\n\
Rofi theme picker\n\
NixOS rebuild (switch)\n\
NixOS rebuild (test)\n\
NixOS config folder\n\
Audio mixer (pavucontrol)\n\
Display settings (wlr-randr)\n" | rofi -dmenu -i -p "Settings"
}

choice=$(menu)
case "$choice" in
  "Keybinds (searchable)")      exec "$HOME/.config/hypr/scripts/Help.sh" ;;
  "Tide Island Settings")       exec tide-island-config-app ;;
  "Hyprland config (hyprland.lua)")   kitty -e "$EDITOR" ~/.config/hypr/hyprland.lua ;;
  "Binds config (binds.lua)")   kitty -e "$EDITOR" ~/.config/hypr/binds.lua ;;
  "Wallpaper picker")           exec "$HOME/.config/hypr/scripts/WallpaperSelect.sh" ;;
  "Zsh theme switcher")         exec "$HOME/.config/hypr/scripts/ZshSwitcher.sh" ;;
  "Rofi theme picker")          exec "$HOME/.config/hypr/scripts/RofiThemes.sh" ;;
  "NixOS rebuild (switch)")     kitty -e sudo nixos-rebuild switch --flake /etc/nixos#nixos ;;
  "NixOS rebuild (test)")       kitty -e sudo nixos-rebuild test --flake /etc/nixos#nixos ;;
  "NixOS config folder)")       exec thunar /etc/nixos ;;
  "Audio mixer (pavucontrol)")  exec pavucontrol ;;
  "Display settings (wlr-randr)") exec wlr-randr ;;
esac
