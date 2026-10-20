# Kernel & Hardware on NixOS

An exhaustive, independently-usable reference for kernel and hardware control on NixOS — choosing and customizing kernels, patchsets, undervolting/overclocking (AMD P-state, corectrl), fan curves and thermals, sensors, I/O schedulers, power management, and per-hardware enablement. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual (kernel, hardware) · nixpkgs module sources (`hardware/cpu/*`, `services/hardware/thermald.nix`, `services/hardware/irqbalance.nix`, `services/system/earlyoom.nix`, `services/misc/ananicy.nix`, `boot/kernel.nix` — extraModulePackages/structuredExtraConfig verified) · AMD P-state kernel docs · corectrl/scx docs · community Ryzen tuning knowledge. Schema verified against nixpkgs release-26.05; cross-check <https://search.nixos.org/options> before adopting.

**Your reference hardware:** Ryzen 5 3600 (Zen 2, 6c/12t) + GTX 1660 SUPER — examples use it, but every section carries the AMD/Intel dGPU/iGPU variants.

**Companion guides:** `Hardening-NixOS.md` §2 (kernel hardening — the security angle of the same knobs), `Gaming-NixOS.md` §12 (the perf angle).

---

## Table of Contents

1. [Kernel Selection & Versions](#1-kernel-selection-versions)
2. [Kernel Customization (params, modules, config)](#2-kernel-customization)
3. [Custom Kernel Packages & Patchsets](#3-custom-kernel-packages-patchsets)
4. [AMD CPU Tuning (P-state, undervolt, corectrl)](#4-amd-cpu-tuning)
5. [Intel CPU Tuning (thermald, P-states)](#5-intel-cpu-tuning)
6. [Thermals, Fans & Sensors](#6-thermals-fans-sensors)
7. [Memory & Swap Discipline](#7-memory-swap-discipline)
8. [Storage & I/O (schedulers, rotation, TRIM)](#8-storage-io)
9. [Power Management (desktops & laptops)](#9-power-management)
10. [Per-Hardware Enablement Cheatsheet](#10-per-hardware-enablement-cheatsheet)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference Index](#12-reference-index)

---

## 1. Kernel Selection & Versions

```nix
{ config, pkgs, ... }: {
  # The default on stable is fine for 99% of use. Know the ladder:

  # Default (tracked by your nixpkgs pin — currently 6.18.x era on 26.05):
  boot.kernelPackages = pkgs.linuxPackages;

  # Newest stable (faster driver/hw support — minor breakage risk):
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # LTS line (max compatibility):
  # boot.kernelPackages = pkgs.linuxPackages_6_12;   # per-release naming

  # Zen kernel (desktop/latency-tuned — gamers like it):
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # XanMod etc. live in flakes/torrents of opinion — same mechanism as §3.

  # The RULE for mixing: everything that builds kernel modules
  # (kvmfr! nvidia! xpadneo!) MUST come from the SAME kernelPackages:
  #   boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];  ✓
  # Passing pkgs.linuxPackages_latest.kvmfr while running default = refuse.
}
```

## 2. Kernel Customization

### 2.1 Command line

```nix
{ config, ... }: {
  boot.kernelParams = [
    # --- verified-good desktop params (you have most already) -----------
    "quiet" "loglevel=3"            # Customization §2
    "preempt=full"                  # Gaming §12 — input latency
    "amd_iommu=on" "iommu=pt"       # Virtualization §4 — passthrough

    # --- memory ----------------------------------------------------------
    "hugepagesz=2M" "hugepages=8192" # Virtualization §5.3 (remove if unused!)

    # --- debugging (turn ON when hunting §11 problems) ------------------
    # "boottrace"
  ];

  # Blacklist modules you never want autoloaded (hardening §5 pattern):
  boot.blacklistedKernelModules = [
    # "btusb"       # bluetooth
    # "thunderbolt" # TB security
  ];
}
```

### 2.2 Module loading order

```nix
{ config, ... }: {
  # Modules loaded at INITRD time (before root mount — GPU/IOMMU critical):
  boot.initrd.kernelModules = [ "kvmfr" ];    # Looking Glass §4

  # Modules loaded during normal boot:
  boot.kernelModules = [ "kvm_amd" "vfio_pci" ];

  # out-of-tree modules MUST declare here to be built against your kernel:
  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
}
```

### 2.3 Kernel .config (structuredExtraConfig)

```nix
{ config, pkgs, lib, ... }: {
  # Everything in boot.kernelPackages can carry config overrides via
  # the override mechanism (Hardening §2 uses this for linux-hardened).

  # The real pattern — configure via .override on the kernel pkg:
  # NOTE: `pkgs.linux_latest` does not exist — use a versioned attr
  # (`pkgs.linux_6_18`) or `pkgs.linuxPackages_latest` for the set:
  boot.kernelPackages =
    (pkgs.linuxPackagesFor (pkgs.linux_6_18.override {
      structuredExtraConfig = with lib.kernel; {
        # Format: OPTION = yes/no/module/freeform "str";
        # PREEMPT = lib.mkForce yes;
        # SECURITY_LOCKDOWN_LSM = lib.mkForce yes;   # hardening §2 style
        KVM_AMD = module;
      };
      # Patches ride along here too:
      kernelPatches = [
        {
          name = "custom-tweak";
          patch = null;
          extraStructuredConfig = with lib.kernel; { /* ... */ };
        }
      ];
    }));
}
```

## 3. Custom Kernel Packages & Patchsets

The full custom kernel recipe (Hardening-NixOS.md §2's hardened patchset is this same pattern):

```nix
{ config, pkgs, lib, ... }: {
  # When you need a specific source + specific config + patches:
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor (pkgs.linux.override {
    # modDirVersion & src must align with your kernel source:
    modDirVersion = "6.18.0";
    src = pkgs.fetchurl {
      url = "mirror://kernel/linux/kernel/v6.x/linux-6.18.tar.xz";
      hash = "sha256-...";
    };
    structuredExtraConfig = with lib.kernel; {
      # Your custom config knobs, e.g. for the gaming/latency crowd:
      PREEMPT = lib.mkForce yes;
      HZ = lib.mkForce (freeform "1000");   # 1000Hz timer — latency
    };
    kernelPatches = [
      # Community patchsets land here, e.g.:
      # pkgs.kernelPatches.bridge_stp_helper        # nixpkgs built-ins
      # pkgs.kernelPatches.request_key_helper
      # {
      #   name = "custom-patch";
      #   patch = ./patches/my-kernel-tweak.patch;
      # }
    ];
  }));
}
```

## 4. AMD CPU Tuning

Your 3600 and any future AMD silicon:

```nix
{ config, pkgs, lib, ... }: {
  # ---- Microcode (you have this — the table stakes) ---------------------
  hardware.cpu.amd.updateMicrocode = true;   # fixes errata, perf-waifs

  # ---- amd_pstate driver -------------------------------------------------
  # Zen2 uses acpi-cpufreq + CPPC; Zen3+ prefer amd-pstate/epp.
  # FORCE the modern driver where the default is conservative:
  boot.kernelParams =
    lib.optionals (lib.versionAtLeast
      (lib.getVersion config.boot.kernelPackages.kernel) "6.3")
    [ "amd_pstate=active" ];
  # 'active' = amd_pstate_epp (energy-aware, best desktop feel)
  # 'guided'/'passive' = more governor-controlled
  # Check: cat /sys/devices/system/cpu/amd_pstate/status
  # (Zen2/3600: driver won't load — acpi-cpufreq is FINE there.)

  # ---- The undervolt/curve-optimizer tool --------------------------------
  programs.corectrl = {
    enable = true;

    # corectrl needs its helper daemon + polkit; the module wires it.
    # Usage: set per-core Curve Optimizer (Zen3+) or PBO offsets (Zen2
    # via BIOS more reliable), GPU clocks, fan curves — GUI.
  };
  # NOTE: on Zen2 (3600) undervolting is a BIOS PBO/Vcore affair —
  # corectrl still manages GPU + monitoring. Zen3/4/5: curve optimizer
  # per-core from the GUI, verified by built-in stress tests.

  # ---- systemd governor default (pre-corectrl) ---------------------------
  powerManagement.cpuFreqGovernor = "schedutil";
  # schedutil = kernel-native, the right default for mixed desktop loads.

  # ---- Sensors: k10temp (in-tree) + zenpower (out-of-tree, finer) --------
  boot.kernelModules = [ "k10temp" ];  # Zen temp/voltage — verify: sensors | grep k10temp
  # boot.extraModulePackages = [ config.boot.kernelPackages.zenpower ];  # per-core + SVI2
  # boot.kernelModules = [ "zenpower" ];  # then sensors shows zenpower-pci-*
  # Ryzen SMU (advanced: curve/power-table introspection, ryzenadj/ryzen_smu):
  # boot.extraModulePackages = [ config.boot.kernelPackages.ryzen-smu ];  # /dev/ryzen_smu
  # environment.systemPackages = [ pkgs.ryzenadj ];  # ryzenadj --stapm-limit-fast=X (laptops!)
  # Verify SMU: dmesg | grep -i smu; ls /dev/ryzen_smu
}
```

## 5. Intel CPU Tuning

```nix
{ config, pkgs, ... }: {
  hardware.cpu.intel.updateMicrocode = true;   # intel-ucode (errata + MDS/TAA microcode)

  # Thermald — Intel's official thermal daemon (caps throttling damage,
  # REQUIRED-ish for laptops, nice for desktops under sustained loads):
  services.thermald.enable = true;   # AMD hosts: LEAVE OFF (no Intel DTS — useless)

  # intel_pstate driver (HWP): active=HWP-hinted (default, best); passive=acpi-cpufreq-like:
  # boot.kernelParams = [ "intel_pstate=active" ];
  # EPP hint is sysfs not sysctl: echo balance_performance > /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference
  powerManagement.cpuFreqGovernor = "powersave";   # with intel_pstate, powersave+HWP = dynamic boost

  # RAPL (Running Average Power Limit — Intel power caps + monitoring):
  boot.kernelModules = [ "intel_rapl_common" "intel_rapl_msr" ];
  environment.systemPackages = with pkgs; [ powertop ];  # powertop shows RAPL watts
  # Verify: ls /sys/class/powercap/intel-rapl*; cat /sys/class/powercap/intel-rapl:0/energy_uj

  # i915 (pre-Arc) / Xe (Arc+) GuC + HuC firmware — REQUIRED for QSV low-power encode:
  # (needs enableRedistributableFirmware=true §10 to even load the blobs):
  boot.kernelParams = [
    "i915.enable_guc=2"      # 2=GuC+Huc on i915 (Gen11+ low-power H.264/HEVC)
    # "xe.enable_guc=2"      # Arc/dGPU on xe driver instead (kernel 6.8+)
  ];
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver intel-compute-runtime vpl-gpu-rt  # iHD + OpenCL + VPL (§10)
  ];
  # Verify: dmesg | grep -E 'GuC|HuC|i915.*firmware'; vainfo | grep -i low-power
}
```

## 6. Thermals, Fans & Sensors

```nix
{ config, pkgs, ... }: {
  # ---- Read every sensor (lm_sensors + nvme + GPU tops) --------------------
  environment.systemPackages = with pkgs; [
    lm_sensors           # sensors — the viewer (k10temp/coretemp/nct6775)
    nvme-cli             # nvme smart-log /dev/nvme0 — SSD temps (not in lm_sensors!)
    # stress-ng           # heat it up and watch temps — validates cooling
    # radeontop           # AMD GPU load/temp (needs video group)
    # intel-gpu-tools     # intel_gpu_top (Intel iGPU/dGPU)
  ];
  # One-time sensor detection (persists):
  #   sudo sensors-detect --auto
  # Verify: sensors; nvme smart-log /dev/nvme0n1 | grep -i temp; ls /sys/class/hwmon/

  # ---- Thunderbolt (bolt — authorize, don't auto-accept) -------------------
  services.hardware.bolt.enable = true;   # boltd + boltctl (GNOME/KDE widget path)
  # Verify: boltctl list; boltctl authorize <uuid>  # one-shot
  # boltctl enroll <uuid>  # persistent; security.level in BIOS should be user/secure
  # Hardening §5 blacklists thunderbolt when unused — ENABLE bolt only if you USE docks.

  # ---- Fan control ----------------------------------------------------------
  # With corectrl (§4) you get per-GPU fan curves. For CASE fans:
  # hwmon-based: fancontrol (lm_sensors) — declare via config file:
  # environment.etc."fancontrol".text = ''
  #   INTERVAL=10
  #   DEVNAME=hwmon3    # from sensors -u; verify each boot!
  #   FCTEMPS=hwmon3/pwm1=hwmon3/temp1_input
  #   MINTEMP=hwmon3/pwm1=40
  #   MAXTEMP=hwmon3/pwm1=80
  #   MINSTART=hwmon3/pwm1=60
  #   MINSTOP=hwmon3/pwm1=30
  # '';
  # (motherboard RGB/fan hubs often need vendor tools — check nixpkgs
  #  for your board family first.)

  # ---- The OOM safety net -----------------------------------------------------
  services.earlyoom = {
    enable = true;
    # Kill the biggest memory hog BEFORE the kernel OOM-panics:
    freeMemThreshold = 5;         # % — act at 5% free
    freeMemKillThreshold = 2;    # % — kill someone at 2%
    enableNotifications = true;   # desktop notify
  };
}
```

## 7. Memory & Swap Discipline

```nix
{ config, ... }: {
  # Your config already has the winning combo — the reference version:
  zramSwap = {
    enable = true;
    # algorithm: "zstd" is default on modern; lzo for very old CPUs:
    # algorithm = "zstd";
    # size relative to RAM: 50% default is sane:
    # memoryPercent = 50;
  };
  boot.kernel.sysctl = {
    # NOTE: with zram enabled above the zram-correct value is 180 (compressed
    # RAM swap wants aggressive paging INTO it) — 10 starves zram and
    # contradicts the swapless `vm.swappiness = 0` posture in Hardening §4
    # (pick one: 0 swapless, 180 zram, never 10 with zram):
    "vm.swappiness" = 180;
    "vm.vfs_cache_pressure" = 50;   # keep inode/dentry cache honest
    # NOTE: was 2147483642 — overflows/rolls back on kernels clamping to
    # INT_MAX-adjacent ranges; the sane hardened ceiling is 1048576
    # (hardened_malloc + games both happy; Gaming §12):
    "vm.max_map_count" = 1048576;
  };
  # NO disk swap on an SSD system with zram — §8's write-avoidance.
}
```

## 8. Storage & I/O

```nix
{ config, ... }: {
  # ---- Scheduler per device class ------------------------------------------
  # Verify defaults: cat /sys/block/nvme0n1/queue/scheduler
  services.udev.extraRules = ''
    # NVMe: none is best (multiqueue, lowest latency):
    ACTION=="add|change", KERNEL=="nvme[0-9]*", \
      ATTR{queue/scheduler}="none"
    # SATA SSD: bfq for interactive fairness / or none:
    ACTION=="add|change", KERNEL=="sd[a-z]", \
      ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
    # Rotational rust: bfq (desktop) — mq-deadline for servers:
    ACTION=="add|change", KERNEL=="sd[a-z]", \
      ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # ---- TRIM (you have fstrim — the alternatives for reference) -----------
  services.fstrim.enable = true;      # weekly batch — simplest, fine
  # Continuous alternative (btrfs/ext4 online discard):
  # ...mount option "discard" in hardware-configuration — heavier, less recommended.

  # ---- I/O priorities for snappiness ---------------------------------------
  # ananicy — auto-renices known desktop apps (the "feels smooth" daemon):
  services.ananicy = {
    enable = true;
    # settings stick to package defaults; extraRules attrset for customs:
    # extraRules = [ { type = "game"; nice = -10; } ];   # format per module
  };
}
```

## 9. Power Management

```nix
{ config, pkgs, ... }: {
  # Desktop that mostly idles (yours):
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";   # AMD Zen2/3 desktop; Intel §5 uses powersave+HWP
    powertop.enable = false;   # powertop --auto-tune breaks mice/USB autosuspend;
                               # MEASURE-ONLY on desktops (powertop --html), never --auto-tune.
  };

  # Laptop additions:
  # services.logind.extraConfig = ''
  #   HandleLidSwitch=suspend-then-hibernate
  # '';
  # PICK EXACTLY ONE — TLP vs power-profiles-daemon vs auto-cpufreq CONFLICT
  # (nixpkgs ASSERTS: ppd+tlp and ppd+auto-cpufreq refuse eval together):
  # services.tlp.enable = true;   # ThinkPad/Intel-laptop king: charge thresholds + BAT/AC split
  # services.power-profiles-daemon.enable = true;  # GNOME/KDE-integrated slider (balanced/power-saver/performance)
  # services.auto-cpufreq.enable = true;  # AMD-laptop favorite: auto governor+EPP (disable TLP first!)

  # ---- Laptop AMD vs Intel power (prescriptive) ---------------------------
  # AMD Ryzen laptop (Framework/Legion AMD): auto-cpufreq + amd_pstate=active +
  #   power-profiles-daemon OFF + thermald OFF (Intel-only). Add ryzenadj for STAPM caps.
  # Intel laptop (XPS/ThinkPad Intel): TLP (or ppd if GNOME) + thermald ON +
  #   intel_pstate=active + GuC/HuC (§5). powertop --auto-tune NEVER with TLP
  #   (both fight over /sys USB/autosuspend — pick TLP, use powertop read-only).
}
```

## 10. Per-Hardware Enablement Cheatsheet

```nix
{ config, pkgs, ... }: {
  # The "new machine checklist" — what to flip per vendor:

  # ---- CPU --------------------------------------------------------------
  hardware.cpu.amd.updateMicrocode = true;      # OR intel (§4-5)

  # ---- GPU ---------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;        # gaming/Steam; false on pure servers
    extraPackages = [ ];      # vendor §Gaming 6.x additions
  };

  # ---- Firmware at large (linux-firmware per vendor) -------------------------
  # NOTE: `hardware.enableAllFirmware` is deprecated — use:
  hardware.enableRedistributableFirmware = true;   # linux-firmware blobs for ALL below
  # Per-vendor what that blob actually loads:
  # AMD CPU: amd-ucode (via hardware.cpu.amd.updateMicrocode §4)
  # Intel CPU: intel-ucode (via hardware.cpu.intel.updateMicrocode §5)
  # AMD GPU: amdgpu PSP/SMC/DMCU + VCN (decode) — dmesg | grep amdgpu.*firmware
  # Intel GPU: i915/xe GuC/HuC + DMC (§5) — dmesg | grep i915.*firmware
  # NVIDIA GPU: GSP firmware (Turing+ open modules bundle it — no linux-firmware)
  # WiFi/BT/NVMe: iwlwifi/btusb/nvme — the classic missing-blob dmesg warnings
  # (or the surgical list — hardening guide prefers minimal:)
  # hardware.firmware = [ pkgs.wireless-regdb ];

  # ---- NVIDIA driver gen matrix (hardware.nvidia.open is MANDATORY choice) --
  # hardware.nvidia = {
  #   modesetting.enable = true;  # all gens on Wayland/Hyprland
  #   # Maxwell/Pascal/Volta (GTX 9xx/10xx, pre-Turing): open = false;  # no GSP, proprietary only
  #   # Turing/Ampere/Ada (GTX16xx/RTX20-40xx, your 1660 SUPER): open = true;  # NVIDIA recommends open
  #   # Blackwell/50xx+: open = true;  # REQUIRED — proprietary REFUSES (no support)
  #   # package = config.boot.kernelPackages.nvidiaPackages.stable;  # beta/vulkan_beta for day-0 Blackwell
  #   # NVreg quirks: boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];  # suspend/resume
  #   #   + nvidia.NVreg_TemporaryFilePath=/var/tmp (GSP stash); powerManagement.enable=true on laptops
  # };

  # ---- Framework/Thinkpad/System76 vendors have their modules: -----------
  # NOTE: `hardware.framework.enable` does not exist in nixpkgs — Framework
  # support comes from the nixos-hardware flake
  # (github:NixOS/nixos-hardware, e.g. nixosModules.framework-13-7040-amd):
  # hardware.framework.enable = true;         # DOES NOT EXIST — see above
  # hardware.system76.enableAll = true;       # check options list
  # services.hardware.bolt.enable = true;     # Thunderbolt security

  # ---- Printing/scanners (when needed): ----------------------------------
  # services.printing.enable = true;          # CUPS
  # hardware.sane.enable = true;              # scanners
}
```

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| Kernel module version mismatch on boot | `extraModulePackages` used a different `kernelPackages` set (§1 RULE). Rebuild with matched set. |
| amd_pstate won't load | Not all CPUs support it — `dmesg \| grep amd_pstate`; Zen2 stays on acpi-cpufreq by design (§4). |
| Fans full-speed, sensors missing | `sudo sensors-detect --auto` then reboot; hwmon numbering shifts across kernels — never hardcode hwmonN without a udev symlink (§6 fancontrol caveat). |
| System freezes under load | Check `journalctl -k -b -1` for MCE/EDAC; run `stress-ng` while watching `sensors`; earlyoom (§6) prevents the OOM-killer variant of freezes. |
| Microcode warning at boot | updateMicrocode points at a package that lacks your CPU family — on stable pins this is rare; check `dmesg \| grep microcode`. |
| corectrl "no polkit action" | The module needs polkit enabled — it is by default; re-login after first enable (group/session). |
| premption=full feels slower for compilation | It is, slightly — compile-heavy workloads prefer `preempt=voluntary`. Toggle via kernelParams, not runtime. |
| earlyoom killed my game | freeMemThreshold too aggressive OR a real leak elsewhere — check `earlyoom` journal; it names its victims. |
| udev scheduler rule doesn't apply | `ACTION=="add\|change"` ordering + `queue/scheduler` attr name vary by driver — verify with udevadm test + read the attr directly. |

## 12. Reference Index

- NixOS kernel manual: <https://nixos.org/manual/nixos/stable/#sec-kernel-config>
- linuxPackages sources: `nixos/modules/system/boot/kernel.nix`, `pkgs/os-specific/linux/kernel-packages.nix`
- AMD pstate docs: kernel `Documentation/admin-guide/pm/amd-pstate.rst`
- corectrl: <https://gitlab.com/corectrl/corectrl>
- earlyoom: <https://github.com/hakavlad/earlyoom>
- ananicy-cpp: <https://github.com/ananicy-cpp/ananicy-cpp>
- lm_sensors/fancontrol: <https://github.com/lm-sensors/lm-sensors>
- Companions: `Hardening-NixOS.md` §2 (kernel security side), `Gaming-NixOS.md` §6/12, `Customization-NixOS.md` §3 (console/early KMS)
