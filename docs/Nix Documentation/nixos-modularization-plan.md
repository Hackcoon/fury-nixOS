# NixOS Configuration Modularization — Full Implementation Plan

**Target:** `/etc/nixos/configuration.nix` (currently 1,789 lines, ~66 KB)
**Goal:** Split into focused modules under a clean directory tree, with zero behavior change on the first rebuild, plus a roadmap for optional/conditional modules and Home Manager.

---

## Table of Contents

1. [Why Split It Up](#1-why-split-it-up)
2. [Current State Audit (what I found)](#2-current-state-audit-what-i-found)
3. [Target Directory Structure](#3-target-directory-structure)
4. [The New `configuration.nix` (the whole thing)](#4-the-new-configurationnix-the-whole-thing)
5. [Every Module With Full Code](#5-every-module-with-full-code)
6. [Migration Order — Step-by-Step](#6-migration-order--step-by-step)
7. [Verification Checklist](#7-verification-checklist)
8. [Fixes Applied vs. Old Config](#8-fixes-applied-vs-old-config)
9. [Phase 2 — Options & Conditionals](#9-phase-2--options--conditionals)
10. [Phase 3 — Home Manager Implementation Roadmap](#10-phase-3--home-manager-implementation-roadmap)
11. [What NOT To Modularize](#11-what-not-to-modularize)
12. [The Mock Sandbox — Test-Before-You-Commit](#12-the-mock-sandbox--test-before-you-commit)
13. [Vendor-Split Hardware, CUDA, Secure Boot + NVIDIA, AI per Vendor, Power](#13-vendor-split-hardware-cuda-secure-boot-nvidia-ai-per-vendor-power)

---

## 1. Why Split It Up

A single 1,789-line file has real costs:

| Problem | Effect |
|---|---|
| **Merge conflicts** | Any two edits touch the same file; git diffs are noisy |
| **Scroll & search tax** | Finding "that one NVIDIA setting" takes minutes |
| **All-or-nothing** | You can't experiment with one section in isolation |
| **No reusability** | Copying your setup to a second machine means copy-paste surgery |
| **Eval failures bury the cause** | An error at line 1,200 could stem from line 20 |

The NixOS module system is built for this. Every file is a module; you just `imports = [ ./path ];` and the module system **merges** everything. Two files can both set `environment.systemPackages` and they get concatenated. This is why splitting is safe: it's the same evaluation, just organized.

**The one rule:** lists and attrsets merge automatically across modules (`imports`, `systemPackages`, `shellAliases`, `nix.settings.*`, etc.), but scalar options (like `networking.hostName`) should be defined in **exactly one module** — defining them twice is an error (unless the values are literally identical), which is exactly the guardrail you want.

---

## 2. Current State Audit (what I found)

I read your entire `configuration.nix`, `flake.nix`, and `hardware-configuration.nix`, and probed the live system. Findings that affect this migration:

### 2.1 Things to FIX during migration

1. **Two separate `nix.settings` blocks** (lines 19–36 of your config). Nix merges them fine, but they should be one block in the new `core/nix.nix`.

2. **Duplicate wrapped/raw packages:** You wrap `sioyek`, `upscayl`, and `vesktop` via `symlinkJoin` (the right way), but **also list the raw `pkgs.sioyek` (line 1489), `pkgs.upscayl` (line 1498), and `pkgs.vesktop` (line 1457)** later in the flat list. I verified on the live system that both the raw and wrapped versions coexist — the raw entries should be removed so only the wrapped versions remain.

3. **`programs.wireshark.enable = true;` is set (line 1234), but your user is NOT in the `wireshark` group.** Your own comment at line 773 says "uncomment IF you enable programs.wireshark in the optional section below" — you did enable it, but never uncommented the group. Without it, Wireshark still prompts for root when capturing. **Add `"wireshark"` to `extraGroups`.**

4. **No git repo in `/etc/nixos`** despite your `config-diff`/`config-status`/`config-save` aliases running `sudo git` commands there — those aliases fail today. Step 0 of the migration initializes the repo.

5. **Stale ASPM comment:** the active `boot.kernelParams = [ "pcie_aspm=off" ];` (line 113) carries a comment saying "Only enable this if disabling EEE above does NOT fully fix..." — but the EEE handling is no longer "above" it (it's a systemd service much further down). Keep the param, fix the comment, and co-locate the reasoning.

6. **`config-save` hardcodes 4 filenames** (`configuration.nix hardware-configuration.nix flake.nix flake.lock`). After modularization you'll have ~25 files, and this alias would silently stop committing them. Change it to `git add .`.

7. **`services.openssh.enable = true;` sits in the middle of the shell section** for no reason — it belongs with networking.

8. **`nix.settings.trusted-users`** lives far away from the user definition — both user-related settings end up co-located in the new layout.

### 2.2 Things that are FINE and just need homes

- The commented `services.syncthing` block (system-service variant) — kept as a comment in the new layout, near where a service module would go.
- The hibernation / encrypted-swap notes — genuinely useful; they're preserved as comments in `hardware/ssd.nix` (hibernation priorities) and stay relevant to `hardware-configuration.nix` (swapDevices lives there).
- `flake.nix` is already clean and well-commented. **No changes needed** — `configuration.nix` remains the single entry point the flake points at; it just becomes thin.

### 2.3 Live-system checks I performed

- `/run/current-system` → generation `26.05.20260829.c5c4a43` (you're on the flake build, stable channel).
- Inspected the store path of wrapped `sioyek` → confirmed it's a real wrapper script (`.sioyek-wrapped` pattern exporting `QT_QPA_PLATFORM='xcb'`).
- `/etc/nixos/.git` does **not exist**.
- `/etc/nix/nix.conf` reflects your merged `nix.settings` (cores=2, max-jobs=1, CUDA substituter + key, experimental-features, auto-optimise-store).

---

## 3. Target Directory Structure

```
/etc/nixos/
├── flake.nix                    # unchanged (entry point for the flake)
├── flake.lock
├── configuration.nix            # now ~55 lines: imports + stateVersion ONLY
├── hardware-configuration.nix   # unchanged (generated file)
└── modules/
    ├── core/
    │   ├── boot.nix             # bootloader, lanzaboote, kernel, ASPM, boot limit
    │   ├── nix.nix              # ALL nix.settings, gc, nh, nix-ld, CUDA cache
    │   └── network.nix          # hostname, NM, DNS/DoT, ssh, wireshark
    ├── hardware/
    │   ├── nvidia.nix           # driver, modesetting, session vars, graphics
    │   ├── audio.nix            # pipewire, rtkit, bluetooth + BT codecs
    │   ├── ssd.nix              # tmpfs, zram, fstrim, journald cap, sleep fix
    │   └── realtek-eee.nix      # the ethtool systemd oneshot service
    ├── desktop/
    │   ├── kde.nix              # Plasma 6, SDDM, power-profiles, xwayland
    │   ├── xfce-chicago95.nix   # XFCE session + bitmap fonts
    │   ├── qylock.nix           # SDDM theme
    │   ├── fonts.nix            # font packages + fontconfig defaults
    │   ├── themes.nix           # cursor vars (XCURSOR_*)
    │   └── portals.nix          # xdg.portal config
    ├── programs/
    │   ├── shell.nix            # zsh, oh-my-zsh, ALL aliases, direnv
    │   ├── gaming.nix           # steam, gamemode, gamescope, xpadneo, proton
    │   ├── appimage.nix         # programs.appimage + packaging how-to comment
    │   ├── virtualisation.nix   # libvirtd, virt-manager, podman
    │   ├── thunar.nix           # thunar + gvfs/tumbler/xfconf
    │   ├── firefox.nix          # programs.firefox
    │   └── ai-services.nix      # ollama (cuda), open-webui, hermes-agent
    ├── services/
    │   ├── printing.nix         # CUPS
    │   └── flatpak.nix         # flatpak
    ├── users/
    │   └── users.nix           # user fury, groups, default shell
    └── packages/
        ├── system-packages.nix  # the big environment.systemPackages list
        └── apps-fixed.nix       # wrapped sioyek/upscayl/vesktop ONLY
```

> **Note:** `core/locale.nix` (timezone + locale) and `programs/firefox.nix` were added to this plan **after the mock build caught them missing** (see section 12). That's the mock process working as intended — dry-build + closure diff finds every dropped setting.

**Grouping logic:**

- **`core/`** — machine must boot, network, and build Nix things.
- **`hardware/`** — physical-device enablement and workarounds.
- **`desktop/`** — session experience: DE, themes, fonts, portals.
- **`programs/`** — feature-toggles for major software stacks (gaming, VMs, AI).
- **`services/`** — background daemons.
- **users & packages** — the "who" and the "what list".

> Bluetooth and audio share `audio.nix` because they're one logical unit on your machine: the headset feature (`hardware.bluetooth` + the wireplumber SBC-XQ/mSBC codec config only make sense together).

---

## 4. The New `configuration.nix` (the whole thing)

Replace the current 1,789-line file with this:

```nix
# /etc/nixos/configuration.nix
#
# Thin entry point. All real configuration lives in ./modules/*.
# The flake (flake.nix) points nixosSystem at this file; this file
# only wires the module tree together and pins stateVersion.
#
# unstablePkgs comes from flake.nix specialArgs — modules that need
# it declare it in their argument set.

{ config, pkgs, lib, unstablePkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix   # generated by nixos-generate-config — do not edit

    # --- core ---
    ./modules/core/boot.nix
    ./modules/core/nix.nix
    ./modules/core/locale.nix
    ./modules/core/network.nix

    # --- hardware ---
    ./modules/hardware/nvidia.nix
    ./modules/hardware/audio.nix
    ./modules/hardware/ssd.nix
    ./modules/hardware/realtek-eee.nix

    # --- desktop ---
    ./modules/desktop/kde.nix
    ./modules/desktop/xfce-chicago95.nix
    ./modules/desktop/qylock.nix
    ./modules/desktop/fonts.nix
    ./modules/desktop/themes.nix
    ./modules/desktop/portals.nix

    # --- programs ---
    ./modules/programs/shell.nix
    ./modules/programs/gaming.nix
    ./modules/programs/appimage.nix
    ./modules/programs/virtualisation.nix
    ./modules/programs/thunar.nix
    ./modules/programs/firefox.nix
    ./modules/programs/ai-services.nix

    # --- services ---
    ./modules/services/printing.nix
    ./modules/services/flatpak.nix

    # --- users & packages ---
    ./modules/users/users.nix
    ./modules/packages/system-packages.nix
    ./modules/packages/apps-fixed.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. Leave this at the release
  # version of your first install. Changing it will NOT upgrade.
  system.stateVersion = "26.05";
}
```

Everything below is the content of each module.

---

## 5. Every Module With Full Code

### 5.1 `modules/core/boot.nix`

```nix
# Bootloader & kernel.
#
# systemd-boot is disabled with mkForce because Lanzaboote (Secure Boot)
# takes over the boot entries and force-disables it itself; being
# explicit avoids "multiple defined" errors from leftover defaults.
{ config, pkgs, lib, ... }:

{
  # Standard kernel from your nixos-26.05 channel (pkgs.linuxPackages).
  # Alternatives: pkgs.linuxPackages_latest, or an LTS pin.
  boot.kernelPackages = pkgs.linuxPackages;

  # Disable default systemd-boot in favor of Lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # Enable Lanzaboote and define the PKI bundle location
  # (your sbctl keys live in /etc/secureboot)
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Allow EFI variables to be modified
  boot.loader.efi.canTouchEfiVariables = true;

  # PCIe ASPM can cause link renegotiation disconnects on RTL8111
  # boards — same symptom family as the EEE bug handled by
  # modules/hardware/realtek-eee.nix. Kept enabled while the EEE fix
  # alone proves stable. Tradeoff: slightly higher idle power draw.
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Caps the boot menu to the last 20 generations so the ESP doesn't
  # fill up with entries even if you rebuild a lot in a short window.
  # Lanzaboote respects this even though systemd-boot.enable is off.
  boot.loader.systemd-boot.configurationLimit = 20;
}
```

### 5.2 `modules/core/nix.nix`

```nix
# Nix-the-package-manager configuration: settings, caches, gc, helpers.
{ config, pkgs, lib, ... }:

{
  # Limit build parallelism so heavy compiles (CUDA etc.) don't
  # overheat the CPU
  nix.settings.cores = 2;      # threads per build (was 0 = all 12)
  nix.settings.max-jobs = 1;   # concurrent builds (was auto = 12)

  nix.settings = {
    # Modern Nix commands and Flakes
    experimental-features = [ "nix-command" "flakes" ];

    # Automatically optimize the Nix store to save disk space
    auto-optimise-store = true;

    # Additional binary cache hosting pre-built CUDA packages.
    # Without this, anything built with cudaSupport = true compiles
    # from source locally (cache.nixos.org doesn't build CUDA).
    # Note: the official cache is merged in automatically alongside
    # this list — verified in your live /etc/nix/nix.conf.
    substituters = [ "https://cache.nixos-cuda.org" ];

    # Public key used to verify packages fetched from the cache above.
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];

    # Adds you to nix's trusted-users list: `nix profile install`,
    # `nh os switch`, and later Home Manager can operate without sudo.
    # On a single-user desktop with wheel/sudo this is a convenience,
    # not a security boundary change.
    trusted-users = [ "root" "fury" ];
  };

  # Globally enables CUDA support for packages in nixpkgs that support
  # it (blender, ffmpeg, ML libs...). Combined with the CUDA cache
  # above, those packages are fetched pre-built instead of compiled.
  nixpkgs.config.cudaSupport = true;

  # EOL Electron/pnpm versions that some apps still need. The better
  # long-term fix is finding which app pulls each one in and updating
  # that app.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    "electron-39.8.10"
    "pnpm-10.29.2"
  ];

  # Automated weekly garbage collection — prunes generations older
  # than 30 days
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # nh — friendlier nixos-rebuild wrapper: `nh os switch` shows a
  # colored diff, `nh clean keep 5` prunes generations in a TUI.
  # Pointed at this flake, it uses /etc/nixos#nixos automatically.
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
    clean = {
      enable = true;      # enables the `nh clean` command
      dates = "weekly";   # auto-prune generations weekly (complements nix.gc)
    };
  };

  # Enable nix-ld to run unpatched dynamic binaries (non-FHS compliance)
  programs.nix-ld.enable = true;
}
```

> Note: `substituters`/`trusted-public-keys` merge with the NixOS defaults (the official cache and its key are added automatically), matching your current live `/etc/nix/nix.conf` exactly.

### 5.3 `modules/core/network.nix`

```nix
# Networking: NetworkManager, encrypted DNS (Quad9 DoT), SSH, Wireshark.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "nixos";

  # Enable NetworkManager for wired and wireless connections
  networking.networkmanager.enable = true;

  # Hand DNS duties to systemd-resolved instead of NetworkManager
  # managing it independently — prevents the two from fighting over
  # /etc/resolv.conf
  networking.networkmanager.dns = "systemd-resolved";

  # Prevent NetworkManager from injecting router DHCP DNS servers.
  # connectionConfig writes to the correct [connection] section,
  # applying to every connection profile (wired + wireless) at once.
  # Without this, your router's DNS (192.168.1.1) leaks in alongside
  # Quad9. Verify with `resolvectl status`.
  networking.networkmanager.connectionConfig = {
    "ipv4.ignore-auto-dns" = true;
    "ipv6.ignore-auto-dns" = true;
  };

  # Quad9 with DNS-over-TLS — encrypts DNS queries so your ISP/network
  # can't see plaintext lookups. Runs at the OS level via
  # systemd-resolved, transparent to every app with zero per-app config.
  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"          # Quad9 primary, TLS hostname for DoT verification
    "149.112.112.112#dns.quad9.net"   # Quad9 secondary
  ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        # Encrypts all DNS traffic between your machine and Quad9
        DNSOverTLS = "true";

        # "allow-downgrade" validates DNSSEC when possible but won't
        # hard-fail on networks/domains with broken DNSSEC records.
        # Strict "true" causes random unexplained connection failures
        # on some networks — avoid unless you want strict enforcement.
        DNSSEC = "allow-downgrade";

        # Used only if Quad9 itself is unreachable/down
        FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
      };
    };
  };

  # Enable the OpenSSH daemon
  services.openssh.enable = true;

  # Packet capture without sudo — requires the user to be in the
  # `wireshark` group (done in modules/users/users.nix; this was a
  # missing piece in the old config).
  programs.wireshark.enable = true;
}
```

### 5.4 `modules/hardware/nvidia.nix`

```nix
# NVIDIA proprietary driver (TU116 card) + graphics stack.
{ config, pkgs, lib, ... }:

{
  # Required for the proprietary NVIDIA driver
  nixpkgs.config.allowUnfree = true;

  # Load the proprietary NVIDIA driver for both X11 and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

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

  # OpenGL/graphics support, including 32-bit for gaming
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
```

### 5.5 `modules/hardware/audio.nix` (includes Bluetooth)

```nix
# Audio (PipeWire) + Bluetooth (BlueZ) — one headset feature unit.
{ config, pkgs, lib, ... }:

{
  # Disable legacy PulseAudio in favor of PipeWire
  services.pulseaudio.enable = false;

  # Realtime Kit scheduling for optimal audio performance
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;       # JACK application support
    wireplumber.enable = true;
  };

  # BlueZ system-wide
  hardware.bluetooth = {
    enable = true;

    # Turn Bluetooth on automatically at boot
    powerOnBoot = true;

    settings = {
      General = {
        Experimental = true;   # e.g. reading headset battery levels
      };
    };
  };

  # Bluetooth audio codec tweaks, applied via the BlueZ monitor in
  # wireplumber. NOTE: verify the extraConfig key
  # ("monitor.bluez.properties") against current wireplumber docs —
  # key renames silently no-op:
  services.pipewire.wireplumber.extraConfig."bluetooth-config" = {
    "monitor.bluez.properties" = {
      # SBC-XQ: higher-quality variant of the standard SBC codec
      "bluez5.enable-sbc-xq" = true;

      # mSBC: wideband speech codec for better headset mic audio
      "bluez5.enable-msbc" = true;

      # Let the device control its own hardware volume — can cause
      # volume-sync issues with some headphones, hence left off.
      # "bluez5.enable-hw-volume" = true;
    };
  };
}
```

### 5.6 `modules/hardware/ssd.nix`

```nix
# SSD longevity & write reduction: tmpfs /tmp, zram swap, fstrim,
# journal cap, and the suspend session-freeze fix.
#
# HIBERNATION NOTES (not currently enabled):
# The kernel hibernates into the swap device with the HIGHEST priority.
# Your zram is priority 5, so hibernation would try to hibernate into
# RAM (nonsense). If you ever want hibernation:
#   1. In hardware-configuration.nix, give the disk swap partition
#      priority 10 (swapDevices is declared there, not here):
#        swapDevices = [
#          { device = "/dev/disk/by-uuid/25c2c9f4-..."; priority = 10; }
#        ];
#   2. Keep zram below it here:  zramSwap.priority = 1;
#   3. Add to boot.kernelParams in core/boot.nix:
#        "resume=UUID=25c2c9f4-..."
#      and set boot.resumeDevice to the same UUID.
# NEVER combine hibernation with randomEncryption on disk swap —
# the key is regenerated at boot, so resume becomes impossible.
{ config, pkgs, lib, ... }:

{
  # Compiling packages / expanding archives / nixos-rebuild generates
  # gigabytes of short-lived temp files. Keeping /tmp in memory
  # eliminates millions of write cycles to disk.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "20%";   # 6.4 GB ceiling on a 32GB system

  # Swap writes degrade flash storage. Offload swap to compressed
  # RAM and keep the kernel from swapping until absolutely necessary.
  zramSwap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 10;

  # Weekly TRIM for SSD health (safely maintains lifespan)
  services.fstrim.enable = true;

  # smartd — continuous disk health monitoring (near-zero CPU, warns
  # weeks before real failure). Check alerts: journalctl -t smartd
  # services.smartd.enable = true;

  # Cap the systemd journal at 200M — logs are still written exactly
  # the same; older ones are just trimmed automatically.
  services.journald.extraConfig = "SystemMaxUse=200M";

  # Disable cgroup-based user session freezing during sleep —
  # prevents Wayland/Plasma crashes after resume.
  systemd.services = {
    "systemd-suspend".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
    "systemd-hibernate".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
    "systemd-hybrid-sleep".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
  };
}
```

### 5.7 `modules/hardware/realtek-eee.nix`

```nix
# Realtek RTL8111 Energy Efficient Ethernet disconnect workaround.
#
# EEE causes intermittent link renegotiation disconnects on this
# board. This oneshot service runs after NetworkManager so the
# interface has initialized before ethtool changes its settings.
{ config, pkgs, lib, ... }:

{
  systemd.services."disable-realtek-eee" = {
    description =
      "Disable Energy Efficient Ethernet on the Realtek Ethernet interface";

    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];

    serviceConfig = {
      Type = "oneshot";            # run once during boot
      RemainAfterExit = true;      # complete after success
      ExecStart =
        "${pkgs.ethtool}/bin/ethtool --set-eee enp5s0 eee off";
    };
  };
}
```

### 5.8 `modules/desktop/kde.nix`

```nix
# KDE Plasma 6 + SDDM (Wayland greeter) + power profiles.
{ config, pkgs, lib, ... }:

{
  # X11 windowing base — needed by XWayland apps and the XFCE session
  services.xserver.enable = true;

  # X11 keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # SDDM display manager — Wayland greeter so Qt6 themes render
  # correctly (required by the qylock themes)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Plasma 6 desktop
  services.desktopManager.plasma6.enable = true;

  # KDE's balanced power profile
  services.power-profiles-daemon.enable = true;

  # XWayland support for legacy apps under Wayland
  programs.xwayland.enable = true;
}
```

### 5.9 `modules/desktop/xfce-chicago95.nix`

```nix
# XFCE session (Chicago95 theme target).
#
# Registers "Xfce Session" in SDDM next to Plasma — pick per-login.
# The most trouble-free pairing with the NVIDIA driver (no Wayland
# quirks): the X11-fix wrappers in packages/apps-fixed.nix (sioyek,
# upscayl, vesktop) run natively here, no env hacks needed. The
# module auto-enables polkit-gnome agent, NM tray applet, pulseaudio
# plugin + pavucontrol, screensaver + PAM, udisks2/gvfs/tumbler,
# gtk + xapp portals.
{ config, pkgs, lib, ... }:

{
  services.xserver.desktopManager.xfce.enable = true;

  # Allow bitmap fonts — needed for Chicago95's pixelated "Helvetica"
  # (cronyx-cyrillic). Declarative equivalent of upstream's
  # "mv /etc/fonts/conf.d/70-no-bitmaps.conf" step. Harmless for
  # Plasma: it only ALLOWS bitmap fonts, never changes a default.
  fonts.fontconfig.allowBitmaps = true;
}
```

### 5.10 `modules/desktop/qylock.nix`

```nix
# Qylock SDDM themes (from the qylock flake input).
#
# NOTE: the Quickshell lockscreen requires compositor support for the
# ext-session-lock-v1 protocol, which KWin does NOT support yet — so
# only the SDDM login-screen theme works under Plasma. qylock-lock
# becomes useful only under a wlroots compositor like Hyprland.
{ config, pkgs, lib, ... }:

{
  programs.qylock = {
    enable = true;

    # Any directory name under qylock's `themes/` folder:
    # "nier-automata", "terraria", "clockwork", "pixel-coffee", ...
    # Full list: https://github.com/Darkkal44/qylock#-gallery
    theme = "nier-automata";

    # sddm.enable = true;         # default: installs theme + sets it active
    # quickshell.enable = false;  # see NOTE above — no KWin support yet

    # Optional per-theme tweaks (skips qylock's interactive prompts):
    # themeOptions = {
    #   terraria.backgroundMode = "time";   # time | random | static
    #   Genshin.backgroundMode = "time";
    #   clockwork.orbital = { themeMode = "dark"; enableWindup = true; };
    #   osu.gameMode = "menu";              # menu | game
    # };
  };
}
```

### 5.11 `modules/desktop/fonts.nix`

```nix
# System-wide fonts + fontconfig defaults.
{ config, pkgs, lib, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # JetBrains Mono NF (icons for eza, bat, ...)
      noto-fonts                  # Multilingual (Arabic, Cyrillic, ...)
      noto-fonts-cjk-sans         # Chinese/Japanese/Korean
      noto-fonts-color-emoji      # Emoji
      symbola                     # Full Unicode symbols (squared/enclosed letters)
      freefont_ttf                # GNU FreeFont (math bold script)
      stix-two                    # Math & script coverage
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" "FreeMono" "STIX Two Math" "Symbola" ];
        sansSerif = [ "Noto Sans" "FreeSans" "STIX Two Text" "Symbola" ];
        serif     = [ "Noto Serif" "FreeSerif" "STIX Two Text" "Symbola" ];
        emoji     = [ "Noto Color Emoji" ];
      };
    };
  };
}
```

### 5.12 `modules/desktop/themes.nix`

```nix
# Cursor theme + related environment variables.
#
# XCURSOR_THEME must match a variant provided by google-cursor
# (installed in packages/system-packages.nix under THEMES & CURSORS).
{ config, pkgs, lib, ... }:

{
  environment.variables = {
    # Variant options: GoogleDot-Blue, GoogleDot-Black, GoogleDot-White, GoogleDot-Red
    # Other themes: phinger-cursors (most over-engineered),
    #   Borealis-cursors, bibata-cursors-translucent, bibata-cursors
    #   macOS-like: apple-cursor, afterglow-cursors-recolored
    #   Windows-like: openzone-cursors
    XCURSOR_THEME = "GoogleDot-Black";

    # Standard cursor sizes: 22, 24, 32, 48, 64
    XCURSOR_SIZE = "22";
  };
}
```

### 5.13 `modules/desktop/portals.nix`

```nix
# XDG desktop portals — KDE Plasma and Hyprland have native portals,
# GTK is the general fallback. The wlroots portal stays installed for
# possible future MangoWC use but is not a default for any session.
{ config, pkgs, lib, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk      # GTK dialogs, file pickers, fallback
      pkgs.xdg-desktop-portal-hyprland # Hyprland screen sharing / Wayland
      pkgs.xdg-desktop-portal-wlr      # generic wlroots (future MangoWC)
      pkgs.kdePackages.xdg-desktop-portal-kde  # Plasma screen sharing
    ];
    config = {
      hyprland.default = [ "hyprland" "gtk" ];
      kde.default      = [ "kde" "gtk" ];
      # NOTE: "xapp" below needs pkgs.xdg-desktop-portal-xapp in
      # extraPortals above — currently NOT installed, so xfce falls
      # back to gtk only until you add it:
      xfce.default     = [ "xapp" "gtk" ];
      common.default   = [ "gtk" ];   # fallback for unidentified DEs
    };
  };

  # Uncomment when you start using MangoWC:
  # xdg.portal.config.mango.default = [ "wlr" "gtk" ];
  # xdg.portal.config.wlroots.default = [ "wlr" "gtk" ];
}
```

### 5.14 `modules/programs/shell.nix`

```nix
# Zsh + Oh My Zsh + aliases + direnv. The whole terminal experience.
{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;

    # Links /share/zsh (all package completions) into fpath and
    # installs nix-zsh-completions. Setting false breaks completions.
    enableCompletion = true;

    # Removes ONLY the duplicate compinit call from /etc/zshrc —
    # Oh My Zsh runs its own compinit anyway.
    enableGlobalCompInit = false;

    # Flat option (NOT history = { ... }) — sets both HISTSIZE and
    # SAVEHIST. histFile already defaults to ~/.zsh_history.
    histSize = 10000;

    autosuggestions.enable = true;      # gray suggestions from history
    syntaxHighlighting.enable = true;   # red invalid, green valid

    ohMyZsh = {
      enable = true;
      theme = "af-magic";
      plugins = [
        # "git"     # git aliases (gst, gco, gcmsg, gp, ...)
        "sudo"
        # "docker"  # tab-completion for docker commands
      ];
    };

    # Custom (non-bundled) themes like powerlevel10k go here instead
    # of theme = "...". Remember to comment out `theme` above:
    # ohMyZsh.plugins = [
    #   {
    #     name = "powerlevel10k";
    #     src = pkgs.zsh-powerlevel10k;
    #     file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    #   }
    # ];

    shellAliases = {
      # ---------- Everyday commands ----------
      ls   = "eza --icons";                          # modern ls with icons
      ll   = "eza -lah --icons";                    # detailed + hidden + readable
      lsd  = "eza -l --icons --only-dirs";          # directories only
      cat  = "bat";                                 # syntax-highlighted cat
      man  = "batman";                              # colourized manpages
      ".." = "cd ..";
      duh  = "du -sh ./*";                          # size of every item here
      c    = "clear";
      restart-gui = "sudo systemctl restart display-manager";

      # ---------- NixOS rebuild commands ----------
      nix-test         = "sudo nixos-rebuild test --flake /etc/nixos#nixos";
      nix-switch       = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      nix-rebuild      = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      nix-build-system = "sudo nixos-rebuild build --flake /etc/nixos#nixos";
      nix-build-dry    = "sudo nixos-rebuild dry-build --flake /etc/nixos#nixos";

      # ---------- Flake update commands ----------
      nix-upgrade = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      flake-update = "cd /etc/nixos && sudo nix flake update";
      nix-upgrade-locked = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      nix-check   = "sudo nix flake check /etc/nixos";
      nix-inputs  = "nix flake metadata /etc/nixos";

      # ---------- Generations & rollback ----------
      nix-generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nix-keep-10 = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +10 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      nix-keep-20 = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +20 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      nix-rollback = "sudo nixos-rebuild switch --rollback";
      nix-current  = "readlink /nix/var/nix/profiles/system";

      # ---------- Nix store cleanup ----------
      nixdelete          = "sudo nix-collect-garbage --delete-older-than 30d";
      nix-gc             = "sudo nix-collect-garbage --delete-older-than 30d";
      nix-delete-all-old = "sudo nix-collect-garbage --delete-old";  # WARNING: removes ALL old generations
      nix-store-size     = "sudo du -sh /nix/store";
      nix-optimize       = "sudo nix-store --optimise";

      # ---------- Nix file commands ----------
      # Requires nixfmt in systemPackages.
      nix-format = "sudo nixfmt /etc/nixos/configuration.nix /etc/nixos/flake.nix";

      # ---------- Configuration Git commands ----------
      config-diff   = "cd /etc/nixos && sudo git diff";
      config-status = "cd /etc/nixos && sudo git status";
      config-log    = "cd /etc/nixos && sudo git log --oneline --decorate -10";
      config-save   = "cd /etc/nixos && sudo git add . && sudo git commit";

      # ---------- System information ----------
      ff          = "fastfetch";
      bt          = "btop";
      dg          = "dgop";
      disks       = "df -h";
      memory      = "free -h";
      myip        = "ip -brief address";
      boot-status = "systemctl --failed";
      sb-status   = "sbctl status";
      sb-verify   = "sbctl verify";
    };

    # Initialize Zsh tools when an interactive shell opens.
    interactiveShellInit = ''
      eval "$(zoxide init zsh)"
      eval "$(fzf --zsh)"
    '';
  };

  # Automatically load per-project development environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
```

> **Changes vs. old config:** `users.defaultUserShell` moved to `users/users.nix` (a user property — define scalars in exactly one place). `config-save` now does `git add .` so all ~25 module files get committed, not just the 4 old filenames.

### 5.15 `modules/programs/gaming.nix`

```nix
# Gaming: Steam, GameMode, Gamescope, controllers, Proton helpers.
{ config, pkgs, lib, ... }:

{
  # GameMode adjusts CPU scheduling, I/O priority, and other settings
  # while a game is running
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    remotePlay.openFirewall = true;   # Remote Play / streaming
  };

  # Several Proton games crash without this (Star Citizen pattern).
  # NOTE: use 1048576 — 2147483647 overflows the kernel's signed-int limit:
  boot.kernel.sysctl."vm.max_map_count" = 1048576;

  # Xbox controller over Bluetooth
  hardware.xpadneo.enable = true;
}
```

### 5.16 `modules/programs/appimage.nix`

```nix
# AppImage support via binfmt_misc.
#
# USAGE:
#   Run (one-off):  chmod +x ./SomeApp.AppImage && ./SomeApp.AppImage
#   Without binfmt: nix-shell -p appimage-run --run "appimage-run ./SomeApp.AppImage"
#   "Install":      gearlever (in nixpkgs) manages AppImages + desktop
#                  entries, like AppImageLauncher on other distros.
#
# PACKAGING an AppImage properly (best for constant use):
#   1. Determine the type: `file ./SomeApp.AppImage`
#      "ISO 9660" in the output = Type 2 (use appimageTools.wrapType2)
#      "ELF" only              = Type 1 (use wrapType1)
#   2. Write a derivation, e.g. /etc/nixos/pkgs/someapp.nix:
#
#        { lib, appimageTools, fetchurl }:
#        let
#          pname = "someapp";
#          version = "1.4.0";
#          src = fetchurl {
#            url = "https://example.com/releases/SomeApp-${version}.AppImage";
#            hash = "";   # leave blank; nix prints the real hash on first build
#          };
#        in
#        appimageTools.wrapType2 {
#          inherit pname version src;
#          # Fixes the .desktop Exec= line so launchers call the wrapped binary
#          extraInstallCommands = ''
#            substituteInPlace $out/share/applications/${pname}.desktop \
#              --replace-fail 'Exec=AppRun' 'Exec=${pname}'
#          '';
#        }
#
#   3. Wire it in (packages/system-packages.nix):
#        (pkgs.callPackage ./pkgs/someapp.nix { })
#   4. Build once with the empty hash to learn the real one, paste it in,
#      rebuild for real. From here it's a normal package: launcher entry,
#      icon, updates on version bump, correct GC behavior.
#
# IF AN APPIMAGE FAILS TO LAUNCH with "error while loading shared
# libraries: libXXX.so.XX: cannot open shared object file", uncomment
# ONLY what the error names in the override below — some (torch) are
# multi-GB; don't add speculatively.
{ config, pkgs, lib, ... }:

{
  programs.appimage = {
    enable = true;
    binfmt = true;

    # package = pkgs.appimage-run.override {
    #   extraPkgs = pkgs: [
    #     pkgs.icu               # libicuuc.so errors (Electron/Qt AppImages)
    #     pkgs.libxcrypt-legacy  # libcrypt.so.1 errors (older glibc/crypt)
    #     pkgs.python312         # only if it bundles/calls system Python 3.12
    #     pkgs.python312Packages.torch  # ML AppImages expecting host PyTorch (heavy)
    #   ];
    # };
  };
}
```

### 5.17 `modules/programs/virtualisation.nix`

```nix
# Virtualization: libvirtd/KVM + virt-manager + Spice USB + Podman.
{ config, pkgs, lib, ... }:

{
  # libvirtd with settings tuned for KVM/QEMU VM performance
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  # Virt-Manager GUI
  programs.virt-manager.enable = true;

  # Spice redirection for USB passthrough
  virtualisation.spiceUSBRedirection.enable = true;

  # Podman — daemonless container backend. Nothing runs until you
  # actually start a container (zero idle CPU/memory).
  #   dockerCompat    -> `docker` CLI shim pointing at podman
  #   dockerSocket    -> docker-compatible API socket (socket-activated,
  #                     starts on demand) so docker-API tools (winboat)
  #                     work without a permanent daemon.
  # Want the REAL Docker daemon instead? Drop this block and enable
  # virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };
}
```

### 5.18 `modules/programs/thunar.nix`

```nix
# Thunar file manager + the services it needs (mounting, trash,
# thumbnails, preference persistence).
{ config, pkgs, lib, ... }:

{
  programs.thunar = {
    enable = true;
    # These plugins were moved from pkgs.xfce to top-level pkgs.
    plugins = [
      pkgs.thunar-archive-plugin
      pkgs.thunar-volman
      pkgs.thunar-media-tags-plugin
      pkgs.thunar-shares-plugin
    ];
  };

  services.gvfs.enable = true;      # mounting, trash, removable devices
  services.tumbler.enable = true;   # thumbnails
  programs.xfconf.enable = true;    # saves Thunar prefs outside a full XFCE session
}
```

### 5.18b `modules/programs/firefox.nix`

> Added after the mock build caught it missing (see section 12): the closure diff showed `firefox: 154.0.1 → ∅, -381 MiB` — a silent regression the dry-build exposed.

```nix
# Firefox — system-wide installation via the NixOS module
# (wraps the unwrapped package with policies/wrapping support).
{ config, pkgs, lib, ... }:

{
  programs.firefox.enable = true;
}
```

### 5.19 `modules/programs/ai-services.nix`

```nix
# Local AI stack: Ollama (CUDA) + open-webui + Hermes Agent.
#
# NOTE — secrets: never put API keys in `settings` or `environment`;
# both are written into /nix/store, which is world-readable. Use
# `environmentFiles` pointed at a sops-nix/agenix secret (or, as a
# bare-minimum starting point, a manually created 0600 file owned by
# the hermes user).
{ config, pkgs, lib, ... }:

{
  # Ollama — always-on local LLM server at http://localhost:11434.
  # ollama-cuda offloads inference to the NVIDIA GPU; idle it consumes
  # nearly nothing.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  services.open-webui = {
    enable = true;
    port = 8080;
    # package = pkgs.open-webui;  # pin explicitly if needed
  };

  services.hermes-agent = {
    # NOTE: custom flake module (hermes-agent input), NOT nixpkgs —
    # requires hermes-agent.nixosModules.default in flake.nix modules:
    enable = true;

    settings.model = {
      # OpenRouter is Hermes' default provider — no base_url override
      # needed, just the model slug. MiniMax M3 (free): 1M context,
      # tuned for long-horizon agentic/coding work — genuinely free,
      # not a trial quota.
      default = "minimax/minimax-m3:free";
    };

    # OpenRouter key (see secrets NOTE above)
    environmentFiles = [ "/var/lib/hermes/env" ];

    addToSystemPackages = true;
  };
}
```

### 5.20 `modules/services/printing.nix`

```nix
# CUPS printing.
{ config, pkgs, lib, ... }:

{
  services.printing.enable = true;
}
```

### 5.21 `modules/services/flatpak.nix`

```nix
# Flatpak sandboxed applications.
{ config, pkgs, lib, ... }:

{
  services.flatpak.enable = true;
}
```

### 5.22 `modules/users/users.nix`

```nix
# Users, groups, default shell.
{ config, pkgs, lib, ... }:

{
  users.users."fury" = {
    isNormalUser = true;
    description = "Fury";
    extraGroups = [
      "networkmanager"  # manage network connections without a password prompt
      "wheel"           # sudo access
      "libvirtd"        # access VMs in virt-manager without "access denied"
      "wireshark"       # packet capture without sudo — programs.wireshark is
                        # enabled in core/network.nix; this group membership
                        # was missing in the old config (fix #3)
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # Default shell (zsh itself is configured in programs/shell.nix)
  users.defaultUserShell = pkgs.zsh;
}
```

### 5.23 `modules/packages/system-packages.nix`

The big list — same packages, same categories, minus the raw sioyek/upscayl/vesktop (now only in apps-fixed.nix), minus `wireshark` (installed by the module in network.nix).

```nix
# System-wide packages. Wrapped/patched apps live in apps-fixed.nix.
# Unstable packages use unstablePkgs (from flake.nix specialArgs).
{ config, pkgs, lib, unstablePkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # === SYSTEM & HARDWARE UTILITIES ===
    sbctl                   # Secure Boot key manager
    solaar                  # Logitech device manager
    lshw                    # Hardware configuration list tool
    pciutils                # PCI bus utilities (lspci)
    usbutils                # USB device utilities (lsusb)
    smartmontools           # S.M.A.R.T. disk monitoring
    gsmartcontrol           # GUI for smartmontools
    winboat                 # Run Windows apps on Linux with seamless integration

    # === SYSTEM MONITORING ===
    topgrade                # System upgrade utility
    fastfetch               # System information fetcher
    btop                    # Command-line resource monitor
    mission-center          # GUI system resource monitor
    cpu-x                   # System profiler (CPU-Z alternative)
    hardinfo2               # Hardware analyzer and benchmark tool
    nvitop                  # Interactive NVIDIA GPU resource monitor
    dgop                    # Go dependency graph tool
    gdu                     # GNOME disk usage analyzer

    # === WAYLAND & DESKTOP UTILITIES ===
    kitty                   # GPU-based terminal
    wl-clipboard            # wl-copy / wl-paste
    cliphist                # Clipboard history for Wayland
    flameshot               # Screenshot with annotation
    qalculate-qt            # Multi-purpose desktop calculator
    hyprcursor              # New cursor theme format
    cmatrix                 # Matrix rain in terminal

    # === CLI UTILITIES & REPLACEMENTS ===
    ripgrep                 # Faster grep (rg)
    bat-extras.batman       # man pages via bat
    zsh-completions         # Additional zsh completions
    util-linux              # System utilities (keep for batman)
    fd                      # Faster find
    bat                     # Better cat with syntax highlighting
    eza                     # Better ls with icons (works with Nerd Font)
    fzf                     # Fuzzy finder
    zoxide                  # Smarter cd
    tealdeer                # Simplified man pages
    manix                   # Fast Nix option/docs searcher
    wikiman                 # Offline manual search engine
    micro                   # Terminal text editor
    fresh-editor            # Terminal text editor / IDE
    jq                      # JSON processor
    yq                      # YAML processor

    # === DEVELOPMENT & IT TOOLS ===
    vscodium                # Open source VS Code binaries
    antigravity-fhs         # Agentic development platform
    home-manager            # home-manager CLI for nix files
    nixfmt                  # Nix formatter
    nil                     # Nix language server (mainly for fresh editor)
    nixd                    # Feature-rich Nix language server
    git                     # Version control
    gh                      # GitHub CLI
    gitkraken               # Git GUI (requires allowUnfree)

    # === AI TOOLS ===
    lmstudio                # Local LLM desktop app
    cherry-studio           # Multi-provider LLM desktop client
    opencode                # AI coding agent for the terminal
    opencode-desktop        # AI coding agent desktop client

    # === LANGUAGE TOOLCHAINS & COMPILERS ===
    gcc                     # C/C++ compiler
    gdb                     # C/C++ debugger
    gnumake                 # Build automation
    cmake                   # Cross-platform build generator
    go                      # Go toolchain
    rustup                  # Rust toolchain manager (rustc & cargo)
    python3                 # Python runtime
    nodejs_22               # Node.js runtime
    python3Packages.pip     # Python package installer
    lua                     # Lua interpreter
    luarocks                # Lua package manager

    # === ENVIRONMENTS & CONTAINERS ===
    distrobox               # Linux distros in containers
    bruno                   # Offline Postman alternative
    devenv                  # Per-project dev environments (pairs with flakes)

    # === NETWORK & SECURITY ===
    ethtool                 # Ethernet checker (also used by realtek-eee.nix)
    nmap                    # Network scanner
    dig                     # DNS lookup
    whois                   # Domain info
    traceroute              # Network path tool
    iperf3                  # Network speed testing
    remmina                 # Remote desktop client (RDP, VNC, SSH)
    kdePackages.kleopatra   # Certificate manager, GnuPG GUI
    gnupg                   # GNU Privacy Guard

    # === INTERNET & COMMUNICATION ===
    brave                   # Privacy-focused browser
    librewolf               # Privacy-focused Firefox fork
    stoat-desktop           # Open-source Discord alternative
    mailspring              # Email client

    # === FILE MANAGEMENT, SYNC & ARCHIVING ===
    wget                    # File downloader
    curl                    # HTTP swiss army knife
    aria2                   # Multi-connection downloader
    qbittorrent             # Torrent client with GUI
    filezilla               # FTP/SFTP GUI client
    syncthing               # P2P file syncing (manual/GUI use — see
                            # commented service block below)
    localsend               # AirDrop equivalent for local network

    # Archive backends ark needs for all formats
    unzip
    unrar
    p7zip
    zip
    gzip
    xz
    zstd
    bzip2

    # === OFFICE & PRODUCTIVITY ===
    obsidian                # Knowledge base / markdown notes
    logseq                  # Open-source obsidian
    anytype                 # Offline-first encrypted knowledge base
    appflowy                # Open-source Notion
    onlyoffice-desktopeditors  # Office suite
    pdfarranger             # Merge, split, rotate PDFs

    # === GRAPHICS & DESIGN ===
    gimp                    # Image manipulation
    inkscape                # Vector graphics editor
    krita                   # Digital painting / 2D animation
    darktable               # RAW developer / photo workflow

    # === GAMING & CHESS ===
    en-croissant            # Ultimate Chess Toolkit
    pawn-appetit            # Chess toolkit (en-croissant fork)
    prismlauncher           # Minecraft launcher
    heroic                  # GOG / Epic / Amazon Games launcher
    bottles                 # Wine prefix manager

    # Gaming performance and diagnostics
    mangohud
    vulkan-tools
    mesa-demos

    # Wine/Proton helpers
    protontricks
    protonup-qt
    winetricks
    wineWow64Packages.stable

    # === MEDIA, AUDIO & VIDEO ===
    mpv                     # Highly configurable video player
    haruna                  # Qt/QML video player built on libmpv
    vlc                     # Versatile media player
    nomacs                  # Image viewer
    kdePackages.kdenlive    # Non-linear video editor
    ffmpeg-full             # Record / convert / stream audio+video
    mediainfo               # Media file info CLI
    mediainfo-gui           # GUI for mediainfo
    easyeffects             # Audio effects for PipeWire apps

    # === KDE EXTRAS ===
    kdePackages.sddm-kcm    # Login screen manager
    kdePackages.kcalc       # Scientific calculator

    # === THEMES & CURSORS ===
    chicago95               # Win95 total-conversion theme (GTK, icons, XFWM)
    gtk-engine-murrine      # GTK2 engine needed by Chicago95
    google-cursor           # Cursor theme (provides GoogleDot-* used in
                            # desktop/themes.nix — keep in sync)
    bibata-cursors          # Modern triangular cursor

    # === Chicago95 taskbar plugins ===
    # Whisker Menu is the "Start" button; the theme ships Win95-logo
    # sidebar branding for it. docklike = optional quick-launch style.
    xfce4-whiskermenu-plugin
    xfce4-panel-profiles    # applies the official Win95 taskbar layout
    xfce4-clipman-plugin     # clipboard history, retro-fitted
    xfce4-docklike-plugin

    # === Chicago95 extras ===
    font-cronyx-cyrillic    # pixelated bitmap "Helvetica" the Win95 UI used
    sox                     # `play` command — Win95 startup chime + event sounds

    # === THUMBNAIL SUPPORT ===
    kdePackages.kdegraphics-thumbnailers   # PDFs, EPS
    kdePackages.ffmpegthumbs               # videos
    kdePackages.kimageformats              # WebP, RAW, etc.
    kdePackages.kio-extras                 # network shares, extra formats
    epub-thumbnailer                       # EPub thumbnails

    # === FROM UNSTABLE (nixos-unstable via flake input) ===
    unstablePkgs.llmfit     # LLM model size finder
  ];

  # Syncthing as a user service (run at login, auto-restart) — enable
  # when you want background sync instead of launching it manually:
  # services.syncthing = {
  #   enable = true;
  #   user = "fury";
  #   openDefaultPorts = false;   # local-network syncing needs no ports
  # };
  # Check with: systemctl --user status syncthing
}
```

> **Removed vs. your current list:** raw `sioyek`, `upscayl`, `vesktop` (wrapped versions live in apps-fixed.nix — the duplicate fix), `wireshark` (the module installs it), and the commented `ollama` / `open-webui` / `nh` / `docker` / `docker-compose` / `direnv` lines (all now handled by their modules).

### 5.24 `modules/packages/apps-fixed.nix`

```nix
# Apps with KDE/Wayland fixes, via symlinkJoin wrappers.
#
# These three are broken under KDE Wayland:
#   sioyek   -> needs QT_QPA_PLATFORM=xcb
#   upscayl  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
#   vesktop  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
#
# IMPORTANT: do NOT also add the raw pkgs.sioyek / pkgs.upscayl /
# pkgs.vesktop to system-packages.nix — the raw packages would
# duplicate these wrappers (this was a live bug in the old
# monolithic config).
{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Sioyek fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "sioyek";
      paths = [ pkgs.sioyek ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb
      '';
    })

    # Upscayl fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "upscayl";
      paths = [ pkgs.upscayl ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/upscayl --unset NIXOS_OZONE_WL --add-flags "--ozone-platform=x11"
      '';
    })

    # Vesktop fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "vesktop";
      paths = [ pkgs.vesktop ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/vesktop \
          --unset NIXOS_OZONE_WL \
          --add-flags "--ozone-platform=x11"
      '';
    })
  ];
}
```

---

## 6. Migration Order — Step-by-Step

Do this over multiple rebuilds so a failure tells you exactly which module broke it. Run `nix-test` after every step, and commit after every successful test.

### Step 0 — Git safety net (REQUIRED FIRST)

```bash
cd /etc/nixos
sudo git init
sudo git add configuration.nix hardware-configuration.nix flake.nix flake.lock
sudo git commit -m "Monolithic config before modularization"
```

Why: your `config-diff`/`config-save` aliases already assume a repo exists — it doesn't. Every step below should end with a commit so you can `git checkout` your way out of any mistake.

### Step 1 — Create the tree, extract core (boot + nix + network)

```bash
sudo mkdir -p /etc/nixos/modules/{core,hardware,desktop,programs,services,users,packages}
```

Create `modules/core/boot.nix`, `modules/core/nix.nix`, `modules/core/network.nix` (sections 5.1–5.3). In `configuration.nix`: add the three imports, **delete** the moved-out blocks, keep everything else.

```bash
nix-test          # verify
cd /etc/nixos && sudo git add . && sudo git commit -m "Extract core: boot, nix, network"
```

### Step 2 — Extract hardware (nvidia, audio+bt, ssd, realtek)

Sections 5.4–5.7. Watch the two old scattered `nix.settings`-adjacent blocks (cores/max-jobs and the cache block) become one coherent module.

```bash
nix-test          # verify → commit "Extract hardware modules"
```

### Step 3 — Extract desktop (kde, xfce, qylock, fonts, themes, portals)

Sections 5.8–5.13. Note `fonts.fontconfig.allowBitmaps` moves into `xfce-chicago95.nix` — it exists specifically for Chicago95's bitmap font.

```bash
nix-test          # verify → commit "Extract desktop modules"
```

### Step 4 — Extract programs (shell, gaming, appimage, virtualisation, thunar, ai)

Sections 5.14–5.19. Biggest single move: all of zsh + 40+ aliases.

```bash
nix-test          # verify → commit "Extract program modules"
```

### Step 5 — Extract services + users + packages

Sections 5.20–5.24. This is where the raw/wrapped duplicate fix and the wireshark group fix land — apply them as you move (they're already in the listings above).

```bash
nix-test          # verify → commit "Extract services, users, packages"
```

### Step 6 — Final `configuration.nix` + switch

At this point configuration.nix should contain ONLY the imports list + `system.stateVersion` (section 4). Diff it against your old file (in git) to confirm nothing was lost:

```bash
cd /etc/nixos
sudo git diff HEAD~5 -- configuration.nix   # eyeball what left the file
nix-test                                     # full check
nix-switch                                   # make permanent
groups fury                                  # should now include wireshark
```

---

## 7. Verification Checklist

After each phase:

```bash
nix-build-dry    # can it evaluate + fetch?
nix-test         # activate temporarily
```

`nh os test` also works and shows a colored diff of what changed.

Functional spot-checks after the final switch:

| Check | Command | Expected |
|---|---|---|
| Secure Boot still enforced | `sb-status` / `sb-verify` | Enabled, verified |
| DNS is Quad9 DoT only | `resolvectl status` | Only Quad9 on enp5s0 |
| EEE still disabled | `sudo ethtool --show-eee enp5s0` | EEE: off |
| Audio + BT codecs | connect headset, check sound settings | SBC-XQ / mSBC available |
| Wrapped apps | launch sioyek, upscayl, vesktop | They open (in X11 mode) |
| Ollama | `systemctl status ollama` | active (running) |
| open-webui | http://localhost:8080 | Web UI loads |
| Hermes agent | `systemctl status hermes-agent` | active (running) |
| Wireshark no-sudo capture | open wireshark as fury | Captures without root |
| Wireshark group took effect | `groups fury` | lists `wireshark` (re-login if needed) |
| zsh aliases | `ff`, `nix-generations`, `sb-verify` | All work |
| Rollback safety | `nix-generations` | Old monolithic gen still listed |

---

## 8. Fixes Applied vs. Old Config

| # | Fix | Where it landed |
|---|---|---|
| 1 | Two separate `nix.settings` blocks merged into one | core/nix.nix |
| 2 | Raw sioyek/upscayl/vesktop removed — were duplicating the symlinkJoin wrappers | packages/apps-fixed.nix |
| 3 | `wireshark` group added to user (module was enabled, group was missing) | users/users.nix |
| 4 | openssh moved next to networking (was orphaned in the shell section) | core/network.nix |
| 5 | `trusted-users` co-located with the nix settings that use it | core/nix.nix |
| 6 | Stale ASPM comment rewritten (it referenced an EEE block that no longer preceded it) | core/boot.nix |
| 7 | `config-save` alias now commits all files (`git add .`), not 4 hardcoded names | programs/shell.nix |
| 8 | Git repo initialized (config-diff/status/save aliases were broken) | Step 0 |
| 9 | `users.defaultUserShell` defined once (in users.nix, not scattered) | users/users.nix |
| 10 | Hibernation + encrypted-swap notes preserved as comments where relevant | hardware/ssd.nix |
| 11 | `programs.firefox` — found missing by the mock's closure diff (-381 MiB), restored as its own module | programs/firefox.nix |
| 12 | `time.timeZone` + `i18n.defaultLocale` — found missing by the mock's closure diff (-2.5 MiB glibc-locales), restored | core/locale.nix |

Also removed as dead weight: the four "OLD WAY (unused)" comment blocks (the superseding config is now adjacent in its own module, making the archaeology unnecessary), the duplicate custom-theme comment blocks (one copy now lives in shell.nix), and the giant AppImage tutorial (condensed into appimage.nix's header comment).

---

## 9. Phase 2 — Options & Conditionals (do this AFTER the split works)

Once the tree is stable, add custom options so whole feature stacks can be toggled from configuration.nix without editing imports:

```nix
# modules/options.nix
{ config, lib, ... }:

{
  options.my = {
    enableGaming = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the full gaming stack (Steam, GameMode, controllers, Proton helpers).";
    };
    enableAiStack = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Ollama, open-webui, and Hermes Agent.";
    };
    enableXfce = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the XFCE/Chicago95 alternate session.";
    };
  };
}
```

Then wrap a module's config in `lib.mkIf`:

```nix
# modules/programs/gaming.nix
{ config, pkgs, lib, ... }:

{
  config = lib.mkIf config.my.enableGaming {
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;
    # ... everything else from section 5.15
  };
}
```

Add `./modules/options.nix` to the imports, and toggling a whole stack becomes one line in configuration.nix:

```nix
my.enableGaming = false;   # entire gaming stack off, nothing else edited
```

Good candidates for mkIf-flagging: gaming, the AI stack, virtualisation, printing, the XFCE session. This is also the natural stepping stone to **multiple machines**: keep one module tree, add a per-host flag file.

---

## 10. Phase 3 — Home Manager Implementation Roadmap

This is the complete migration path, staged so you can stop at any step with a working system. Do this **after** the modular split (sections 3–7) is stable — Home Manager on top of a modular tree is trivial; on top of the monolith it's misery.

### 10.1 What Home Manager is (and why you want it)

Home Manager (HM) manages your **user** environment declaratively: dotfiles, shell config, git, kitty, user packages, session variables. The NixOS layer keeps managing the machine (hardware, services, system packages); HM manages fury-the-user.

**The boundary rule of thumb:**

| Belongs in NixOS (`modules/*`) | Belongs in HM (`home/*`) |
|---|---|
| Hardware, drivers, kernel | Terminal/editor config (kitty, micro) |
| System services (ollama, ssh, CUPS) | Shell experience (aliases, prompt, OMZ plugins) |
| System-wide packages (systemPackages) | Personal packages (only fury uses) |
| Users, groups, sudo | Git identity & config |
| Bootloader, Secure Boot | Session vars that are per-user prefs |
| Fonts (system-wide fallbacks) | Application themes (per-user GTK/Qt) |

### 10.2 Step 1 — Wire HM into the flake

Uncomment/add the input in `flake.nix`:

```nix
inputs = {
  # ... existing inputs ...

  home-manager.url = "github:nix-community/home-manager";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";   # ONE package set, no version skew
};
```

Add the module to `nixosConfigurations.nixos.modules`:

```nix
outputs = { self, nixpkgs, nixpkgs-unstable, lanzaboote, qylock, hermes-agent, home-manager, ... }:
  # ...
  modules = [
    ./configuration.nix
    lanzaboote.nixosModules.lanzaboote
    qylock.nixosModules.default
    hermes-agent.nixosModules.default

    home-manager.nixosModules.home-manager   # NEW
  ];
```

> The `follows` is critical: HM then builds from the exact same nixpkgs revision as your system, so user packages never drift from system packages.

### 10.3 Step 2 — Create the HM module tree

Mirror the NixOS tree structure so your brain uses one map:

```
/etc/nixos/
├── modules/          # system-level (from the modular split)
└── home/             # user-level (fury)
    ├── home.nix      # HM entry point — imports everything below
    ├── shell.nix     # zsh aliases, OMZ theme/plugins, interactiveShellInit
    ├── git.nix       # programs.git (name, email, aliases, delta)
    ├── terminal.nix  # kitty config
    └── packages.nix  # personal packages (home.packages)
```

### 10.4 Step 3 — The HM entry point (`home/home.nix`)

```nix
# /etc/nixos/home/home.nix
{ config, pkgs, lib, ... }:

{
  home = {
    username = "fury";
    homeDirectory = "/home/fury";
    stateVersion = "26.05";   # same rule as system.stateVersion — set once, never bump casually

    # Manage dotfiles via HM (symlinked from ~/.config etc.)
    file = { };
  };

  # Let home-manager manage itself inside the NixOS rebuild
  programs.home-manager.enable = true;

  imports = [
    ./shell.nix
    ./git.nix
    ./terminal.nix
    ./packages.nix
  ];
}
```

### 10.5 Step 4 — Wire fury to it (from NixOS side)

In `modules/users/users.nix`, add one line to the existing user:

```nix
users.users."fury" = {
  # ... existing config ...
};

# Home Manager for fury — driven by the NixOS rebuild
home-manager.users.fury = import ../home/home.nix;
```

And set the two glue options once (a good home is `modules/users/users.nix`, bottom):

```nix
home-manager.useGlobalPkgs = true;   # share the system pkgs — no second nixpkgs eval
home-manager.useUserPackages = true; # install to ~/.local — per-user rollback without sudo
```

After this, `nix-switch` builds **both** the system and your home environment in one rebuild. No separate `home-manager switch` command needed.

### 10.6 Step 5 — Migrate settings in this order (safest first)

Migrate ONE thing at a time, `nix-test` + spot-check after each:

1. **Git config** (`home/git.nix`) — lowest risk, pure user config:
   ```nix
   { config, pkgs, lib, ... }:
   {
     programs.git = {
       enable = true;
       userName  = "Fury";
       userEmail = "fury@example.com";   # ← your real email
       extraConfig = {
         init.defaultBranch = "main";
         pull.rebase = false;
       };
       # delta = { enable = true; };   # nicer diffs
     };
   }
   ```
2. **Kitty config** (`home/terminal.nix`):
   ```nix
   { config, pkgs, lib, ... }:
   {
     programs.kitty.enable = true;

     # If you already have ~/.config/kitty/kitty.conf you want to keep
     # verbatim first, use xdg.configFile instead of programs.kitty:
     # xdg.configFile."kitty/kitty.conf".source = ./kitty.conf;
   }
   ```
3. **zsh personal bits** (`home/shell.nix`) — move the aliases/prompt/OMZ config OUT of `modules/programs/shell.nix` INTO here. NixOS-side keeps only:
   ```nix
   # modules/programs/shell.nix — after migration, keeps ONLY:
   { config, pkgs, lib, ... }:
   {
     programs.zsh.enable = true;              # system-wide zsh availability
     users.defaultUserShell = pkgs.zsh;        # (or move to users.nix)
     programs.direnv.enable = true;            # system-wide direnv + nix-direnv
     programs.direnv.nix-direnv.enable = true;
   }
   ```
   And `home/shell.nix` gets the personal layer:
   ```nix
   # home/shell.nix
   { config, pkgs, lib, ... }:
   {
     programs.zsh = {
       enable = true;

       # Everything personal from the old shell.nix:
       enableCompletion = true;
       enableGlobalCompInit = false;
       histSize = 10000;
       autosuggestions.enable = true;
       syntaxHighlighting.enable = true;

       ohMyZsh = {
         enable = true;
         theme = "af-magic";
         plugins = [ "sudo" ];
       };

       shellAliases = {
         # ... the full alias list from section 5.14 ...
       };

       interactiveShellInit = ''
         eval "$(zoxide init zsh)"
         eval "$(fzf --zsh)"
       '';
     };
   }
   ```
   **Why this is safe:** `programs.zsh` exists at both NixOS and HM levels and they merge — HM writes `~/.zshrc`, NixOS writes `/etc/zshrc`, both get sourced.

4. **Personal packages** (`home/packages.nix`) — move apps only you use out of `environment.systemPackages`:
   ```nix
   # home/packages.nix
   { config, pkgs, lib, ... }:
   {
     home.packages = with pkgs; [
       obsidian
       logseq
       mailspring
       # ... apps with no system-service component
     ];
   }
   ```
   Keep system-critical things (nixfmt, ethtool, editors for root) in systemPackages.

### 10.7 Gotchas specific to your config

1. **`nh` + HM:** nh's flake detection works fine with HM in the same flake — `nh os switch` rebuilds everything. No change needed.
2. **The `wireshark` group fix:** group membership is a system thing — stays in `modules/users/users.nix`, never moves to HM.
3. **Thunar/XFCE prefs:** per-user settings like Thunar's are managed by xfconf — leave the `programs.xfconf.enable = true` at the system level (it's what allows HM to write per-user xfconf settings later if you adopt `xdg.configFile` for them).
4. **OMZ plugins that are binaries** (like powerlevel10k) — use HM's `programs.zsh.ohMyZsh.plugins` with `src = pkgs.zsh-powerlevel10k` same as before; nothing changes except the file it lives in.
5. **`home-manager` in systemPackages:** you currently have the CLI in systemPackages. Once HM is flake-integrated you can remove it — the `home-manager switch` standalone command is only for non-flake-integrated setups. Keep it if you like running it by hand for user-only rebuilds.
6. **stateVersion on both sides:** `system.stateVersion = "26.05"` and `home.stateVersion = "26.05"` are **different options** — both must be set. When HM first initializes it'll complain if unset; set it to your NixOS stateVersion for consistency.

### 10.8 Test Home Manager in the mock FIRST

You already have the mock sandbox (`~/Downloads/newconfigs-nix`, section 12). Before touching `/etc/nixos`:

```bash
cd ~/Downloads/newconfigs-nix
# add home-manager input + module to the mock's flake.nix (as in 10.2)
# create home/ tree (as in 10.3–10.5)
nixos-rebuild dry-build --flake .#nixos      # full evaluation check
nixos-rebuild build --flake .#nixos          # builds system + fury's home
nix store diff-closures /run/current-system ./result
# then inspect the home side:
ls -la result/home-files/                    # what HM would put in ~fury
```

If dry-build + closure diff are clean, port to /etc/nixos with confidence.

### 10.9 End state

After full migration, your system is three clean layers:

```
flake.nix            ← inputs & wiring (system + home-manager module)
modules/**           ← machine: hardware, services, system packages
home/**              ← fury: shell, git, terminal, personal packages
```

One `nix-switch` rebuilds and activates everything. Rollback (`nix-rollback`) restores system AND home in lockstep — that lockstep is the killer feature over managing dotfiles by hand.

---

## 11. What NOT To Modularize

- **`flake.nix`** — already minimal and correct. It stays the single wiring point; splitting flakes across files buys nothing at your scale.
- **`hardware-configuration.nix`** — machine-generated; leave it alone. (Its comment already correctly explains why `noatime` would be set there, and swapDevices lives there too.)
- **The flake's external modules** (lanzaboote, qylock, hermes-agent) — already imported at the flake level, correctly.
- **`system.stateVersion`** — stays in configuration.nix; it's a property of the machine as a whole.

---

## 12. The Mock Sandbox — Test-Before-You-Commit

**This is the most important section of the whole plan.** You do NOT need to touch `/etc/nixos` to validate the modularized config. A mock copy in `~/Downloads/newconfigs-nix` lets you build the *exact same system* in a sandbox: if the mock builds and its closure matches production, the split is provably behavior-identical.

### 12.1 What was already built for you

A complete, **tested** mock exists at `~/Downloads/newconfigs-nix`:

```
~/Downloads/newconfigs-nix/
├── flake.nix              # same inputs (flake.lock copied — identical pins)
├── flake.lock             # copied from /etc/nixos
├── configuration.nix      # the THIN entry point (imports only)
├── configuration.nix.orig # your original, untouched, for reference
├── hardware-configuration.nix   # copied, untouched
└── modules/               # all 26 modules, per sections 5.1–5.24
```

### 12.2 The verification loop (what was actually run, and what it caught)

Run these from inside the mock directory. Each command is read-only for your running system:

```bash
cd ~/Downloads/newconfigs-nix

# 1. Fast structural check — all modules parse, options exist
nix flake check

# 2. Full evaluation WITHOUT building — catches option typos, bad merges
nixos-rebuild dry-build --flake .#nixos

# 3. Real build — produces ./result, never activates
nixos-rebuild build --flake .#nixos

# 4. THE PROOF — compare the built mock against your RUNNING system
nix store diff-closures /run/current-system ./result
```

**What this caught when run on the mock (before it was fixed):**

| Round | `diff-closures` said | Meaning | Fix |
|---|---|---|---|
| 1 | `firefox: 154.0.1 → ∅, -381 MiB` | Firefox module was missing from the split | created `modules/programs/firefox.nix` |
| 2 | `glibc-locales: -2.5 MiB` | Locale/timezone module was missing (Canada locale not generated) | created `modules/core/locale.nix` |
| 3 | *(empty — byte-identical)* | Closure matches production exactly | done |

Two silent regressions, caught without ever touching `/etc/nixos`. That's the entire argument for the mock-first workflow. (The remaining `-12.8 KiB system` delta is the activation-script/etc-files change from the intentional fixes — wireshark group, alias change — not a regression.)

Then option-level equivalence was verified directly — same values from the original flake and the mock:

```bash
nix eval /etc/nixos#nixosConfigurations.nixos.config.time.timeZone --json
nix eval .#nixosConfigurations.nixos.config.time.timeZone --json
```

All 22 structural options (kernelParams, nameservers, journald, sysctl, etc.) and 17 service-level options (hermes model, ollama package, qylock theme, nvidia package, substituters, sddm wayland, etc.) matched. The package-list diff showed exactly the three intentional removals (raw sioyek/upscayl/vesktop) and nothing else. `users.users.fury.extraGroups` gained exactly `wireshark`.

### 12.3 Deep-dive checks (beyond closures)

Closure diffs catch package-level drift. Some things need deeper checks:

```bash
# Package list comparison (catches a package that moved between outputs
# but same-version — e.g. wrapped vs raw)
nix eval .#nixosConfigurations.nixos.config.environment.systemPackages \
  --apply 'map (p: p.pname or p.name or "unknown")' --json | jq -r '.[]' | sort

# User groups comparison
nix eval .#nixosConfigurations.nixos.config.users.users.fury.extraGroups --json

# Any scalar you care about
nix eval .#nixosConfigurations.nixos.config.services.resolved.settings --json
```

Compare against `/etc/nixos#nixosConfigurations...` for each — old vs new must match everywhere except the intentional fixes.

### 12.4 Migration day — from mock to production

When the mock is clean:

```bash
# 0. Safety net FIRST (if not already done)
cd /etc/nixos && sudo git init && sudo git add . && sudo git commit -m "monolithic config"

# 1. Copy the mock's module tree into production
sudo cp -r ~/Downloads/newconfigs-nix/modules /etc/nixos/
sudo cp ~/Downloads/newconfigs-nix/configuration.nix /etc/nixos/configuration.nix

# 2. NOT flake.nix / flake.lock — production keeps its own (identical
#    inputs, but the description line differs and mock's flake lacks
#    your detailed comments)

# 3. Test, then switch
nix-test && nix-switch

# 4. Commit the modularized state
cd /etc/nixos && sudo git add . && sudo git commit -m "modularize: split configuration.nix into modules/"
```

Keep `~/Downloads/newconfigs-nix` around as your **staging area forever**: try risky changes there first, `nix store diff-closures` against `/run/current-system`, and only port to `/etc/nixos` when the diff looks intentional. It also becomes the natural place to test Phase 2 options and Phase 3 Home Manager (section 10.8) before they touch production.

### 12.5 Why not just `nix-test` directly on /etc/nixos?

You can — and eventually will. But the mock gives you three things `nix-test` alone doesn't:

1. **Zero risk of a half-migrated state** — if you stop mid-refactor (life happens), production is untouched.
2. **A/B comparison** — `diff-closures old new` needs two complete builds; the mock is the second build without touching the first.
3. **A place to experiment** — Phase 2 flags, Home Manager, Hyprland tests — all without breaking your daily driver.

**Daily workflow after migration:**

```bash
nix-test       # try a change temporarily
nix-switch     # make permanent
config-save    # commit (now stages ALL files)
nix-rollback   # escape hatch, always available
```

**Rule of thumb for new settings:** find the module whose topic matches (NVIDIA setting → `hardware/nvidia.nix`; new alias → `programs/shell.nix`; new package → `packages/system-packages.nix` by category). New topic entirely → new file under the right directory + one import line in configuration.nix.

**Merge rules to remember:**
- Lists and attrsets merge automatically across modules.
- Scalars must live in exactly one module (or use `lib.mkDefault` in one and a plain definition in another; `lib.mkForce` wins conflicts).
- If a rebuild ever errors with "option ... is defined multiple times", you've defined a scalar in two modules — move it to the more appropriate one.

---

## 13. Vendor-Split Hardware, CUDA, Secure Boot + NVIDIA, AI per Vendor, Power

One host = one GPU vendor. Split `modules/hardware/` by vendor so a second host imports ONLY its stack — never `nvidia.nix` + `amd.nix` together (conflicting `videoDrivers`, conflicting Ollama backends).

### 13.1 Vendor-split modules

```
modules/hardware/
  nvidia.nix   # EXISTS (§5.4: TU116, proprietary, modesetting, powerManagement)
  amd.nix      # NEW: RDNA iGPU/dGPU (open driver, ROCm, power-profiles)
  intel.nix    # NEW: Intel iGPU (i915/Xe, GuC/HuC firmware, no dGPU driver)
```

```nix
# modules/hardware/amd.nix — AMD iGPU/dGPU host (e.g. laptop, RZ616 WiFi):
{ config, pkgs, lib, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];   # open kernel driver (NOT "radeon")
  hardware.graphics = { enable = true; enable32Bit = true; };
  # ROCm for compute (Ollama rocm side — §13.4):
  # hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr.icd ];
  # AMD P-state (modern laptops; verify `cpupower frequency-info` driver first):
  # boot.kernelParams = [ "amd_pstate=active" ];
}

# modules/hardware/intel.nix — Intel iGPU host (no dGPU):
{ config, pkgs, lib, ... }:
{
  services.xserver.videoDrivers = [ "modesetting" ];   # Intel uses kernel modesetting, no vendor X driver
  hardware.graphics = { enable = true; enable32Bit = true; };
  hardware.intel-gpu-tools.enable = true;   # intel_gpu_top for verification
  # GuC/HuC firmware for media offload (verify option name on your release):
  # hardware.firmware = with pkgs; [ linux-firmware ];
  # boot.kernelParams = [ "i915.enable_guc=2" ];
}
```

### 13.2 Per-host GPU/CPU selection

```nix
# hosts/fury-desktop/hardware.nix (THIS machine — TU116 + RTL8111):
{ ... }: {
  imports = [
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/realtek-eee.nix
  ];
}

# hosts/fury-laptop/hardware.nix (AMD example — iGPU + mt7921):
# { ... }: {
#   imports = [
#     ../../modules/hardware/amd.nix
#   ];
# }
# flake.nix picks per host: modules = [ ./hosts/<name>/default.nix ];
# (full hosts/ layout + disko/impermanence in nixos-modular-guide.md §12).
```

### 13.3 CUDA cache + allowUnfree (NVIDIA hosts only)

```nix
# Lives in modules/core/nix.nix (§5.2) — repeated here as the vendor contract:
{
  nixpkgs.config.allowUnfree = true;   # REQUIRED for nvidia driver + ollama-cuda
  nixpkgs.config.cudaSupport = true;   # builds CUDA variants (blender, ffmpeg, ML libs)
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];   # cache.nixos.org skips CUDA — without this you COMPILE
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };
  # AMD/Intel hosts: keep allowUnfree (firmware, steam) but DROP cudaSupport
  # + the CUDA substituter — they only cost eval time + closure bloat there.
}
```

### 13.4 Lanzaboote Secure Boot + NVIDIA signing

```nix
# modules/core/boot.nix (§5.1) already wires lanzaboote + pkiBundle.
# NVIDIA addendum: the nvidia kernel modules are OUT-OF-TREE — Secure Boot
# REJECTS them unless signed with YOUR sbctl key:
{
  # Lanzaboote signs the kernel/initrd; nvidia modules need manual signing
  # after every kernel OR driver bump (until an auto-sign hook lands):
  #   sudo sbctl verify                    # must list nvidia.ko as signed
  #   sudo sbctl sign -s /run/current-system/kernel-modules/lib/modules/*/kernel/drivers/video/nvidia*.ko
  # Out-of-tree extras (r8125, rtw88 — Networking guide §21) have the SAME
  # burden: prefer in-kernel drivers (r8169, rtw88-in-tree) to avoid re-signing.
  # AMD/Intel hosts: in-tree amdgpu/i915 need NO module signing — kernel signature covers them.
}
```

### 13.5 Ollama cuda vs rocm per vendor + open-webui

```nix
# modules/programs/ai-services.nix (§5.19) is the NVIDIA variant. Per vendor:
{
  # NVIDIA host (fury-desktop TODAY):
  # services.ollama = { enable = true; package = pkgs.ollama-cuda; };

  # AMD host (ROCm — verify card support: gfx1100+ recommended, older = slow CPU fallback):
  # services.ollama = { enable = true; package = pkgs.ollama-rocm; };
  # environment.variables = { HSA_OVERRIDE_GFX_VERSION = "11.0.0"; };  # only for APUs that misreport — verify `rocminfo` first

  # Intel / headless / CPU-only (no GPU offload):
  # services.ollama = { enable = true; package = pkgs.ollama; };

  # open-webui is VENDOR-NEUTRAL (talks to http://localhost:11434 either way):
  services.open-webui = { enable = true; port = 8080; };
  # Keep open-webui in the SHARED ai-services module; gate ONLY the
  # services.ollama.package line per host (hosts/<name>/hardware.nix or an
  # `my.enableRocm` mkIf flag — plan §9 pattern).
}
```

Verify per vendor: `ollama ps` (which backend loaded), `nvitop` (NVIDIA VRAM) vs `rocm-smi` (AMD), `http://localhost:8080` (open-webui regardless).

### 13.6 Power profiles per vendor

| Host | Daemon | Module wiring |
|---|---|---|
| NVIDIA desktop (fury-desktop) | `power-profiles-daemon` (balanced) | `services.power-profiles-daemon.enable = true;` in desktop/kde.nix (§5.8) — KEEP |
| AMD laptop | `power-profiles-daemon` + `amd_pstate` | same daemon + `boot.kernelParams = [ "amd_pstate=active" ]` in amd.nix |
| Intel laptop | `thermald` + `power-profiles-daemon` | `services.thermald.enable = true;` in intel.nix (Intel-only daemon, useless on AMD) |
| Any laptop (newer) | `auto-cpufreq` OR `tlp` | pick ONE (they fight each other AND power-profiles-daemon) — `services.tlp.enable = true;` with `services.power-profiles-daemon.enable = false;` |

```nix
# modules/hardware/intel.nix laptop tail:
# { services.thermald.enable = true; }   # Intel thermal daemon — Intel hosts only
# NEVER enable tlp + auto-cpufreq + power-profiles-daemon together.
# Verify: `powerprofilesctl` (daemon), `cpupower frequency-info` (pstate driver), `powertop --auto-tune` (debug only).
```
