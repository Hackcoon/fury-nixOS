# ============================================================================
# hardware-profiles.nix — PORTABLE hardware toggles for multi-machine NixOS
# Ported from LinuxBeginnings/NixOS-Hyprland (hosts/*/config.nix driver block)
#
# DESIGN: everything here is lib.mkDefault — profiles are DEFAULTS. Your
# existing tuned modules (e.g. modules/hardware/nvidia.nix) always win.
# Safe to enable a profile alongside a dedicated module without conflicts.
{ config, pkgs, lib, ... }:

with lib;
{
  # ───────────────────────── options ─────────────────────────
  options.hardware-profiles = {
    nvidia.enable       = mkEnableOption "NVIDIA proprietary driver";
    nvidia-prime = {
      enable      = mkEnableOption "NVIDIA PRIME (laptop hybrid graphics)";
      intelBusID  = mkOption { type = types.str; default = "PCI:0:2:0"; };
      nvidiaBusID = mkOption { type = types.str; default = "PCI:1:0:0"; };
    };
    amdgpu.enable       = mkEnableOption "AMD GPU (amdgpu kernel driver)";
    intel.enable        = mkEnableOption "Intel integrated graphics";
    vm-guest.enable     = mkEnableOption "VM guest services (QEMU/KVM boxes)";
    local-hw-clock.enable = mkEnableOption "Local RTC clock (dual-boot machines)";
  };

  # ───────────────────────── implementations (all mkDefault) ─────────────────
  config = mkMerge [
    # ── NVIDIA (your desktop) ──
    (mkIf config.hardware-profiles.nvidia.enable {
      services.xserver.videoDrivers = mkDefault [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = mkDefault true;
        powerManagement.enable = mkDefault true;
        open = mkDefault false;              # set true for 50xx-series cards
        nvidiaSettings = mkDefault true;
        package = mkDefault config.boot.kernelPackages.nvidiaPackages.stable;
      };
      hardware.graphics.enable = mkDefault true;
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = mkDefault "nvidia";
        __GLX_VENDOR_LIBRARY_NAME = mkDefault "nvidia";
      };
    })

    # ── NVIDIA PRIME (laptop: iGPU + dGPU) ──
    (mkIf config.hardware-profiles.nvidia-prime.enable {
      services.xserver.videoDrivers = mkDefault [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = mkDefault true;
        prime = {
          offload = {
            enable = mkDefault true;
            enableOffloadCmd = mkDefault true;   # `nvidia-offload <app>`
          };
          intelBusId  = mkDefault config.hardware-profiles.nvidia-prime.intelBusID;
          nvidiaBusId = mkDefault config.hardware-profiles.nvidia-prime.nvidiaBusID;
        };
      };
    })

    # ── AMD GPU ──
    (mkIf config.hardware-profiles.amdgpu.enable {
      services.xserver.videoDrivers = mkDefault [ "amdgpu" ];
      hardware.graphics = {
        enable = mkDefault true;
        extraPackages = with pkgs; [ amdvlk rocmPackages.clpkgs ];
      };
    })

    # ── Intel iGPU ──
    (mkIf config.hardware-profiles.intel.enable {
      services.xserver.videoDrivers = mkDefault [ "modesetting" ];
      hardware.graphics = {
        enable = mkDefault true;
        extraPackages = with pkgs; [
          intel-media-driver       # Broadwell+ VAAPI
          vaapiIntel
          vaapiVdpau
          libvdpau-va-gl
        ];
      };
    })

    # ── VM guest (their vm-guest-services.nix) ──
    (mkIf config.hardware-profiles.vm-guest.enable {
      services.qemuGuest.enable = mkDefault true;
      services.spice-vdagentd.enable = mkDefault false;   # their note: breaks to 1920x1080
      services.spice-webdavd.enable = mkDefault true;
    })

    # ── Local hardware clock (dual-boot with Windows) ──
    (mkIf config.hardware-profiles.local-hw-clock.enable {
      time.hardwareClockInLocalTime = mkDefault true;
    })
  ];
}
