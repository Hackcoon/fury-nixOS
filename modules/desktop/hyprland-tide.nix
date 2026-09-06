# Hyprland + Tide Island — one desktop module for your NixOS config
#
# This file enables Hyprland (the NixOS module handles session files so SDDM
# shows a "Hyprland" option) AND the Tide Island dynamic island you built in
# ~/Projects/tide-island-nix — together, in one import.
{ config, pkgs, lib, ... }:

{
  # =========================================================================
  # 1) HYPRLAND — the compositor (window manager)
  # =========================================================================
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;   # X11 apps (Steam, some games) keep working
  };

  # =========================================================================
  # 2) TIDE ISLAND — the dynamic island widget, from your local package
  # =========================================================================
  programs.tide-island = {
    enable = true;
    withHelpers = true;        # brightnessctl, cava, imagemagick, NetworkManager
    withSystemdService = false; # island starts from hyprland.lua instead
  };

  # The module needs to find the tide-island *package*; point it at your build:
  # (the module's package option defaults to pkgs.tide-island which doesn't
  #  exist yet in nixpkgs — so we override it with your local derivation)
  programs.tide-island.package =
    (pkgs.callPackage /home/fury/Projects/tide-island-nix/tide-island.nix { });

  # =========================================================================
  # 3) Wayland ecosystem extras the island/compositor use
  # =========================================================================
  environment.systemPackages = with pkgs; [
    hyprsunset       # night light — the island's control-center toggle drives this
    hyprpaper        # wallpaper (simple) — or use swww below
    swww             # animated wallpaper daemon — point Tide's wallpaper
                     # "custom command" at: swww img <path> --transition-type grow
    hyprpolkitagent  # password prompts for privileged apps
  ];
}
