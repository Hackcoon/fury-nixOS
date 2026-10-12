# ============================================================================
# configuration-pi.nix — Raspberry Pi host entry (PARKED, UNTESTED).
#
# No ARM hardware exists here, so nothing below is validated: treat this as a
# starting draft, not a working config. Referenced (commented) by the
# RASPBERRY PI skeleton in flake.nix. First real work happens on the Pi.
#
# SHAPE: console-first minimal. Only portable core modules + shell + users.
# Everything x86/NVIDIA/CUDA/gaming/AI is deliberately absent — most of it
# doesn't exist on aarch64 (proton, CUDA wheels, brave-webgpu, ollama-cuda).
# Desktop (Hyprland runs on ARM via wlroots) comes later, after console boot
# is proven. system-packages.nix is EXCLUDED until audited for x86-only pkgs.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  imports = [
    # --- hardware (generate ON THE PI, never copy) ---
    ./hardware-configuration.nix

    # --- core (portable subset) ---
    ./modules/core/locale.nix
    ./modules/core/network.nix
    ./modules/core/dns.nix
    ./modules/core/default-apps.nix
    ./modules/core/flatpak.nix
    ./modules/core/fonts.nix
    # ./modules/core/nix.nix        # EXCLUDED for now: sets cudaSupport=true
                                    # + CUDA caches (meaningless on ARM). The
                                    # essentials (flakes, nh, nix-ld) are
                                    # re-declared minimally below instead.
    # ./modules/core/appimage.nix   # EXCLUDED: AppImage is x86_64-only.
    # ./modules/core/boot.nix       # EXCLUDED: Lanzaboote Secure Boot is x86.

    # --- hardware (generic only) ---
    ./modules/hardware/ssd.nix      # tmpfs/zram/trim — arch-independent

    # --- shell + user ---
    ./modules/programs/shell.nix
    ./modules/users/users.nix       # groups libvirtd/wireshark are harmless
                                    # without their services; trim if wanted

    # --- desktop/services/AI: intentionally empty on first boot ---
    # Prove console boot first. Candidates later (all need ARM verification):
    # ./modules/desktop/hyprland.nix  # wlroots runs on ARM — try first
    # ./modules/desktop/portals.nix
    # ./modules/services/printing.nix
  ];

  # ── Pi boot: extlinux/U-Boot, NOT Lanzaboote ──
  # VERIFY ON DEVICE: kernel package name (rpi4 vs rpi5 vs mainline moves
  # with nixpkgs releases — check `nix search nixpkgs linuxPackages_rpi`
  # on the Pi), firmware blobs, and device-tree overlays for the board rev.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  # boot.kernelPackages = pkgs.linuxPackages_rpi4; # confirm name on device
  hardware.enableRedistributableFirmware = true; # Pi firmware blobs

  # ── Nix essentials (minimal stand-in for core/nix.nix) ──
  # Flakes + store optimization + nh GC + nix-ld. cudaSupport stays OFF:
  # no CUDA on ARM (Jetson-only, not this flake's problem).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nixpkgs.config.cudaSupport = false;
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 30d --keep 10 --keep-one";
    };
  };
  programs.nix-ld.enable = true;

  networking.hostName = "raspberry";

  # Fresh machine: set to the release FIRST installed here (not 26.05 by
  # ritual). Changing it later does NOT upgrade — it pins stateful-data
  # defaults to the install release.
  system.stateVersion = "26.05"; # adjust to actual install release
}
