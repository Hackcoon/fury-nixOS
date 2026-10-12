# ============================================================================
# intel-gpu.nix — Full Intel graphics stack (iGPU, Arc discrete, hybrids).
#
# Enable with: intel-gpu.enable = true; (see OTHER MACHINES in configuration.nix)
# Inert until enabled — safe to import on AMD/NVIDIA machines.
#
# WHAT THIS DOES (standalone — no hardware-profiles toggle needed):
#   - services.xserver.videoDrivers = ["modesetting"] (X11/XWayland binding)
#   - Intel microcode updates (stability + security fixes from Intel)
#   - i915 in initrd (early KMS: clean boot, no flicker)
#   - Intel VA-API decode stack (cheap video playback, incl. battery boxes)
#   - firmware for Arc discrete cards (enableRedistributableFirmware)
# PARKED for a future Intel box — nothing here uses it yet.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  # Shortcut so we can write cfg.enable instead of config.intel-gpu.enable.
  cfg = config.intel-gpu;
in
{
  # ── Options: master switch ──
  options.intel-gpu = {
    enable = mkEnableOption "Full Intel graphics stack (microcode, early KMS, VA-API)";
  };
  # ----------------------------------------------------------------------

  # Everything below only applies when intel-gpu.enable = true.
  config = mkIf cfg.enable {
    # ── Driver binding: modesetting covers Intel ──
    services.xserver.videoDrivers = mkDefault [ "modesetting" ];
    # ----------------------------------------------------------------------

    # ── Microcode + early KMS + firmware ──
    # Microcode = Intel stability/security fixes. i915 in initrd = clean boot.
    # Redistributable firmware covers Arc discrete + newer iGPU media blobs.
    hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
    boot.initrd.kernelModules = [ "i915" ];
    hardware.enableRedistributableFirmware = mkDefault true;
    # ----------------------------------------------------------------------

    # ── VA-API decode stack ──
    hardware.graphics = {
      enable = mkDefault true;
      extraPackages = with pkgs; [
        intel-media-driver       # Broadwell+ VAAPI
        vaapiIntel               # older Intel VAAPI
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    # ----------------------------------------------------------------------
  };
}
