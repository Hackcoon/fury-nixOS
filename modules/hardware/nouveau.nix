# ============================================================================
# nouveau.nix — Open-source NVIDIA driver (basic display, no CUDA/perf).
#
# Enable with: nouveau.enable = true; (see OTHER MACHINES in configuration.nix)
# Inert until enabled — safe to import everywhere. NEVER enable alongside the
# proprietary stack (nvidia.nix / PRIME): two drivers binding one card breaks
# the display. Pick one.
#
# WHAT THIS DOES: modesetting-friendly open driver for NVIDIA cards where the
# proprietary blob is unwanted (ideology, unsupported old cards, rescue use).
# Honest limits: no CUDA, no serious gaming perf, Turing+ needs GSP firmware
# for more than basic modesetting. For full speed use the proprietary stack.
# PARKED — nothing here uses it yet.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  # Shortcut so we can write cfg.enable instead of config.nouveau.enable.
  cfg = config.nouveau;
in
{
  # ── Options: master switch ──
  options.nouveau = {
    enable = mkEnableOption "Open-source Nouveau NVIDIA driver (basic display)";
  };
  # ----------------------------------------------------------------------

  # Everything below only applies when nouveau.enable = true.
  config = mkIf cfg.enable {
    # ── Driver binding: nouveau replaces nvidia/modesetting ──
    services.xserver.videoDrivers = mkDefault [ "nouveau" ];
    # ----------------------------------------------------------------------

    # ── Kernel side: nouveau in initrd for early KMS ──
    boot.initrd.kernelModules = [ "nouveau" ];
    hardware.graphics = {
      enable = mkDefault true;
    };
    # ----------------------------------------------------------------------
  };
}
