# ============================================================================
# amdgpu.nix — AMD discrete GPU (RDNA3 e.g. RX 7800 XT) + Ryzen firmware.
#
# Enable with: amd-gpu.enable = true; (see the AMD PC section in configuration.nix)
# Inert until enabled — safe to import on NVIDIA/Intel machines.
#
# WHAT THIS DOES (standalone — no hardware-profiles toggle needed):
#   - services.xserver.videoDrivers = ["amdgpu"] (X11/XWayland driver binding;
#     Hyprland itself uses KMS/GBM directly, but SDDM/XWayland want this)
#   - amdgpu in initrd (early KMS: no flicker, clean boot)
#   - redistributable firmware + AMD microcode (REQUIRED — Navi won't init
#     without its firmware blob)
#   - Mesa RADV Vulkan + radeonsi VA-API, vulkan-loader for Chromium/Brave,
#     32-bit RADV for Steam/Proton
#   - ROCm/HIP compute: OFF by default (large closure) — flip amd-gpu.rocm
#     below for Blender/AI-on-AMD workloads
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  # Shortcut so we can write cfg.enable instead of config.amd-gpu.enable.
  cfg = config.amd-gpu;
in
{
  # ── Options: master switch + ROCm ──
  options.amd-gpu = {
    enable = mkEnableOption "AMD discrete GPU support (firmware, microcode, Mesa RADV)";
    rocm = mkEnableOption "ROCm/HIP OpenCL compute stack (large download, Blender/AI on AMD)";
  };
  # ----------------------------------------------------------------------

  # Everything below only applies when amd-gpu.enable = true.
  config = mkIf cfg.enable {
    # ── Driver binding: amdgpu replaces modesetting ──
    services.xserver.videoDrivers = mkDefault [ "amdgpu" ];
    # ----------------------------------------------------------------------

    # ── Early KMS: amdgpu in initrd ──
    # Display comes up cleanly, no flicker.
    boot.initrd.kernelModules = [ "amdgpu" ];
    # ----------------------------------------------------------------------

    # ── Firmware + microcode (the hard requirement) ──
    # Navi firmware + Ryzen microcode (7700 included). Without the firmware
    # blob the 7800 XT never initializes — this is the one unskippable piece.
    hardware.enableRedistributableFirmware = mkDefault true;
    hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
    # ----------------------------------------------------------------------

    # ── Mesa RADV stack + 32-bit for Steam ──
    # RADV is the default AMD Vulkan (leave amdvlk off — RADV is faster for
    # games). vulkan-loader = libvulkan.so.1 for Chromium/Brave.
    hardware.graphics = {
      enable = mkDefault true;
      enable32Bit = mkDefault true; # Steam/Proton need 32-bit RADV
      extraPackages = with pkgs; [
        mesa # RADV Vulkan + radeonsi VA-API
        vulkan-loader # libvulkan.so.1 for Chromium/Brave
        libvdpau-va-gl # VDPAU-over-VAAPI bridge
      ];
    };
    # ----------------------------------------------------------------------

    # ── ROCm/HIP compute (gated, OFF unless amd-gpu.rocm) ──
    # OpenCL runtime for Blender Cycles + some AI tools. Adds a large closure.
    environment.systemPackages = mkIf cfg.rocm (with pkgs; [ rocmPackages.clr ]);
    # ----------------------------------------------------------------------
  };
}
