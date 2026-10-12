# ============================================================================
# nvidia.nix — NVIDIA proprietary driver, DESKTOP 1660 SUPER (TU116) only.
#
# UNCONDITIONAL: applies whenever imported — comment this file out of imports
# on the laptop (PRIME profile covers it) and the AMD PC. Tuned for TU116:
# proprietary userspace, stable driver branch, sleep-safe VRAM handling.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Unfree + driver binding ──
  # allowUnfree covers the proprietary NVIDIA userland; videoDrivers loads it
  # for both X11 and Wayland.
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  # ----------------------------------------------------------------------

  # ── Driver behavior: sleep-safe, modesetting, TU116 userspace ──
  # open=false = proprietary userspace (best for TU116; 50xx-series would flip
  # this true). stable branch over latest: fewer surprises on a machine that
  # must Just Boot.
  hardware.nvidia = {
    # Saves VRAM contents to disk before sleep and restores on wake —
    # prevents KWin/Plasma from losing display buffers and crashing
    # on resume.
    powerManagement.enable = true;

    # Kernel Mode Setting — required for proper display mode
    # restoration on wake and mandatory for Wayland compositors.
    modesetting.enable = true;

    open = false;            # proprietary userspace (best for TU116)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  # ----------------------------------------------------------------------

  # ── Session env: GLX to NVIDIA, nothing forced ──
  environment.sessionVariables = {
    # Direct GLX apps to NVIDIA driver
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Hardware acceleration — keep disabled for now (breaks vesktop).
    # LIBVA_DRIVER_NAME = "nvidia";

    # Forces Electron/Chromium apps native Wayland — breaks upscayl
    # and vesktop, which is why packages/apps-fixed.nix wraps them
    # back to X11.
    # NIXOS_OZONE_WL = "1";
  };
  # ----------------------------------------------------------------------

  # ── Graphics stack: GL + 32-bit + Vulkan loader ──
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit for gaming
    # vulkan-loader: Brave (and other Chromium browsers with the Vulkan
    # feature) needs libvulkan.so.1 at runtime. make-brave.nix only adds
    # the ICD search path (XDG_DATA_DIRS), not the loader itself, so we
    # provide it via the driver runpath.
    extraPackages = [ pkgs.vulkan-loader ];
  };
  # ----------------------------------------------------------------------
}
