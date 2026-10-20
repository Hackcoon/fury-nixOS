# ============================================================================
# gaming.nix — Steam, GameMode, Gamescope, controllers, Proton helpers.
#
# HEAVY: Steam pulls 32-bit + Proton (see the 32-bit graphics in
# hardware/nvidia.nix and amdgpu.nix). Drop for minimal. The 7800 XT AMD PC
# is the natural gaming box (Mesa RADV); this desktop's 1660 SUPER also plays.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── GameMode + Gamescope: perf while playing ──
  # GameMode retunes CPU scheduling + I/O priority while a game runs.
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;
  # ----------------------------------------------------------------------

  # ── Steam + Proton-GE + Remote Play ──
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    remotePlay.openFirewall = true;   # Remote Play / streaming
  };
  # ----------------------------------------------------------------------

  # ── Proton crash fix: giant mmap allowance ──
  # Several Proton games crash without this (address-space exhaustion).
  boot.kernel.sysctl."vm.max_map_count" = 2147483647;
  # ----------------------------------------------------------------------

  # ── Xbox controller over Bluetooth ──
  hardware.xpadneo.enable = true;
  # ----------------------------------------------------------------------
}
