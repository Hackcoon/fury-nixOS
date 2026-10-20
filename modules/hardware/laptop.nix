# ============================================================================
# laptop.nix — Laptop master switch: power, input, wireless, sleep.
#
# Enable with: laptop.enable = true; (wired in configuration.nix)
# Pair with hardware-profiles.nvidia-prime.enable = true, plus EITHER:
#   Intel+NVIDIA: hardware-profiles.intel.enable = true (+ intelBusID)
#   AMD+NVIDIA:   hardware-profiles.amdgpu.enable = true
# e.g. i7-10750H + UHD + GTX 1660 Ti.
#
# WHAT THIS DOES:
#   - Power: upower, powertop auto-tune, power-profiles-daemon OFF
#     (conflicts with TLP). All TLP AC/BAT + powersave/balanced/performance
#     tuning lives in power-modes.nix (laptop.powerMode) — setting TLP values
#     here as well collides with that module.
#     (+ thermald ONLY on Intel — off on AMD)
#   - NVIDIA PRIME tuning (fine-grained power in offload mode, sync flags
#     in sync mode, nvidia-settings GUI)
#   - Input: libinput touchpad (tapping, natural scroll off, disable-while-typing)
#   - Wireless: NetworkManager wifi powersave, bluetooth on, fwupd firmware
#   - Sleep: systemd suspend-then-hibernate, lid-switch handling
#   - Battery niceties: acpi tool, brightnessctl (already in hyprland.nix)
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  # Shortcut so we can write cfg.enable instead of config.laptop.enable.
  cfg = config.laptop;
in
{
  # ── Options: master switch (OFF until configuration.nix flips it) ──
  # mkEnableOption defaults false — importing this file alone changes nothing.
  options.laptop.enable = mkEnableOption "laptop power, input and wireless tuning";
  # ----------------------------------------------------------------------

  # Everything below only applies when laptop.enable = true.
  # (Hostname stays from modules/core/network.nix — set per machine in
  # configuration.nix, not forced here.)
  config = mkIf cfg.enable {
    # ── Kernel power knobs + powertop auto-tune ──
    powerManagement = {
      enable = true; # enable /sys power knobs
      powertop.enable = true; # install powertop --auto-tune service
    };
    # ----------------------------------------------------------------------

    # ── TLP on, power-profiles-daemon OFF (they fight over governors) ──
    # GNOME/KDE enable the daemon by default, hence mkForce. TLP's actual
    # AC/BAT tables live in power-modes.nix (laptop.powerMode) — this file
    # only turns the daemon on.
    services.power-profiles-daemon.enable = mkForce false;
    services.tlp.enable = true; # daemon on; profiles come from power-modes.nix
    # ----------------------------------------------------------------------

    # ── thermald: Intel-only thermal guard ──
    # Keeps thin Intel laptops from throttling badly. Follows the intel
    # profile toggle — off on AMD (Ryzen handles thermals via firmware/k10temp).
    services.thermald.enable = lib.mkDefault config.hardware-profiles.intel.enable;
    # ----------------------------------------------------------------------

    # ── UPower: battery backend + hibernate-at-5% ──
    # Feeds bars + `upower -d`. Thresholds warn at 15/8, then hibernate
    # instead of dying mid-write at 5.
    services.upower = {
      enable = true; # battery daemon
      percentageLow = 15; # warn at 15 percent
      percentageCritical = 8; # urgent warn at 8 percent
      percentageAction = 5; # act at 5 percent
      criticalPowerAction = "Hibernate"; # hibernate instead of dying
    };
    # ----------------------------------------------------------------------

    # ── acpid + fwupd: power events + firmware updates ──
    # acpid handles power-button/lid/charger events; fwupd = `fwupdmgr
    # get-updates` for BIOS/SSD/etc.
    services.acpid.enable = true;
    services.fwupd.enable = true;
    # ----------------------------------------------------------------------

    # ── Sleep: suspend-then-hibernate (2h), lid + idle policy ──
    # Light RAM sleep first, hibernate to disk after 2h. Needs DISK swap —
    # zram alone cannot hibernate (suspend still works, hibernate fails
    # gracefully). Lid: sleep on battery, lighter sleep on charger (faster
    # wake), ignore when docked (external monitor stays on).
    systemd.sleep.settings.Sleep = {
      HibernateDelaySec = "2h"; # stay in light sleep 2h, then hibernate to disk
      SuspendState = "mem"; # plain RAM sleep (not standby) — lowest idle draw
    };
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate"; # lid close on battery
      HandleLidSwitchExternalPower = "suspend"; # lid close on charger (faster wake than hibernate)
      HandleLidSwitchDocked = "ignore"; # lid close when docked (external monitor stays on)
      IdleAction = "suspend-then-hibernate"; # idle 30min = sleep
      IdleActionSec = "30min"; # idle timeout
    };
    # ----------------------------------------------------------------------

    # ── Touchpad via libinput (all compositors) ──
    # tappingButtonMap "lrm": 1-finger left, 2-finger right, 3-finger middle.
    # middleEmulation: two-finger click also pastes (X middle-click) for terminals.
    services.libinput = {
      enable = true; # enable libinput driver
      touchpad = {
        tapping = true; # tap-to-click on
        tappingButtonMap = "lrm"; # 1/2/3 finger = left/right/middle
        naturalScrolling = false; # classic scroll direction
        disableWhileTyping = true; # avoid palm clicks while typing
        middleEmulation = true; # two-finger click = middle click
        scrollMethod = "twofinger"; # two-finger scroll
      };
    };
    # ----------------------------------------------------------------------

    # ── Wifi powersave + bluetooth ──
    # wpa_supplicant = standard stack (iwd breaks some enterprise/EAP campus
    # nets). scanRandMacAddress = anti-tracking while probing. Bluetooth:
    # A2DP audio + file transfer, battery reporting for headsets, blueman
    # tray applet for pairing GUI.
    networking.networkmanager.wifi = {
      backend = "wpa_supplicant"; # standard wifi backend
      powersave = true; # save battery on wifi
      scanRandMacAddress = true; # randomize MAC when scanning
    };
    hardware.bluetooth = {
      enable = true; # bluetooth stack
      powerOnBoot = true; # radio on after boot
      settings.General = {
        Enable = "Source,Sink,Media,Socket"; # A2DP audio + file transfer
        Experimental = true; # battery reporting for headsets
      };
    };
    services.blueman.enable = true;
    # ----------------------------------------------------------------------

    # ── NVIDIA PRIME tuning (only with the nvidia-prime profile) ──
    # Offload: dGPU fully powers off at idle (~0W). Sync (NVIDIA renders
    # everything): finegrained MUST stay off or the display dies, and the
    # offload wrapper makes no sense — both flip with syncMode. Values mirror
    # hardware-profiles.nix (equal mkDefaults merge cleanly).
    hardware.nvidia = mkIf config.hardware-profiles.nvidia-prime.enable (let
      syncMode = config.hardware-profiles.nvidia-prime.mode == "sync";
    in {
      powerManagement = {
        enable = mkDefault true; # suspend/resume VRAM handling
        finegrained = mkDefault (!syncMode); # full dGPU power-off at idle (offload only)
      };
      prime.offload.enableOffloadCmd = mkDefault (!syncMode); # `nvidia-offload <app>` wrapper
      prime.sync.enable = mkDefault syncMode;
      nvidiaSettings = mkDefault true; # nvidia-settings GUI
    });
    # ----------------------------------------------------------------------

    # ── iGPU video decode (Intel path): cheap battery playback ──
    # AMD decode comes via Mesa/RADV from the amdgpu profile — nothing needed
    # here on AMD hybrids.
    hardware.graphics.extraPackages = lib.mkIf config.hardware-profiles.intel.enable (with pkgs; [
      intel-media-driver # Broadwell+ VAAPI decode
      vaapiIntel # older Intel VAAPI
      libvdpau-va-gl # VDPAU over VAAPI bridge
    ]);
    # ----------------------------------------------------------------------

    # ── Helper tools: battery, tunables, backlight, firmware, PCI ──
    # acpi -b = battery status; powertop = tunables; brightnessctl = backlight
    # keys (also used by hyprland.nix); fwupd = firmware CLI; pciutils =
    # lspci to find PRIME BusIDs (00:02.0 -> PCI:0:2:0, 01:00.0 -> PCI:1:0:0),
    # then set hardware-profiles.nvidia-prime.intelBusID / nvidiaBusID
    # (AMD+NVIDIA hybrids: amdgpuBusID instead of intelBusID).
    environment.systemPackages = with pkgs; [
      acpi # `acpi -b` battery status
      powertop # `sudo powertop --auto-tune` tunables
      brightnessctl # backlight keys (also used by hyprland.nix)
      fwupd # `fwupdmgr` firmware CLI
      pciutils # `lspci` to find PRIME BusIDs
    ];
    # ----------------------------------------------------------------------
  };
}
