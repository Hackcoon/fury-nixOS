# Gaming: Steam, GameMode, Gamescope, controllers, Proton helpers.
{ config, pkgs, lib, ... }:

{
  # GameMode adjusts CPU scheduling, I/O priority, and other settings
  # while a game is running
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    remotePlay.openFirewall = true;   # Remote Play / streaming
  };

  # Several Proton games crash without this
  boot.kernel.sysctl."vm.max_map_count" = 2147483647;

  # Xbox controller over Bluetooth
  hardware.xpadneo.enable = true;
}
