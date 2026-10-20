# ============================================================================
# TIDE ISLAND — optional dynamic island shell (Quickshell widget)
#
# FULLY SEPARATE from hyprland.nix. To remove Tide Island from the system:
#   1. comment ONE line in configuration.nix:
#        # ./modules/unused/tide-island.nix
#   2. rebuild. Done — hyprland/fury-bar/vicinae all keep working.
#
# When disabled: SwitchShell.sh detects absence and only manages fury-bar;
# hyprland.lua's tide autostart line is already commented by default
# (fury-bar is the main shell).
#
# Package source lives in /etc/nixos/pkgs/tide-island/ (in-flake, pure eval).
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../pkgs/tide-island/module.nix
  ];

  programs.tide-island = {
    enable = true;
    withHelpers = true;         # brightnessctl, cava, imagemagick, NM, pywal
    withSystemdService = false; # started via SwitchShell/hyprland.lua instead
    package = pkgs.callPackage ../../pkgs/tide-island/tide-island.nix { };
  };
}
