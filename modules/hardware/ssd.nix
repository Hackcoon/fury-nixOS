# ============================================================================
# ssd.nix — SSD longevity & write reduction + suspend/resume stability.
#
# Strategy: keep short-lived writes in RAM (tmpfs /tmp, zram swap, tiny
# swappiness), TRIM weekly, cap the journal, and stop systemd from freezing
# user sessions during sleep (the Wayland/Plasma resume-crash fix).
# Hibernation is NOT enabled (notes below) — needs disk swap + resume wiring.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── /tmp in RAM: spare the flash ──
  # Compiles, archives, and nixos-rebuild generate gigabytes of short-lived
  # temp files. tmpfs eliminates millions of write cycles to disk.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "20%";   # 6.4 GB ceiling on a 32GB system
  # ----------------------------------------------------------------------

  # ── Swap to compressed RAM, almost never ──
  # Swap writes degrade flash: offload swap to zram and keep the kernel from
  # swapping until absolutely necessary.
  zramSwap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 10;
  # ----------------------------------------------------------------------

  # ── Weekly TRIM + journal cap ──
  # TRIM maintains SSD lifespan; the 200M journal cap only trims old logs,
  # writing behavior is unchanged.
  services.fstrim.enable = true; # weekly TRIM for SSD health
  services.journald.extraConfig = "SystemMaxUse=200M";
  # ----------------------------------------------------------------------

  # ── smartd: disk health watchdog (parked OFF) ──
  # Near-zero CPU, warns weeks before real failure. Check alerts with
  # journalctl -t smartd. Uncomment to enable.
  # services.smartd.enable = true;
  # ----------------------------------------------------------------------

  # ── Don't freeze user sessions during sleep ──
  # Disables cgroup-based session freezing — prevents Wayland/Plasma
  # crashes after resume.
  systemd.services = {
    "systemd-suspend".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
    "systemd-hibernate".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
    "systemd-hybrid-sleep".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
  };
  # ----------------------------------------------------------------------

  # ── PARKED: scx userspace CPU scheduler (OFF) ──
  # sched_ext runs scheduling policy in userspace (6.18 kernel supports it).
  # "scx_lavd" favors interactive/gaming responsiveness: foreground apps keep
  # snappy frame pacing under load instead of competing equally with background
  # compiles, backups, and browser tabs.
  # HEAT NOTE: a different scheduler changes WHEN CPU work runs, shifting
  # thermals on an already-warm CPU (Ryzen 5 3600 here). If enabled, compare
  # temps with `btop` before/after under the same workload. Hotter or louder =
  # comment back out and rebuild — the entire rollback, no package changes
  # (the module installs its own tooling).
  # services.scx = {
  #   enable = true;
  #   scheduler = "scx_lavd";
  # };
  # ----------------------------------------------------------------------

  # ── HIBERNATION NOTES (not enabled — needs disk swap + resume wiring) ──
  # The kernel hibernates into the HIGHEST-priority swap device. zram here is
  # priority 5, so hibernation would target RAM (nonsense). To enable:
  #   1. In hardware-configuration.nix, give disk swap priority 10
  #      (swapDevices lives there, not here):
  #        swapDevices = [
  #          { device = "/dev/disk/by-uuid/25c2c9f4-..."; priority = 10; }
  #        ];
  #   2. Keep zram below it here:  zramSwap.priority = 1;
  #   3. Add to boot.kernelParams in core/boot.nix: "resume=UUID=25c2c9f4-..."
  #      and set boot.resumeDevice to the same UUID.
  # NEVER combine hibernation with randomEncryption on disk swap — the key
  # regenerates at boot, so resume becomes impossible.
  # ----------------------------------------------------------------------
}
