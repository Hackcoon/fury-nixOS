# ============================================================================
# power-modes.nix — powersave / balanced / performance presets for laptops.
#
# Switch with: laptop.powerMode = "powersave" | "balanced" | "performance";
# (in configuration.nix, then rebuild). Default: "balanced".
#
# HOW IT WORKS: TLP already switches AC vs BAT automatically by power source.
# This module layers a *mode* on top, rewriting the TLP AC/BAT tables per
# preset so one rebuild flips the whole machine's behavior.
#   - powersave:   max battery. Boost off everywhere, low-power platform
#                  profile, most aggressive PCIe/USB/disk savings. Lectures,
#                  flights, long days away from a charger.
#   - balanced:    the sane default. Full speed on AC (boost on), aggressive
#                  savings on battery (boost off, ASPM powersupersave).
#   - performance: max speed. Performance governor + boost on AC, platform
#                  "performance", ASPM performance. Drains fast — charger +
#                  PRIME sync mode territory (gaming).
#
# BATTERY LONGEVITY (charge limits): all modes cap charging at 80% (start 75%)
# via TLP thresholds. Lithium pinned at 100% degrades fast — 80% roughly doubles
# cycle life. Only works on laptops with a supported EC (ThinkPad/Legion/Dell/
# ASUS...); harmless no-op elsewhere. For a trip, raise temporarily:
#     services.tlp.settings.STOP_CHARGE_THRESH_BAT0 = 100;
#
# NVIDIA NOTE: with PRIME "sync" (NVIDIA primary) the dGPU is ALWAYS powered —
# no CPU preset fixes that; it's the cost of max fps. For true battery life,
# flip PRIME to offload: hardware-profiles.nvidia-prime.mode = "offload".
#
# AMD NOTE: governors stay "powersave" on battery in every mode — with
# amd_pstate active the CPU still boosts when needed; "powersave" just lets it
# clock down aggressively at idle, which is where battery goes to die.
# Boost on/off (CPU_BOOST_*) is the real lever.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.laptop;
  isIntel = config.hardware-profiles.intel.enable;
in
{
  # ── Options: the power preset ──
  options.laptop.powerMode = mkOption {
    type = types.enum [ "powersave" "balanced" "performance" ];
    default = "balanced";
    description = "Laptop power preset: max battery, sane default, or max speed.";
  };
  # ----------------------------------------------------------------------

  config = mkIf cfg.enable (mkMerge [
    # ── Common to all modes: watchdog off, charge caps, wifi default ──
    # NMI watchdog: small idle saving, zero cost. Charge caps double cycle
    # life (see header). BAT1 covers two-battery laptops. WIFI_PWR_ON_BAT=on:
    # wifi cards that hate powersave drop SSH/scans — override with "off" in
    # configuration.nix if that happens. upower here backs the battery widget
    # (harmless headless; laptop.nix owns the thresholds).
    {
      services.upower.enable = true;
      services.tlp.settings = {
        NMI_WATCHDOG = 0;
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
        WIFI_PWR_ON_BAT = "on";
      };
    }
    # ----------------------------------------------------------------------

    # ── POWERSAVE: every watt counts ──
    # Key groups (same groups repeat in balanced/performance):
    #   CPU_*      = clock governor + turbo boost on AC vs battery.
    #   PLATFORM_* = firmware platform profile (fan/thermal policy).
    #   PCIE_ASPM_ = PCIe link power saving (deeper = less idle watts).
    #   RADEON_*   = AMD iGPU power profile + dynamic power state.
    #   WIFI/SOUND = radio + audio-chip idle power.
    #   DISK/SATA  = HDD APM parking + SATA link power (matters on spinning
    #                disks; near-noop on pure NVMe machines).
    #   RUNTIME_PM/USB = autosuspend idle USB/PCI devices.
    (mkIf (cfg.powerMode == "powersave") {
      services.tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = 0; # no turbo even on charger — cool + quiet
        CPU_BOOST_ON_BAT = 0; # no turbo unplugged — biggest battery lever
        PLATFORM_PROFILE_ON_AC = "low-power"; # quiet fans, low thermal ceiling
        PLATFORM_PROFILE_ON_BAT = "low-power";
        PCIE_ASPM_ON_AC = "powersave"; # PCIe link savings even on charger
        PCIE_ASPM_ON_BAT = "powersupersave"; # deepest link power saving
        RADEON_POWER_PROFILE_ON_AC = "low"; # clamp AMD iGPU clocks down
        RADEON_POWER_PROFILE_ON_BAT = "low";
        RADEON_DPM_STATE_ON_AC = "battery"; # battery DPM table even on AC
        RADEON_DPM_STATE_ON_BAT = "battery";
        WIFI_PWR_ON_AC = "on"; # wifi powersave on charger too (max savings)
        SOUND_POWER_SAVE_ON_AC = 1; # power down audio chip when idle (secs)
        SOUND_POWER_SAVE_ON_BAT = 1;
        DISK_APM_LEVEL_ON_AC = "128"; # allow disk head parking/spindown
        DISK_APM_LEVEL_ON_BAT = "128";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm"; # partial SATA slumber
        SATA_LINKPWR_ON_BAT = "min_power"; # deepest SATA slumber
        RUNTIME_PM_ON_AC = "auto"; # autosuspend idle PCI/USB devices
        RUNTIME_PM_ON_BAT = "auto";
        USB_AUTOSUSPEND = 1; # suspend idle USB (set 0 if mouse stutters)
      } // optionalAttrs isIntel {
        # Intel HWP dynamic boost (Intel-only; AMD ignores these keys).
        CPU_HWP_DYN_BOOST_ON_AC = 0;
        CPU_HWP_DYN_BOOST_ON_BAT = 0;
      };
    })
    # ----------------------------------------------------------------------

    # ── BALANCED: fast on AC, frugal on battery (default) ──
    # Same key groups as powersave (see above): aggressive on charger (full
    # turbo, auto iGPU, wifi full-speed), saving values on battery. Only deltas
    # from powersave are commented — uncommented keys behave as described there.
    (mkIf (cfg.powerMode == "balanced") {
      services.tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave"; # amd-pstate scales via EPP; boost does the work
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = 1; # full turbo when plugged in
        CPU_BOOST_ON_BAT = 0; # no turbo unplugged — biggest battery lever
        PLATFORM_PROFILE_ON_AC = "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
        RADEON_POWER_PROFILE_ON_AC = "auto";
        RADEON_POWER_PROFILE_ON_BAT = "low";
        RADEON_DPM_STATE_ON_AC = "balanced";
        RADEON_DPM_STATE_ON_BAT = "battery";
        WIFI_PWR_ON_AC = "off"; # full wifi speed on charger
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 1;
        DISK_APM_LEVEL_ON_AC = "254"; # max perf on charger
        DISK_APM_LEVEL_ON_BAT = "128";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "min_power";
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";
        USB_AUTOSUSPEND = 1; # set 0 if the mouse stutters on battery
      } // optionalAttrs isIntel {
        CPU_HWP_DYN_BOOST_ON_AC = 1;
        CPU_HWP_DYN_BOOST_ON_BAT = 0;
      };
    })
    # ----------------------------------------------------------------------

    # ── PERFORMANCE: wall power go brrr ──
    # Full speed everywhere: turbo + high iGPU clocks + no autosuspend on AC,
    # nearly the same on battery (drains fast). Gaming/compile mode — expect
    # heat + fan noise. Same key groups as powersave; deltas noted.
    (mkIf (cfg.powerMode == "performance") {
      services.tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave"; # still clock down at idle unplugged
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 1; # turbo even on battery — drains fast (opt-in cost)
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "balanced";
        PCIE_ASPM_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersave";
        RADEON_POWER_PROFILE_ON_AC = "high";
        RADEON_POWER_PROFILE_ON_BAT = "auto";
        RADEON_DPM_STATE_ON_AC = "performance";
        RADEON_DPM_STATE_ON_BAT = "balanced";
        WIFI_PWR_ON_AC = "off";
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 0;
        DISK_APM_LEVEL_ON_AC = "254";
        DISK_APM_LEVEL_ON_BAT = "254";
        SATA_LINKPWR_ON_AC = "max_performance";
        SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";
        USB_AUTOSUSPEND = 0; # no USB latency for gaming mice/controllers
      } // optionalAttrs isIntel {
        CPU_HWP_DYN_BOOST_ON_AC = 1;
        CPU_HWP_DYN_BOOST_ON_BAT = 1;
      };
    })
    # ----------------------------------------------------------------------
  ]);
}
