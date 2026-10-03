# Troubleshooting & Recovery on NixOS

An exhaustive, independently-usable reference for when NixOS goes wrong — boot failures, rollback surgery, store corruption, broken generations, emergency chroot toolkit, and the repair workflows for every other guide's failure modes. Every code block is self-contained with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual (boot, rollback, installing) · systemd-boot/GRUB recovery docs · the `nixos-enter`/`nixos-install` tooling · nix store diagnostics (`nix store verify`, `nix-store --verify`) · community repair runbooks. Commands verified on current NixOS 26.05-era tooling (`nixos-rebuild`, `nix` 2.24+ CLI style).

**Companion guides:** this is the capstone — it cross-references every other guide's troubleshooting sections and adds the recovery layer they deliberately don't.

---

## Table of Contents

 1. [The Golden Rules of NixOS Recovery](#1-the-golden-rules-of-nixos-recovery)
 2. [First Responders: Live Diagnostics](#2-first-responders-live-diagnostics)
     - [2.1 Previous-Boot Forensics (journalctl -b -1)](#21-previous-boot-forensics-journalctl--b--1)
 3. [Rollback: The 30-Second Fix](#3-rollback-the-30-second-fix)
     - [3.1 The build --flake Iterate Loop](#31-the-build---flake-iterate-loop)
 4. [When the System Won't Boot](#4-when-the-system-wont-boot)
     - [4.1 rescue.target vs init=/bin/sh](#41-rescuetarget-vs-initbinsh)
     - [4.2 GPU-Failure Recovery (per vendor)](#42-gpu-failure-recovery)
     - [4.3 Secure-Boot Verify (sbctl / lanzaboote)](#43-secure-boot-verify-sbctl--lanzaboote)
     - [4.4 Kernel Bisect (boot.kernelPackages swap)](#44-kernel-bisect-bootkernelpackages-swap)
 5. [The Emergency Chroot Toolkit](#5-the-emergency-chroot-toolkit)
6. [Store Corruption & Repair](#6-store-corruption-repair)
7. [Generation & Boot Entry Surgery](#7-generation-boot-entry-surgery)
8. [Disk Full: The NixOS Special Hell](#8-disk-full-the-nixos-special-hell)
9. [Per-Stack Failure Modes (cross-reference)](#9-per-stack-failure-modes-cross-reference)
10. [Prevention (bake resilience into config)](#10-prevention)
11. [Reference Index](#11-reference-index)

---

## 1. The Golden Rules of NixOS Recovery

1. **You cannot lose the system by breaking software.** Every previous generation boots. Hardware failure aside, every "NixOS is broken" story ends with "rolled back in 60 seconds".
2. **Never `nixos-rebuild switch` blindly when the machine matters** — `test` first (doesn't touch boot entries), or `boot` (sets default but runs current until reboot).
3. **The Nix store is append-only and immutable** — corruption is rare, and §6 covers even that.
4. **Generation ≠ boot entry ≠ configuration.** Know which layer is lying to you (§7).
5. **Keep a live USB of anything.** Any NixOS ISO can rescue any NixOS — same tools, same store format.

## 2. First Responders: Live Diagnostics

```bash
# ---- "It booted but something's wrong" ------------------------------

# What generation am I on? What's the current system path?
readlink /run/current-system          # → /nix/store/...-nixos-26.05...
nixos-version --json | head           # full version + configuration revision

# Which boot entry will fire next reboot?
efibootmgr -v | head -5               # (systemd-boot: bootctl list)

# What changed vs the previous generation? — THE killer diagnostic:
nvd diff /run/current-system /nix/store/*-nixos-26.05...*   # or:
# nix store diff-closures /run/current-system /run/booted-system

# Service-level failure:
systemctl --failed                    # the headline list
journalctl -b -p err                  # this boot's errors only
journalctl -b -1 -p err               # LAST boot's errors (compare!)

# Was it even my rebuild? Hardware events:
journalctl -b -k | grep -iE "error|fail|oom|thermal"
```

### 2.1 Previous-Boot Forensics (journalctl -b -1)

```bash
# The crashed boot is GONE from -b — interrogate it via -b -1 (and -2...):
journalctl -b -1 -p err               # previous boot, errors only
journalctl -b -1 --since "5 min ago"  # tail of the death spiral
journalctl -b -1 -k | tail -50        # last kernel lines before the hang
journalctl -b -1 -u sddm -u gdm       # display-manager death? (§4.2 GPU)
journalctl -b -1 | grep -iE "xid|amdgpu.*(ring|timeout)|i915.*(hang|reset)"
#   ↑ GPU signatures land HERE, not in -b (§9.1: Xid vs ring-timeout)

# Workflow: boot the GOOD generation (§3), then diff its -b -1 (the failed
# boot) against -b -2 (the last good one). The delta IS the bug report.
```

## 3. Rollback: The 30-Second Fix

```bash
# ---- The system still boots ------------------------------------------
sudo nixos-rebuild switch --rollback
#  → switches to the PREVIOUS generation immediately, services restart.
#  Repeat --rollback to walk further back one generation at a time.

# To a SPECIFIC generation (not just "previous"):
sudo nixos-rebuild switch --rollback-to-generation 42
# (list first: nix-env --list-generations --profile /nix/var/nix/profiles/system)

# ---- Boot-time rollback (before login) ------------------------------
# In the systemd-boot menu (reboot, hold/press at menu):
#   "NixOS - Generation 41" style entries are listed.
#   GRUB: "Advanced options" submenu holds the same.
# Pick any older generation → boots. Then (with SSH/console):
sudo nixos-rebuild switch --rollback   # make it permanent

# ---- The nuclear safety net: I broke the CURRENT gen but old
#      one boots fine; new rebuilds keep failing ----------------------
# Boot the good generation once, and rebuild from a clean slate there:
#   bootctl set-default <good-entry-id>  (systemd-boot)
# or just don't switch until the fix is found — 'nixos-rebuild build'
# never touches anything. Iterate with build/test until green.
 ```

### 3.1 The build --flake Iterate Loop

```bash
# NEVER debug with switch. The loop that can't hurt you:
nixos-rebuild build --flake /etc/nixos#nixos   # 1. evaluate + build only
# → ./result is the WOULD-BE system. Inspect it:
nvd diff /run/current-system ./result          # what WOULD change?
./result/bin/switch-to-configuration dry-activation  # what WOULD run?
sudo nixos-rebuild test --flake /etc/nixos#nixos     # 2. activate NOW,
#   boot entries UNTOUCHED — reboot returns to the old default. Break it?
#   Reboot. Try again. Only when test survives a full session:
sudo nixos-rebuild switch --flake /etc/nixos#nixos   # 3. commit it
# sudo nixos-rebuild boot --flake ...  # variant: set default, keep running
# Golden rule: build iterates (free), test probes (reversible), switch
# commits (only when green). GPU/driver experiments (§4.2) live in test.
```

## 4. When the System Won't Boot

The triage ladder, ordered by likelihood:

```bash
# ---- A. Boot loader itself works, system hangs/fails at stage N ------
# 1. Reboot → boot menu → your kernel entry with a working generation.
# 2. If ALL generations hang: edit kernel cmdline IN THE MENU:
#      systemd-boot: press 'e' on the entry; append to linux line:
#        systemd.unit=multi-user.target     # skip graphical (SDDM death)
#        systemd.unit=rescue.target         # single-user-ish
#        init=/bin/sh                       # LAST resort: raw shell
#        # debugging gold:
#        loglevel=7                         # verbose kernel
#        "rd.systemd.show_status=always"
# 3. Boot to console → §2 diagnostics.

# ---- B. Boot loader MISSING (no menu at all) --------------------------
# You're in the §5 chroot toolkit. Common root cause: UEFI entry wiped
# (Windows update, BIOS flash) or ESP damage. Repair (in chroot):
#   bootctl status                        # is the ESP mounted? entries?
#   bootctl install                       # reinstall systemd-boot files
#   # Or from NixOS side (more thorough — regenerates loader entries):
#   nixos-rebuild switch --install-bootloader   # ← also fixes entries!
#   # If the ESP itself is fine but entries vanished:
#   nixos-rebuild switch                   # regenerates systemd-boot entries
#   # NOTE: switch --install-bootloader also covers the
#   #  lanzaboote/secure-boot path (re-signs everything) — see
#   # Hardening-NixOS.md §22 for key caveats (needs your SB keys intact).

# ---- C. LUKS / password prompt issues ---------------------------------
# passphrase not asked/accepted? Boot menu edit:
#   rd.luks.name=<UUID>=cryptroot   # explicit mapping
# In chroot: check /etc/crypttab.default vs initrd config mismatch —
#   usually after changing hardware-configuration.nix (disk UUIDs!).

# ---- D. Initrd missing a driver (new hardware swap) -------------------
# Symptom: stuck at "waiting for device /dev/disk/by-label/...".
# Root cause: boot.initrd.availableKernelModules lost the driver.
# Fix in chroot: add the module (your hardware-configuration.nix!) to
#   boot.initrd.availableKernelModules; rebuild; reboot. Common after
#   SATA→NVMe moves or controller-mode changes (AHCI/RAID in BIOS).
# ```

### 4.1 rescue.target vs init=/bin/sh

| | `systemd.unit=rescue.target` | `systemd.unit=multi-user.target` | `init=/bin/sh` |
|---|---|---|---|
| What boots | kernel + minimal systemd, root shell, almost no services | full system minus graphical | NO systemd — raw shell as PID 1 |
| Root FS | mounted (ro or rw) | mounted rw | may be RO — `mount -o remount,rw /` yourself |
| Use when | service/ordering failure, need journalctl + systemctl | SDDM/GDM death, GPU/display failure (§4.2) | systemd itself broken, rescue won't start |
| Networking | off (add `systemd.unit=rescue.target ip=dhcp` for net) | on | none — static `ip` commands only |
| Exit | `systemctl default` continues boot | `systemctl isolate graphical.target` | `exec /sbin/init` (or reboot — state is fragile) |

```bash
# Append ONE of these on the kernel cmdline in the boot menu (§4-A):
#   systemd.unit=multi-user.target     # first try for GPU/display deaths
#   systemd.unit=rescue.target         # service/ordering deaths
#   init=/bin/sh                       # systemd is the patient, not doctor
```

### 4.2 GPU-Failure Recovery (per vendor)

```bash
# Symptom family: black screen / SDDM loop / freeze at "reached graphical".
# First: boot to console (systemd.unit=multi-user.target, §4.1) — then:

# ---- NVIDIA: kill modesetting, fall back to console/simpledrm --------
# In the boot menu append ONE of:
#   nomodeset                            # disables ALL KMS (nvidia+simpledrm
#                                        # text console; GUI dead but shell lives)
#   module_blacklist=nvidia,nvidia_drm    # keep KMS, drop only NVIDIA
# Then, once booted, make it stick while you fix the driver:
```

```nix
{ config, pkgs, ... }: {
  # NVIDIA triage (pick ONE, iterate with §3.1 test — never switch blind):
  # 1. Disable modesetting, keep the driver loaded (console + SSH fixable):
  # hardware.nvidia.modesetting.enable = false;
  # 2. Drop the driver entirely (Intel iGPU takes the displays):
  # services.xserver.videoDrivers = [ "modesetting" ];  # iGPU only
  # boot.blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_uvm" ];
  # 3. Hybrid laptops: force the iGPU as primary, NVIDIA off:
  # hardware.nvidia.prime = {
  #   offload.enable = true; intelBusId = "PCI:0:2:0";
  #   nvidiaBusId = "PCI:1:0:0";   # from lspci — YOUR ids!
  # };
}
```

```nix
# ---- AMD fallback (amdgpu.ppfeaturemask / DPM) ------------------------
{ ... }: {
  # Black screen on AMD (usually DPM/power-play or DC on new cards):
  # boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];  # unlock
  #   # full power-feature mask (overclocking + DPM control surface)
  # boot.kernelParams = [ "amdgpu.dpm=0" ];      # LAST resort: kill DPM
  # boot.kernelParams = [ "amdgpu.dc=0" ];       # pre-Polaris display-code
  #   # fallback (breaks HDMI audio + FreeSync — diagnostic only)
  # SDDM-loop on AMD: usually mesa/vulkan mismatch after a channel bump —
  # rollback (§3) then `nix store verify --repair` (§6), not GPU params.
}
```

```nix
# ---- Intel fallback (i915.modeset / force_probe) ----------------------
{ ... }: {
  # Black screen on Intel iGPU/Arc (usually modeset or firmware):
  # boot.kernelParams = [ "i915.modeset=1" ];    # force KMS on (vs nomodeset)
  # boot.kernelParams = [ "i915.force_probe=7d55" ];  # YOUR PCI ID from
  #   # lspci -nn — unblocks new Arc/iGPUs the kernel doesn't claim yet
  # boot.kernelParams = [ "xe.force_probe=..." ];     # Battlemage+ on the
  #   # xe driver instead of i915 — same idea, other driver name
  # Missing firmware (GuC/HuC): dmesg shows `i915 ... firmware: failed` —
  # enable: hardware.enableRedistributableFirmware = true;
}
```

### 4.3 Secure-Boot Verify (sbctl / lanzaboote)

```bash
# Lanzaboote path (Hardening §22): after ANY boot-entry weirdness —
# "signature not verified", blue-screen MOK loops, entries that vanish:
sbctl verify               # checks EVERY signed EFI binary on the ESP
sbctl status               # enrolled keys? setup mode? Secure Boot state?
bootctl status             # ESP mounted? entries present? (§4-B)

# Typical repairs (in the booted good generation or §5 chroot):
# 1. Keys rotated/BIOS reset → re-enroll: sbctl create-keys; sbctl enroll-keys -m
# 2. ESP binaries stale → rebuild re-signs: nixos-rebuild switch --install-bootloader
# 3. One unsigned leftover → sbctl verify NAMES it; delete or sbctl sign -s <file>
# Never disable Secure Boot to "fix" a verify failure — that's the alarm
# working. Fix the signature, not the alarm.
```

### 4.4 Kernel Bisect (boot.kernelPackages swap)

```nix
{ config, pkgs, ... }: {
  # Regression after a kernel bump (WiFi/GPU/suspend died)? Swap the WHOLE
  # kernel set in one line, iterate with §3.1 test:
  # boot.kernelPackages = pkgs.linuxPackages_6_6;    # LTS fallback
  # boot.kernelPackages = pkgs.linuxPackages_latest; # newest (fix landed?)
  # boot.kernelPackages = pkgs.linuxPackages_zen;    # alt scheduler test
  # boot.kernelParams = [ "acpi_osi=Linux" ];        # + ACPI quirk, often
  #   # paired with kernel swaps on laptops (suspend/backlight bugs)
}
```

```bash
# Bisect loop: latest → LTS → zen, one test-boot each. When LTS works and
# latest doesn't: pin LTS + file the regression (dmesg + journalctl -b -1
# from the FAILED boot, §2.1). Unpin after the fix lands — LTS pins rot.
```

## 5. The Emergency Chroot Toolkit

The universal rescue, from any NixOS (or even non-Nix) live USB:

```bash
# ---- 0. Boot live USB. Open a root shell. ---------------------------

# ---- 1. Identify & mount the target ---------------------------------
lsblk -f                              # find root partition (and boot/EFI!)
# For a typical encrypted layout (yours may differ — read lsblk!):
mount /dev/nvme0n1p2 /mnt             # unencrypted root
# Encrypted (LUKS):
# cryptsetup open /dev/nvme0n1p2 cryptroot
# mount /dev/mapper/cryptroot /mnt

# Subvolumes (btrfs: adjust paths — @ for /):
# mount -o subvol=@ /dev/mapper/cryptroot /mnt

# ESP + any /boot partition:
mount /dev/nvme0n1p1 /mnt/boot        # or /mnt/boot/efi — match lsblk!

# Virtual environments for a working chroot:
# NOTE: nixos-enter already bind-mounts dev/proc/sys itself — these
# manual mounts are only needed for a plain chroot without nixos-enter:
for fs in dev proc sys; do
  mount --rbind /$fs /mnt/$fs && mount --make-rslave /mnt/$fs
done

# ---- 2. Enter ----------------------------------------------------------
nixos-enter                           # ← THE tool: chroots AND activates
                                      # the installed system's environment
# (from non-Nix live media: first run:
#   curl -L https://nixos.org/nix/install | sh
#   nix-env -iA nixos.nixos-enter -f <nixpkgs-channel>
#  ... or simpler: use a NixOS ISO. Always simpler.)

# ---- 3. Inside: you have the FULL installed toolchain ----------------
nixos-rebuild switch --rollback       # try the easy fix first
# Edit configs, rebuild with 'test' until healthy, THEN 'switch'.
# Secure boot note: rebuilding in chroot can't test-boot; verify with
# 'nixos-rebuild build' + inspect /nix/store/*-systemd before switching.

# ---- 4. Unmount cleanly ------------------------------------------------
exit                                  # leave chroot
umount -R /mnt/boot                   # recursive unmounts
umount -R /mnt
reboot
```

## 6. Store Corruption & Repair

Rare — the store is designed against it — but disks die:

```bash
# ---- Diagnosis --------------------------------------------------------
nix store verify --all --no-trust --repair-dry-run  # see the damage
#    (older syntax: nix-store --verify --check-contents --repair-dry-run)

# Common finding: ONE path with checksum mismatch (bitrot on old SSD):
# → --repair fetches from cache.nixos.org if available!

# ---- Repair options, escalating ---------------------------------------
nix store verify --repair --all       # fix what's fetchable
# Path not on any binary cache (your own builds!):
#   1. Which generations reference it?
find /nix/var/nix/profiles -type l -lname '*<path-hash>*'
#   2. If unreferenced by anything you care about: it's already
#      effectively dead — nix-collect-garbage will drop the husk.
  #   3. If NEEDED: delete + rebuild that path (only works if
  #      unreferenced — live GC roots refuse deletion, check
  #      `nix-store --query --roots` first):
  nix store delete /nix/store/<path>
nixos-rebuild switch                  # rebuilds the missing piece

# ---- When the store DB itself is corrupted ---------------------------
# Symptom: "error: database disk image is malformed" (sqlite):
# Stop the daemon FIRST — the DB cannot be rebuilt while it holds it open:
systemctl stop nix-daemon
mv /nix/var/nix/db /nix/var/nix/db.broken
# Nix auto-rebuilds the DB from /nix/store metadata on next daemon start
# (lose: registration metadata like deriver links. Keep: everything else.)
systemctl start nix-daemon
```

**Btrfs/ZFS note:** `btrfs scrub` / `zpool scrub` catch corruption BELOW Nix's layer — a store `--verify` after scrub failure will show you the blast radius.

## 7. Generation & Boot Entry Surgery

```bash
# ---- Understand the three layers --------------------------------------
# 1. /nix/var/nix/profiles/system-generation-N  ← profiles (GC roots)
# 2. /nix/var/nix/profiles/system → the DEFAULT profile
# 3. ESP entries (loader/entries/entry-nixos-generation-N.conf)

nix-env --list-generations --profile /nix/var/nix/profiles/system
#    old syntax still fine: nix-env -p /nix/var/nix/profiles/system --list-generations

# Point the default profile at an arbitrary existing generation
# (what --rollback automates):
nix-env --profile /nix/var/nix/profiles/system \
  --switch-generation 41
# Regenerate boot entries to match:
/nix/var/nix/profiles/system/bin/switch-to-configuration switch

# Purge old generations (both GC + entries):
sudo nix-collect-garbage --delete-older-than 30d
#  → this ALSO removes boot menu entries for collected generations.

# GC without deleting generations (store bloat, not gen bloat):
sudo nix-collect-garbage -d           # optimize + collect
nix store gc                          # new syntax

# Finding what pins a path you want gone:
nix-store --query --roots /nix/store/<path>
```

## 8. Disk Full: The NixOS Special Hell

```bash
# Symptom: rebuild fails with "no space left on device" — but df / looks fine!

# The NixOS subtlety: /nix often fills while / shows 20% free (same
# partition, but /nix is huge) OR the build用户 tmp fills:
df -h /nix /tmp

# ---- Free space ladder -------------------------------------------------
# 1. Old generations + closures (the big win, usually 10-50GiB):
sudo nix-collect-garbage --delete-older-than 7d

# 2. Build detritus (failed builds kept):
rm -rf /tmp/nix-build-*                # if /tmp not tmpfs
nix store gc

# 3. The profile-only GCs (per-user environments):
nix-env --delete-generations old      # your own profile
# root + other users matter too: sudo -u eachuser nix-env --...

# 4. Booted-vs-current trap: the CURRENTLY BOOTED generation can't be
#    collected until you reboot into something newer. Reboot after GC.

# 5. Last resort ordering (safe → risky):
nix store optimise                     # dedupe (rarely frees on modern fs)
# Never: delete /nix/store paths by hand. It's GC-managed; §6 if stale.
```

**Prevention:** your config already GCs weekly (30d) — plus `boot.loader.systemd-boot.configurationLimit = 10` (Customization guide §2.2) caps entry bloat.

## 9. Per-Stack Failure Modes (cross-reference)

The 60-second index into the library's troubleshooting sections:

| Stack | Symptom family | Guide § |
|---|---|---|
| Boot / secure-boot | Lanzaboote signature errors, blue-boot loops | Hardening §22, this guide §4-B |
| KVM/libvirt | VM won't start, permissions | Virtualization §19 |
| GPU passthrough | Black screen, vfio binds | Virtualization §19, LG §11 |
| Looking Glass | No display, size mismatches | Looking-Glass §11 |
| KDE/Qt/GTK | Theme half-applied | Customization §15 |
| Steam/Proton | Launch failures, FPS | Gaming §13 |
| Tor | Bootstrap stuck | Anonymity §10 |
| sops/agenix | Won't decrypt, timing | Secrets §10 |
| VPN/WireGuard | Leaks, no traffic | Networking §12 |
| Builds | Hash mismatch, patch drift | Packaging §11 |
| OOM/thermal | Random freezes | Gaming §4 + `journalctl -k` (§2 here) |
| GPU hang (desktop freezes, SSH alive) | dmesg signatures | §9.1 here |

### 9.1 GPU Hang Signatures (dmesg: amdgpu ring timeout vs NVIDIA Xid)

```bash
# SSH in (or boot multi-user.target, §4.1) — the GPU tells you WHO it is:
dmesg | grep -iE "amdgpu|nvidia|NVRM|i915|xe " | tail -30

# ---- AMD: ring timeouts (scheduler stuck, usually power/thermal/VRAM) --
# [drm:amdgpu_job_timedout] *ERROR* ring gfx_0.0.0 timeout, signaled ...
# [amdgpu] *ERROR* GPU Recovery ... ring gfx timeout
# Fix ladder: 1) thermals + PSU rails (sensors, journalctl -k thermal)
#   2) amdgpu.ppfeaturemask / DPM fallback (§4.2 AMD)
#   3) kernel bisect (§4.4 — amdgpu regressions ride kernel bumps)
#   4) VRAM pressure: lower game textures / close GPU ML jobs

# ---- NVIDIA: Xid codes (the driver numbers every failure) --------------
# NVRM: Xid (PCI:0000:01:00): 79, pid='<X>', GPU has fallen off the bus
# NVRM: Xid ... 61, ... 45, ... 13 ... (each code = a failure class)
# Fix ladder: 1) NOTE THE NUMBER — Xid 79 = bus/power (reseat, PSU cable,
#   disable PCIe ASPM: pcie_aspm=off); Xid 61/45 = driver/firmware;
#   Xid 13 = userspace (game/proton, not hardware)
#   2) nvidia.modesetting off + driver re-probe (§4.2 NVIDIA)
#   3) kernel + driver version matrix (nvidiaPackages.stable vs .beta)
# Lookup: NVIDIA Xid list (docs.nvidia.com) — quote the CODE in reports.

# ---- Intel: hangcheck/reset (i915/xe) -----------------------------------
# i915 ... GPU HANG: ecode ... / xe ... gt reset
# Fix ladder: 1) firmware (hardware.enableRedistributableFirmware, §4.2)
#   2) force_probe for new IDs 3) kernel bisect (§4.4)
```

## 10. Prevention

```nix
{ config, pkgs, ... }: {
  # Resilience bakes in BEFORE anything breaks:

  # Keep bootable history (rollback reach):
  boot.loader.systemd-boot.configurationLimit = 10;

  # Scheduled GC keeps the full-disk failure away (you have this):
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # 'test' before 'switch' culture + one alias to reinforce it:
  # (Customization guide §9 shellAliases)
  #   nixtest = "sudo nixos-rebuild test --flake /etc/nixos#nixos";

  # A bootable snapshot of EVERY rebuild — boot fallback per generation
  # is automatic; additionally keep at least one known-good generation
  # UN-collected (raise the GC age, or pin it):
  #   nix.gc.options = "--delete-older-than 30d --keep 5";

  # Monitoring for the slow failures (disk, memory, temps):
  environment.systemPackages = with pkgs; [
    nvd      # nixos diff — know what a rebuild changes (§2 here)
    nix-output-guard  # no — nix-output-monitor for builds:
    nix-output-monitor
    smartmontools     # disk health: smartctl -a /dev/nvme0n1
  ];
  services.smartd.enable = true;      # early warnings to journal
}
```

## 11. Reference Index

- NixOS manual — rollback & maintenance: <https://nixos.org/manual/nixos/stable/#sec-changing-config>
- `nixos-enter` source: `nixos/modules/installer/tools/tools.nix`
- systemd-boot recovery: `man bootctl`
- `nix store verify`: <https://nixos.org/manual/nix/latest/command-ref/new-cli/nix3-store-verify>
 - nvd (diff tool): <https://gitlab.com/khumba/nvd>
 - sbctl (Secure Boot verify): <https://github.com/Foxboron/sbctl> + Hardening §22 (lanzaboote)
 - NVIDIA Xid error list: <https://docs.nvidia.com/deploy/xid-errors/>
 - amdgpu diagnostics: `dmesg` ring-timeout lines + kernel `amdgpu.ppfeaturemask`, `amdgpu.dpm` params
- Arch chroot guide (the mechanics are universal): <https://wiki.archlinux.org/title/Chroot>
- All guides in this library: each §"Troubleshooting" feeds §9 here
