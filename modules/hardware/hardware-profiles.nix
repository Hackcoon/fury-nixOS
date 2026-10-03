# ============================================================================
# hardware-profiles.nix — PORTABLE hardware toggles for multi-machine NixOS.
# One toggle per machine shape (discrete NVIDIA, hybrid PRIME, AMD, Intel,
# VM guest, dual-boot clock).
#
# DESIGN: everything here is lib.mkDefault — profiles are DEFAULTS. The
# existing tuned modules (e.g. modules/hardware/nvidia.nix) always win.
# Safe to enable a profile alongside a dedicated module without conflicts.
#
# PRIME MODES (laptop i7-10750H + GTX 1660 Ti):
#   "offload" (default): Intel UHD draws Hyprland/desktop, NVIDIA sleeps at
#     ~0W until `nvidia-offload <app>` (games/CUDA/ollama at full speed).
#     Best battery, coolest. Hyprland itself is light — UHD handles it fine.
#   "sync": NVIDIA draws EVERYTHING incl. the compositor, Intel only displays.
#     Max fps, no prefixes, but dGPU never sleeps — hotter, louder, ~1-2h
#     battery. Plugged-in gaming only. Rebuild + reboot to switch.
#   Sync does NOT cool the CPU: the dGPU dumps 50-80W into the same shared
#   heatpipes, so total heat goes UP. For CPU overheating use
#   laptop.powerMode powersave/balanced (boost control) + thermald + clean fans.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
{
  # ── Options: one toggle per machine shape ──
  # Declares every profile switch. configuration.nix flips these per machine;
  # nothing below applies until its toggle is enabled.
  # ----------------------------------------------------------------------
  options.hardware-profiles = {
    nvidia.enable       = mkEnableOption "NVIDIA proprietary driver";
    nvidia-prime = {
      enable      = mkEnableOption "NVIDIA PRIME (laptop hybrid graphics)";
      mode = mkOption {
        type = types.enum [ "offload" "sync" ];
        default = "offload";
        description = "PRIME mode: offload = iGPU desktop + per-app `nvidia-offload`, sync = NVIDIA renders everything (plugged-in gaming).";
      };
      intelBusID  = mkOption { type = types.str; default = "PCI:0:2:0"; description = "Intel iGPU PCI ID — `lspci | grep VGA`, 00:02.0 -> PCI:0:2:0. Ignored on AMD+NVIDIA hybrids."; };
      amdgpuBusID = mkOption { type = types.str; default = "PCI:5:0:0"; description = "AMD iGPU/APU PCI ID — `lspci | grep VGA`, e.g. c5:00.0 -> PCI:197:0:0 (hex bus to decimal). AMD+NVIDIA hybrids only."; };
      nvidiaBusID = mkOption { type = types.str; default = "PCI:1:0:0"; description = "NVIDIA dGPU PCI ID — `lspci | grep 3D`, 01:00.0 -> PCI:1:0:0. Wrong IDs = black screen."; };
    };
    amdgpu.enable       = mkEnableOption "AMD GPU (amdgpu kernel driver)";
    intel.enable        = mkEnableOption "Intel integrated graphics";
    vm-guest.enable     = mkEnableOption "VM guest services (QEMU/KVM boxes)";
    local-hw-clock.enable = mkEnableOption "Local RTC clock (dual-boot machines)";
  };
  # ----------------------------------------------------------------------

  # ── Implementations (all mkDefault, merge into one config) ──
  # Each block below is a full snippet: title, what it does, then the code.
  config = mkMerge [
    # ── NVIDIA (desktop 1660 SUPER) ──
    # Binds the proprietary driver for X11/Wayland. mkDefault throughout, so
    # modules/hardware/nvidia.nix (the tuned desktop driver) wins on overlap.
    # ----------------------------------------------------------------------
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
    # ----------------------------------------------------------------------

    # ── NVIDIA PRIME (laptop iGPU + dGPU, offload or sync) ──
    # Hybrid graphics: syncMode flips the whole snippet. Offload = iGPU desktop
    # with per-app `nvidia-offload`; sync = NVIDIA renders everything. In sync
    # the dGPU never sleeps, so finegrained power MUST stay off or the display
    # dies — that flag is the reason the two modes can't share one setting.
    # ----------------------------------------------------------------------
    (mkIf config.hardware-profiles.nvidia-prime.enable (let
      # True when configuration.nix picked mode = "sync" (NVIDIA renders
      # everything). False = "offload" (iGPU desktop, dGPU sleeps until
      # `nvidia-offload <app>`).
      syncMode = config.hardware-profiles.nvidia-prime.mode == "sync";
    in {
      services.xserver.videoDrivers = mkDefault [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = mkDefault true;
        prime = {
          offload = {
            enable = mkDefault (!syncMode);
            enableOffloadCmd = mkDefault (!syncMode);   # `nvidia-offload <app>`
          };
          # Sync mode: dGPU renders, iGPU displays.
          sync.enable = mkDefault syncMode;
          # Intel+NVIDIA hybrid (ignored when the amdgpu profile is on).
          intelBusId = mkIf (!config.hardware-profiles.amdgpu.enable)
            (mkDefault config.hardware-profiles.nvidia-prime.intelBusID);
          # AMD+NVIDIA hybrid, e.g. Ryzen APU + RTX dGPU (ignored otherwise).
          amdgpuBusId = mkIf config.hardware-profiles.amdgpu.enable
            (mkDefault config.hardware-profiles.nvidia-prime.amdgpuBusID);
          nvidiaBusId = mkDefault config.hardware-profiles.nvidia-prime.nvidiaBusID;
        };
        # Sync keeps the dGPU powered always — finegrained MUST stay off or
        # the display dies. Offload may fully power it down at idle.
        powerManagement.finegrained = mkDefault (!syncMode);
      };
    }))
    # ----------------------------------------------------------------------

    # ── AMD GPU (generic fallback profile) ──
    # Minimal video-driver binding + base packages. The 7800 XT machine uses
    # modules/hardware/amdgpu.nix instead (full stack) — this stays as the
    # lightweight toggle for any other AMD box.
    # ----------------------------------------------------------------------
    (mkIf config.hardware-profiles.amdgpu.enable {
      services.xserver.videoDrivers = mkDefault [ "amdgpu" ];
      hardware.graphics = {
        enable = mkDefault true;
        extraPackages = with pkgs; [ amdvlk rocmPackages.clpkgs ];
      };
    })
    # ----------------------------------------------------------------------

    # ── Intel iGPU (modesetting + video decode) ──
    # Covers Intel-only boxes AND the Intel half of NVIDIA hybrids (laptop).
    # VA-API packages = cheap battery-friendly video playback.
    # ----------------------------------------------------------------------
    (mkIf config.hardware-profiles.intel.enable {
      services.xserver.videoDrivers = mkDefault [ "modesetting" ];
      hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
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
    # ----------------------------------------------------------------------

    # ── VM guest (QEMU/KVM boxes) ──
    # Guest agents for clipboard/resolution/file sharing. spice-vdagentd stays
    # off — it forces 1920x1080 and fights the compositor's own scaling.
    # ----------------------------------------------------------------------
    (mkIf config.hardware-profiles.vm-guest.enable {
      services.qemuGuest.enable = mkDefault true;
      services.spice-vdagentd.enable = mkDefault false;   # forces 1920x1080 — leave off
      services.spice-webdavd.enable = mkDefault true;
    })
    # ----------------------------------------------------------------------

    # ── Local hardware clock (dual-boot with Windows) ──
    # Windows writes local time to the RTC, Linux expects UTC — without this
    # the clock jumps on every reboot into the other OS.
    # ----------------------------------------------------------------------
    (mkIf config.hardware-profiles.local-hw-clock.enable {
      time.hardwareClockInLocalTime = mkDefault true;
    })
    # ----------------------------------------------------------------------
  ];
}
