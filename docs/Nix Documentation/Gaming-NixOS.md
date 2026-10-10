# Gaming on NixOS

An exhaustive, independently-usable reference for gaming on NixOS — Steam, Proton, performance tooling, controllers, game streaming, anti-cheat compatibility, and kernel/GPU tuning. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual · NixOS Options Search · nixpkgs module sources (`programs/steam.nix`, `programs/gamemode.nix`, `programs/gamescope.nix`, `hardware/xpadneo.nix`, `hardware/xone.nix`, `services/hardware/joycond.nix`, `nixos/tests/sunshine.nix`) · ProtonDB / Arch Wiki Gaming pages · Valve developer docs. Schema verified against nixpkgs release-26.05 — marked **[SCHEMA]** where options are version-sensitive; always cross-check <https://search.nixos.org/options> before adopting.

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [Steam (complete setup)](#2-steam-complete-setup)
3. [Proton & Compatibility Layers](#3-proton-compatibility-layers)
4. [Performance: Gamemode, MangoHud, Scxtk](#4-performance-gamemode-mangohud-scxtk)
5. [Gamescope (SteamOS-style session/compositor)](#5-gamescope)
6. [GPU Drivers & Tuning](#6-gpu-drivers-tuning)
7. [Controllers & Input](#7-controllers-input)
8. [Game Streaming (Sunshine + Moonlight)](#8-game-streaming-sunshine-moonlight)
9. [Anti-Cheat: What Works and What Doesn't](#9-anti-cheat-what-works-and-what-doesnt)
10. [Non-Steam Launchers (Heroic, Lutris, Bottles)](#10-non-steam-launchers-heroic-lutris-bottles)
11. [Audio & Networking for Games](#11-audio-networking-for-games)
12. [Kernel & System Tuning](#12-kernel-system-tuning)
13. [Troubleshooting](#13-troubleshooting)
14. [Vendor Matrix: GPU + CPU + Launch Options + HM Proton-GE + MangoHud + VR](#14-vendor-matrix-gpu--cpu--launch-options--hm-proton-ge--mangohud--vr)
15. [Reference Index](#15-reference-index)

---

## 1. The Big Picture

NixOS gaming today is genuinely first-class. The stack, bottom to top:

```
Kernel (KVM + full preemption + sched-ext)         ← §12
GPU driver (AMD Mesa in-tree / NVIDIA from nixpkgs)← §6
Steam + Proton (wine-based Windows compat)         ← §2–3
gamemode (CPU governor + niceness)                 ← §4
gamescope (microcompositor: HDR, FSRIE, scaling)   ← §5
MangoHud (overlay metrics)                         ← §4
Sunshine (stream to any Moonlight client)          ← §8
```

Two NixOS-specific things to internalize:

1. **Steam needs unfree enabled** and runs in a FHS-ish sandbox NixOS builds for it — 32-bit libs, udev rules, and PulseAudio/PipeWire glue are handled by the module, but *only if* you enable the module rather than just adding the package.
2. **Anti-cheat games are the one real frontier** (§9): some explicitly support Proton (and thus work), some tolerate it, some ban it. Check ProtonDB before buying.

## 2. Steam (complete setup)

```nix
{ config, pkgs, ... }: {
  # The ONLY correct way to install Steam — the module (not the package):
  programs.steam = {
    enable = true;

    # Replace the package to inject env vars into ALL steam games:
    # (games launched by steam inherit these)
    # package = pkgs.steam.override {
    #   extraEnv = {
    #     MANGOHUD = true;       # mangohud preload in every game (§4)
    #     OBS_VKCAPTURE = true;  # OBS game capture via vulkan (§4)
    #     RADV_TEX_ANISO = 16;   # AMD: anisotropic filtering clamp
    #   };
    #   extraLibraries = p: with p; [
    #     # extra .so files games sometimes need (rare — add on demand)
    #   ];
    # };

    # Steam client and Proton need 32-bit libs; remote play needs this:
    # (the module sets these itself, listed for understanding)

    remotePlay.openFirePorts = true;    # Steam Remote Play: open firewall ports
    dedicatedServer.openFirePorts = true; # srcds/Valve dedicated servers

    # Extra compatibility tools visible in Steam's "Properties → Compatibility":
    extraCompatPackages = with pkgs; [
      proton-ge-bin    # GE-Proton — better for many non-Valve titles
    ];

    # Protontricks/Winetricks helper (manage proton prefixes):
    # install via environment.systemPackages (below)
  };

  # Required for Steam (EULA) + most game-adjacent tools:
  nixpkgs.config.allowUnfree = true;

  # Firewall: Steam's own traffic works without these; open for remote
  # play INTO this machine (module option above does it if enabled):
  networking.firewall.allowedUDPPorts = [ 27031 27036 ];  # steam remote play
  networking.firewall.allowedTCPPorts = [ 27036 27037 ];

  environment.systemPackages = with pkgs; [
    # NOTE: don't list `steam` here — programs.steam.enable already adds
    # cfg.package + cfg.package.run to systemPackages.
    steam-run        # `steam-run ./game-binary` — run non-steam linux
                     # binaries with steam's FHS-like environment
    protontricks     # winetricks for proton prefixes:
                     #   protontricks 12345 winetricks vcrun2022
    protonup-ng      # manage custom Proton-GE installs via CLI
    # gamescope / gamemode / mangohud handled in their sections
    heroic           # Epic/GOG/Amazon launcher (§10)
    lutris           # general wine/launcher manager (§10)
  ];

  # Your user owns the games — flatpak not needed on NixOS; native is
  # more reliable for controller/friends overlay glue.
}
```

### 2.1 Steam session from SDDM (SteamOS-like)

```nix
{ ... }: {
  # Adds a "Steam (gamescope)" entry to your login screen — boots into
  # a Steam-only compositor session, console-like experience:
  programs.steam.gamescopeSession = {
    enable = true;

    # Arguments passed to gamescope for the session (§5 for meanings):
    args = [
      "--rt"                # realtime priority (needs gamemode or rt privs)
      "-W" "2560" "-H" "1440"   # internal render size
      "-w" "2560" "-h" "1440"   # output size
      "-F" "fsr-upscale"     # upscale filter for sub-native rendering
      "--fsr-sharpness" "4"      # 0..20 (higher = sharper)
      "--adaptive-decorations"   # no borders on games
    ];

    # Environment for the session:
    env = {
      MANGOHUD = "1";          # overlay in session (§4)
      DXVK_HUD = "0";
    };
  };
}
```

## 3. Proton & Compatibility Layers

Proton runs Windows games inside Wine-based compatibility. What you need on NixOS:

```nix
{ config, pkgs, ... }: {
  # Valve's Proton ships with the steam module — nothing to add for the
  # default. For MORE/NEWER compatibility:
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  # Wine itself (for non-Steam usage: lutris, manual runs):
  environment.systemPackages = with pkgs; [
    wine-staging        # or wineWowPackages.stable (both 32+64bit)
    # wineWowPackages.staging
    winetricks          # per-prefix tweaks (fonts, dlls, runtimes)
    bottles             # friendly per-app wine prefix manager (§10)
  ];
}
```

**Per-game Proton choice:** Steam → (right-click game) → Properties → Compatibility → Force the use of → pick **GE-Proton (proton-ge-bin)** (appears after `extraCompatPackages`) or the bundled version. Re-download shaders on first launch is normal (long first start).

**Key facts:**
- Most single-player games: **Proton (ProtonDB rating Gold+)** — work fine or with minor tweaks.
- Always check <https://www.protondb.com> for per-title settings before blaming your setup.
- Native Linux games generally just work; some old ones want `steam-run` to find 32-bit libraries.

## 4. Performance: Gamemode, MangoHud, Scxtk

### 4.1 Gamemode — on-demand CPU governor / nice level

```nix
{ config, pkgs, ... }: {
  programs.gamemode = {
    enable = true;

    # Extra config merged into /etc/gamemode.ini:
    settings = {
      general = {
        softrealtime = "auto";    # SCHED_ISO when beneficial
        renice = 10;              # -10 boost via renice: gamemoderun <cmd>
      };
      # GPU-specific tweaks — uncomment for your vendor:
      # [gpu]
      # apply_gpu_optimisations = "accept-responsibility"  # NVIDIA power
      # [amd]  (via corectrl instead — see §6)
    };

    # Custom scripts run when a game starts/stops (hook anything):
    # e.g. start a fan curve, stop backups, enable recording.
    # No startScripts/endScripts options exist — use settings.custom.start/end
    # (written into gamemode.ini [custom]):
    # settings.custom.start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
    # settings.custom.end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
  };

  # Use per-game: right-click game → Properties → Launch Options:
  #   gamemoderun %command%
  # (works for steam-run, lutris, heroic, anything CLI too)
}
```

### 4.2 MangoHud — the overlay

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ mangohud ];

  # System-wide default config (users can override at
  # ~/.config/MangoHud/MangoHud.conf):
  environment.etc."MangoHud/MangoHud.conf".text = ''
    # What to show — the useful gaming set:
    fps                    # frames per second
    frame_time             # per-frame ms graph
    frame_timing           # frametime graph (latency spikes!)
    cpu_stats              # cpu load + clocks
    cpu_temp
    gpu_stats
    gpu_temp
    vram                   # VRAM usage
    ram                    # system RAM
    position=top-left
    horizontal             # horizontal layout
    no_display             # START hidden; toggle with Shift_R+F12
    # toggles: Shift_R+F12 show, Shift_L+F12 toggle logging
  '';

  # Per-game usage:
  #   Steam launch options: mangohud %command%
  #   OR via steam package env (see §2): MANGOHUD=true for all games
}
```

### 4.3 The "vrr/freesync" note

```nix
{ config, pkgs, ... }: {
  # AMD + KDE Plasma: enable VRR per-display in KDE settings
  # ("Display → Adaptive Sync"). Wayland-native, nothing else needed.
  # NVIDIA: enable "Allow G-SYNC on monitor not validated" in nvidia-settings
  # (per-user; persists via nvidia-persistenced or settings save).
  # No system-wide NixOS option — it's per-display state.
}
```

## 5. Gamescope

Valve's micro-compositor: window management + filtering for a game. On NixOS it's a program module with sane defaults:

```nix
{ config, pkgs, ... }: {
  programs.gamescope = {
    enable = true;

    # sysenv tweaks passed to gamescope'd processes:
    # (cap_sysnice lets gamescope raise game priority without gamemode)
    # env = { DISPLAY = ":0"; };
    # args = [ "--rt" ];  # when you need realtime
  };

  # Launch a game through it directly:
  #   gamescope -W 2560 -H 1440 -F fsr-upscale -- %command%
  #
  # Common flags (official gamescope --help covers all):
  #   -W/-H   internal resolution (game renders AT this)
  #   -w/-h   output resolution (gamescope displays AT this)
  #   -F fsr-upscale | nis | linear | nearest
  #           upscaling filter; FSR = AMD's, best general choice
  #   --immediate-flips        lowest latency present mode
  #   --force-grab-cursor      games that ignore cursor capture
  #   --hdr-enabled            HDR (needs compatible stack §6)
  #   --mangoapp               overlay integration inside gamescope
}
```

Use cases:
- **Ultrawide trick:** render at 16:9 internal, output at native 21:9 without black bars — `-W 2560 -H 1080 -w 3440 -h 1440 -F fsr-upscale`
- **HDR + HDR saturation:** the only way to do real HDR on Steam/Proton reliably.
- **Frame limiting:** `--rt --force-grab-cursor -r 144` for latency-fighting.

## 6. GPU Drivers & Tuning

### 6.1 AMD (Radeon — open driver)

```nix
{ config, pkgs, ... }: {
  # Mesa RADV is in-tree and enabled automatically when a GPU is
  # detected. What you might add explicitly:
  hardware.graphics = {
    enable = true;
    # 32-bit for Steam/Proton games (DXVK needs it):
    enable32Bit = true;

    # Vulkan layers etc. you may want:
    extraPackages = with pkgs; [
      amdvlk            # AMD's alternative vulkan driver (default RADV
                        # usually wins for games; add only if a title
                        # demands it — then select via env)
      mangohud
    ];
  };

  # Overclock/undervolt GUI (AMD — Polaris+):
  # programs.corectrl = {           # [SCHEMA] check current option path
  #   enable = true;
  # };

  # Environment toggles for AMD performance (via steam env §2 or shell):
  #   RADV_TEX_ANISO=16        clamp aniso filtering
  #   RADV_PERFTEST=gpl         graphics pipeline libo (on by default now)
}
```

### 6.2 NVIDIA

```nix
{ config, pkgs, lib, ... }: {
  # Your hardening guide's known-good NVIDIA setup applies. Gaming
  # additions on top:
  services.xserver.videoDrivers = [ "nvidia" ];  # or hardware.nvidia

  hardware.graphics = {
    enable = true;
    enable32Bit = true;       # REQUIRED for most Proton/DXVK games
  };

  hardware.nvidia = {
    modesetting.enable = true;   # required for Wayland/gamescope

    # The open kernel modules — REQUIRED for Turing+ (GTX 16/20+):
    # (TU116 GTX 1660 SUPER = Turing → open works, and is required
    #  for the newest driver branches)
    open = true;

    # Fine-grained:
    # powerManagement.enable = true;   # runtime power off-load
    # nvidiaSettings = true;           # nvidia-settings GUI
  };

  # DXVK on NVIDIA needs no env vars; for VKD3D (DX12):
  #   VKD3D_CONFIG=dxr    (RT in some titles; rarely needed)
}
```

### 6.3 Intel Arc / iGPUs

```nix
{ config, pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver   # VA-API video accel
      vpl-gpu-rt           # newer QuickSync
    ];
  };
}
```

## 7. Controllers & Input

### 7.1 Xbox controllers

```nix
{ config, pkgs, ... }: {
  # xpadneo — the superior Bluetooth driver for Xbox One/Series pads:
  hardware.xpadneo.enable = true;

  # xone — for Xbox One/Series USB dongles:
  hardware.xone.enable = true;

  # The old in-kernel xpad driver still handles USB; enable uaccess.
  # NOTE: pkgs.xpad-nokernel was removed — in-kernel xpad +
  # game-devices-udev-rules (§7.4) covers the "guitar/drum" edge cases.
}
```

### 7.2 Nintendo Pro Controllers / Joy-Cons

```nix
{ config, pkgs, ... }: {
  # joycond — the hid-nintendo userspace daemon:
  services.hardware.joycond.enable = true;

  # NOTE: no programs.joycond-cemuhook option exists — motion (cemuhook)
  # translation is handled via joycond/cemuhook userspace tools, not a
  # NixOS program option.
}
```

### 7.3 PlayStation, Steam Deck, generic

```nix
{ ... }: {
  # DualShock/DualSense work in kernel (hid-playstation) — nothing needed.
  # Steam Input handles them all (Steam → Controller → big picture config).

  # "SDL_GAMECONTROLLERCONFIG" legacy mapping issues → prefer letting
  # Steam Input do remapping rather than system hacks.
}
```

### 7.4 Steam Input + udev

```nix
{ config, pkgs, ... }: {
  # Steam's udev rules cover most pads when running via the module.
  # For non-steam games using SDL directly, expose controller udev:
  services.udev.packages = [ pkgs.game-devices-udev-rules ];
}
```

## 8. Game Streaming (Sunshine + Moonlight)

Stream YOUR NixOS desktop/games to Moonlight clients (Steam Deck, phone, TV, another PC) — self-hosted game streaming:

```nix
{ config, pkgs, ... }: {
  # [SCHEMA] module verified against release-26.05 tests — the module is
  # services.sunshine:
  services.sunshine = {
    enable = true;

    # open firewall automatically (base port 47989 TCP + offsets):
    openFirewall = true;

    # DRM/KMS capture needs CAP_SYS_ADMIN (security wrapper):
    capSysAdmin = true;

    # start with graphical-session.target (default true):
    autoStart = true;
    # (module auto-enables hardware.uinput + services.avahi + udev rules)

    # Declarative settings — freeform sunshine.conf keys (see
    # docs.lizardbyte.dev/projects/sunshine config). If set, web UI is locked:
    settings = {
      sunshine_name = "fury-os";
      port = 47989;
    };
  };

  # NOTE: no "sunshine" group exists — no extraGroups needed; the service
  # runs as a systemd user unit.

  # Moonlight client — install on the receiving end (phone/other PC):
  environment.systemPackages = with pkgs; [ moonlight-qt ];
}
```

Pairing: open the Sunshine UI at `https://localhost:47989` (self-signed cert is normal), set a PIN, enter it on the Moonlight client. Then add "Applications" in Sunshine to launch specific games via steam-run.

## 9. Anti-Cheat: What Works and What Doesn't

The state of Linux gaming's last frontier (as of kernel 6.x / Proton 9/10):

| Status | Meaning | Examples |
|---|---|---|
| **Supported** | Vendor enables Linux support in their AC | Apex, War Thunder, Destiny 2, Fortnite **officially NO** (Epic refuses), Halo Infinite |
| **Runs** | Works in practice via Proton | Elden Ring (EAC enabled), Baldur's Gate 3, Cyberpunk |
| **Banned/broken** | Actively blocks Wine/VMs | Rainbow Six Siege (BattlEye no-Linux), most Riot titles (Vanguard), GTA Online (partial risk), Valorant, Tarkov |

```nix
{ config, pkgs, ... }: {
  # Nothing here fixes a hard-blocked title. What you CAN do:
  # 1. Hide Wine/VM strings only where games detect cosmetic stuff:
  #    (per-game env via steam package override, §2)
  #    env = { WINE_HIDE... } — NOT recommended; detection attempts can
  #    trigger bans. Don't fight anti-cheat.

  # 2. The legitimate escape hatch: a Windows VM with GPU passthrough —
  #    see Virtualization-NixOS.md §9 + Looking Glass guide. Anti-cheat
  #    vendors currently treat KVM+VFIO as "real hardware" for most titles,
  #    but check your game's stance first (some detect hypervisor CPU flags).

  # 3. For BattlEye titles with Linux support enabled by devs, proton
  #    battleye runtime is in steam by default — nothing to configure.
}
```

## 10. Non-Steam Launchers (Heroic, Lutris, Bottles)

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Heroic — Epic Games Store, GOG, Amazon Prime:
    heroic

    # Lutris — the "anything" runner (GOG, emulators, manual wine):
    lutris

    # Bottles — clean per-app wine prefixes, runners management:
    bottles

    # itch.io:
    # itch

    # PlayStation/Xbox cloud via browser is best (chromium/firefox)
  ];

  # Flatpak alternatives exist for all three; native NixOS packages
  # integrate better with gamemode/mangohud/controllers. If a native
  # package breaks (rare), flatpak fallback:
  # services.flatpak.enable = true;
}
```

Each has its own runner management (they download wine/protonge themselves into `~/.cache` or their own dirs). Add games to Steam as non-Steam shortcuts to unify with Steam Input.

## 11. Audio & Networking for Games

```nix
{ config, pkgs, ... }: {
  # PipeWire with the low-latency games node:
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;    # 32-bit games' audio
    pulse.enable = true;
    # Quantum (buffer) tweaks for lower latency — a good default balance:
    # wireplumber.enable = true;
    # extraConfig.pipewire = {
    #   "context.properties" = {
    #     "default.clock.rate" = 48000;
    #     "default.clock.quantum" = 1024;  # 21ms @48k; halve for pro-audio
    #   };
    # };
  };

  # Network for latency-sensitive online games:
  # nothing to enable; quality comes from bufferbloat management —
  # if your router runs sqm/cake you're done. Locally you can:
  # networking.firewall.allowedUDPPorts = [ 3478 43757 ];  # steam voice
  # (module handles most of it via remotePlay options)
}
```

## 12. Kernel & System Tuning

```nix
{ config, pkgs, ... }: {
  # ---- Scheduling ------------------------------------------------------
  # "schedutil" is the default & best for most desktops/games.
  # Enable full preemption for lower input latency:
  boot.kernelParams = [ "preempt=full" ];

  # schd-ext (modern scheduler framework; useful on large-core-count CPUs):
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # ---- zram for big-map games (already in your config) -----------------
  zramSwap.enable = true;

  # ---- Transparent Hugepages: 'madvise' is best for games -------------
  boot.kernel.sysctl."vm.max_map_count" = 1048576; # Star Citizen/CS2 scale
  # (was 2147483642 — overflows signed int32, rejected by sysctl)

  # ---- Limits -----------------------------------------------------------
  # Steam's file handles + some games need higher nofile:
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "65536"; }
  ];
}
```

## 13. Troubleshooting

| Symptom | Fix |
|---|---|
| Steam won't launch / blank window | `programs.steam.enable = true` (not just the package) + `nixpkgs.config.allowUnfree = true`. Check 32-bit: `hardware.graphics.enable32Bit = true`. |
| Game runs at 5 FPS | DXVK is missing Vulkan → `hardware.graphics.enable = true` + driver §6. Check `vulkaninfo --summary`. |
| "Could not locate platform tools" / wineprefix errors | Run via `steam-run ./binary` for non-steam binaries — it re-creates the FHS env. |
| Controller works in Steam, not in game | Add game as non-Steam shortcut + enable Steam Input overlay for it; or the game reads evdev directly: add `services.udev.packages = [ pkgs.game-devices-udev-rules ]`. |
| Anti-cheat error on launch | Check ProtonDB for that title. If "unsupported", it's the vendor — §9. Don't attempt cloaking. |
| Gamescope black screen on NVIDIA | `hardware.nvidia.modesetting.enable = true` + reboot. Wayland session + `open = true` for Turing+ — §6.2. |
| Proton-GE not in compatibility list | It appears only after `programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ]` + restart Steam fully (from tray). |
| Fortnite/Valorant won't work | Not supported — no fix exists. Vanguard requires real Windows boot. |
| Voice chat silent in game | PipeWire 32-bit: `alsa.support32Bit = true`. Some games need `PW_FORCE_32BIT...`? No — the option is sufficient. |
| Remote play laggy | It's a router/bufferbloat issue 90% of the time — enable SQM/cake on router. Also §4.1 gamemode on the host game. |

## 14. Vendor Matrix: GPU + CPU + Launch Options + HM Proton-GE + MangoHud + VR

### 14.1 NVIDIA full stack (settings, powermizer, vaapi, explicit-sync, NVENC, DLSS/RTX)

```nix
{ config, pkgs, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = { enable = true; enable32Bit = true; };
  hardware.nvidia = {
    modesetting.enable = true;  # -> nvidia-drm.modeset=1 + fbdev=1 (Wayland/explicit-sync)
    open = true;                # Turing+ (GTX 16/RTX); false only for pre-Turing
    nvidiaSettings = true;      # nvidia-settings GUI (powermizer + G-SYNC toggles)
    powerManagement.enable = true;      # suspend/resume VRAM save (can break sleep)
    # powerManagement.finegrained = true;  # Turing+ PRIME offload only
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  environment.systemPackages = with pkgs; [
    nv-codec-headers        # NVENC/NVDEC headers for obs-studio + sunshine
    libva-nvidia-driver     # nvidia-vaapi: Firefox/Chromium video decode via NVDEC
    vulkan-tools            # vulkaninfo --summary to verify NVK vs proprietary
  ];
  # Powermizer (prefer max perf per-game, not globally):
  #   nvidia-settings -a '[gpu:0]/GpuPowerMizerMode=1'  # 0=auto 1=max-perf 2=auto-low
  # Explicit-sync (Wayland tearing-free on 545+): needs modesetting + Wayland
  # compositor with explicit-sync protocol (KDE 6 / Hyprland) — no NixOS toggle.
  # DLSS/RTX in Proton: VKD3D_CONFIG=dxr + per-game Proton-GE (§14.5); requires
  # proprietary driver (NVK lacks mesh-shader perf for RT today).
}
```

### 14.2 AMD full stack (amdgpu, RADV vs AMDVLK, ROCm/OpenCL, FSR, LACT/corectrl)

```nix
{ config, pkgs, ... }: {
  hardware.graphics = {
    enable = true; enable32Bit = true;
    extraPackages = with pkgs; [
      # RADV (Mesa, default) wins for games — AMDVLK only when a title demands it:
      # amdvlk  # then select: VK_ICD_FILENAMES=/share/vulkan/icd.d/amd_icd64.json
      rocmPackages.clr.icd  # ROCm OpenCL (Blender/DaVinci, NOT games — heavy closure)
    ];
  };
  # boot.initrd.kernelModules = [ "amdgpu" ];  # early KMS (flicker-free boot)
  environment.systemPackages = with pkgs; [
    lact              # AMD/NVIDIA/Intel fan curves + OC (modern corectrl successor)
    # corectrl        # older AMD-only OC GUI — pick LACT xor corectrl, not both
    radeontop         # VRAM/GPU util for MangoHud cross-check
  ];
  # FSR: in-game FSR2/3 > gamescope -F fsr-upscale (§5). RADV perf knobs:
  #   RADV_TEX_ANISO=16 RADV_PERFTEST=gpl (now default) via §2 steam extraEnv
}
```

### 14.3 Intel full stack (Xe/Arc mesa ANV, Xe vs i915, GuC/HuC, presentMon)

```nix
{ config, pkgs, ... }: {
  hardware.graphics = {
    enable = true; enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver  # VA-API (Arc + iGPU decode)
      vpl-gpu-rt          # QuickSync successor
      intel-compute-runtime  # OpenCL on Arc (Blender, not games)
    ];
  };
  # Driver choice: kernel 6.8+ auto-uses xe for Arc (Battlemage needs xe + linux-firmware).
  # Force legacy i915 for debug only: boot.kernelParams = [ "i915.force_probe=..." ];
  # GuC/HuC: boot.kernelParams = [ "xe.enable_guc=2" ]; (Arc) / [ "i915.enable_guc=2" ]; (older)
  # Mesa ANV is the Intel Vulkan driver (auto) — verify: vulkaninfo | grep -i intel
  environment.systemPackages = with pkgs; [ intel-gpu-tools ];  # intel_gpu_top = MangoHud cross-check
}
```

### 14.4 CPU: AMD (zen governors, amd_pstate) vs Intel (intel_pstate, thermald, undervolt)

```nix
{ config, pkgs, ... }: {
  # AMD Zen: amd_pstate=active (default on Zen2+ kernels) + schedutil governor:
  # boot.kernelParams = [ "amd_pstate=active" ];  # explicit; passive only for debug
  # powerProfilesDaemon or auto-cpufreq picks performance on gamemode (§4.1)
  # Intel: intel_pstate=active (default) + thermald prevents throttle-plunge:
  services.thermald.enable = true;  # Intel only — harmless on AMD, wastes cycles
  # Undervolt: Intel (intel-undervolt tool, per-model offsets) — AMD Zen: BIOS PBO
  # curve instead (no stable OS undervolt). Never ship undervolt in shared guide.
  services.power-profiles-daemon.enable = true;  # balanced/performance profiles
}
```

### 14.5 Per-game launch options + Proton-GE via HM + MangoHud per-vendor + VR note

```bash
# Steam launch options (Properties -> General):
gamemoderun mangohud %command%                          # baseline (all vendors)
RADV_TEX_ANISO=16 gamemoderun mangohud %command%        # AMD extra filtering
VKD3D_CONFIG=dxr gamemoderun %command%                  # NVIDIA RTX/DXR titles
PROTON_HIDE_NVIDIA_GPU=0 PROTON_ENABLE_NVAPI=1 %command% # NVIDIA DLSS/NVAPI expose
gamescope -W 2560 -H 1440 -F fsr-upscale -- mangohud %command%  # upscale + overlay
```

```nix
{ config, pkgs, ... }: {
  # Proton-GE via Home Manager (per-user, no sudo — complements §2 system-wide):
  # home-manager: home.packages = [ pkgs.proton-ge-bin ];
  # Then: compatibilitytools.d link: ln -s ${pkgs.proton-ge-bin}/bin/* ~/.steam/root/compatibilitytools.d/
  # Or HM declarative: programs.steam? (HM has no steam module — use system §2
  # extraCompatPackages for system GE + protonup-ng for per-user bleeding edge).
  environment.etc."MangoHud/MangoHud.conf".text = ''
    fps frame_time cpu_stats gpu_stats vram ram
    # Per-vendor extras: NVIDIA shows gpu power draw, AMD shows vram + fan via lact,
    # Intel shows GT C-state — same config file, driver exposes what exists.
  '';
  # VR note: Monado (openxr) + SteamVR via proton — AMD RADV best supported,
  # NVIDIA needs proprietary + modesetting, Intel Arc VR experimental.
  # Anti-cheat VR titles (Vanguard) still Windows-only (§9). Wired Quest via ALVR:
  # environment.systemPackages = with pkgs; [ alvr ]; # + openFirewall 9943-9944
}
```

## 15. Reference Index

- ProtonDB per-game reports: <https://www.protondb.com>
- areweanticheatyet — anti-cheat compatibility tracker: <https://areweanticheatyet.com>
- Gamescope README (flags/usage): <https://github.com/ValveSoftware/gamescope>
- MangoHud config docs: <https://github.com/flightlessmango/MangoHud>
- Gamemode README: <https://github.com/FeralInteractive/gamemode>
- nixpkgs steam module: `nixos/modules/programs/steam.nix`
- nixpkgs sunshine test (canonical module usage): `nixos/tests/sunshine.nix`
- Arch Wiki Gaming: <https://wiki.archlinux.org/title/Gaming>
- Virtualization companion guides: `Virtualization-NixOS.md`, `Looking-Glass-Virtualization-NixOS.md`
- Customization companion guide: `Customization-NixOS.md`
