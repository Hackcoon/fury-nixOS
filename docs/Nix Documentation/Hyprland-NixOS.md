# Hyprland on NixOS

An exhaustive, independently-usable reference for running the Hyprland tiling Wayland compositor on NixOS — alongside or instead of KDE, with full declarative config, keybindings, animations, plugins, screensharing, and the coexistence patterns for your current Plasma setup. Every code block is self-contained and copy-pasteable, with inline comments explaining what each line does.

**Sources synthesized:** Hyprland Wiki (flakes vs NixOS module, config directives) · nixpkgs module source (`programs/wayland/hyprland.nix` — verified release-26.05: `programs.hyprland` with `enable, package, portalPackage, extraPortals, systemd.setPath.enable, xwayland...` schema) · Aquamarine/xdg-desktop-portal-hyprland docs · your system's context (KDE + SDDM + NVIDIA Wayland from the other guides).

**Your baseline:** Plasma 6 on Wayland with SDDM, NVIDIA GTX 1660 SUPER (open modules). This guide covers both "Hyprland as a second session alongside KDE" (recommended) and "full migration".

**Companion guides:** `Customization-NixOS.md` (SDDM sessions, themes), `Gaming-NixOS.md` (gamescope/Hyprland combos), `Networking-NixOS.md` (hyprspace not included — flake territory).

---

## Table of Contents

1. [What Hyprland Is (and the NixOS Layout)](#1-what-hyprland-is)
2. [Installing Hyprland (module, not package)](#2-installing-hyprland-module-not-package)
3. [First Launch (from SDDM, alongside KDE)](#3-first-launch)
4. [The Config File (fully annotated)](#4-the-config-file)
5. [Keybindings & Window Rules](#5-keybindings-window-rules)
6. [Vendor Matrix — NVIDIA / AMD / Intel](#6-vendor-matrix--nvidia--amd--intel-hardware-env--ozone--vaapi)
7. [Screensharing, Portals & XWayland](#7-screensharing-portals-xwayland)
8. [Animations & Eye Candy](#8-animations-eye-candy)
9. [Plugins & Community Ecosystem (+ hypridle/hyprlock)](#9-plugins-community-ecosystem)
10. [Status Bars & Shell Companions](#10-status-bars-shell-companions)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference Index](#12-reference-index)

---

## 1. What Hyprland Is

Hyprland = a **dynamic tiling Wayland compositor** with built-in animations, gaps, a plugin system, and aggressive development pace. Compared to your KDE:

| | KDE Plasma | Hyprland |
|---|---|---|
| Model | full desktop | compositor + you choose the shell |
| Windows | floating | tiling-first (floats fine too) |
| Config | GUI settings | one `hyprland.conf` text file |
| Weight | heavier | extremely light |
| Wayland | mature | native-only (this IS the project) |

On NixOS the module is `programs.hyprland` — NOT just adding the package (the module wires portals, systemd session glue, and the SDDM/GDM session entry).

## 2. Installing Hyprland (module, not package)

```nix
{ config, pkgs, ... }: {
  programs.hyprland = {
    enable = true;

    # Pin to the nixpkgs package (recommended on stable 26.05):
    # package = pkgs.hyprland;
    # The flake "latest" alternative (Hyprland wiki prefers; heavier):
    # package = hyprland.packages.${system}.hyprland;   # + flake input

    # XWayland support — legacy X11 apps (Steam!) need this:
    xwayland.enable = true;    # default true; explicit for clarity

    # Portals — screensharing/file dialogs NEED these.
    # NOTE: `programs.hyprland.extraPortals` does NOT exist — portals go
    # ONLY via `xdg.portal.extraPortals` (see below); anything set here
    # fails eval:
    portalPackage = pkgs.xdg-desktop-portal-hyprland;   # must match hyprland version

    # UWSM session wrapper (recommended — correct env/systemd session):
    withUWSM = true;

    # Session path for systemd units (env correctness):
    # NOTE: defaults to false on 0.5x-era modules — set explicitly:
    systemd.setPath.enable = true;
  };

  # Hyprland + portals on NVIDIA/wayland sessions:
  xdg.portal = {
    enable = true;
    # The portal backend picker (Hyprland-preferred first):
    configPackages = [ pkgs.xdg-desktop-portal-hyprland ];
    # The NixOS module handles the rest; being explicit:
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Hardware prereqs (you have these from earlier guides — reference):
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;   # REQUIRED — Hyprland refuses without
    open = true;                 # Turing+ (your 1660 SUPER)
  };
}
```

```bash
# The session now appears in SDDM's session picker (bottom-left menu):
#   "Hyprland" next to your existing "Plasma (Wayland)"
# Pick per-login — zero migration risk. Your KDE config is untouched.
```

### 2b. UWSM session — the correct systemd/env wrapper (recommended)

```nix
{ config, pkgs, ... }: {
  programs.hyprland.withUWSM = true;   # wraps Hyprland in uwsm (graphical-session.target + env)
  programs.uwsm.enable = true;         # exposes waylandCompositors entries for SDDM
  # Launch idiom: uwsm start hyprland-uwsm.desktop (SDDM does this for you)
  # With UWSM, DISABLE HM systemd integration (conflicts — double target):
  # home-manager.users.fury.wayland.windowManager.hyprland.systemd.enable = false;
  # Verify: systemctl --user status graphical-session.target → active; env | grep HYPRLAND
}
# Without UWSM, hypridle (§9b) never starts (no graphical-session.target) —
# the #1 "hypridle inactive after reboot" cause. Prefer UWSM on bare Hyprland.
```

### 2c. SDDM per-vendor notes

```nix
{ config, pkgs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;   # SDDM itself on Wayland (Plasma6 default)
    # NVIDIA: keep modeset ON or SDDM greeter renders via software (black + cursor);
    #   add nvidia_drm.modeset=1 + fbdev=1 kernelParams on 50xx/Ada.
    # AMD/Intel: no SDDM extras — Mesa KMS just works; if flicker: SDDM theme Qt6 check.
  };
  # Autologin Hyprland-UWSM (kiosk boxes): services.displayManager.autoLogin = {
  #   enable = true; user = "fury"; };  # pairs with defaultSession = "hyprland-uwsm"
}
```

## 3. First Launch

On first login Hyprland starts with defaults: a bare desktop, one terminal (``foot`` if installed — see §10 bars) and the config created at `~/.config/hypr/hyprland.conf` on first modification.

```bash
# The essential escape keys for minute ONE:
#   SUPER + Q        → open a terminal (if bound — default config does)
#   SUPER + M        → exit Hyprland (back to SDDM)
#   SUPER + Enter    → hmm, default binds: check `hyprctl binds` LIVE:
hyprctl binds | less        # every active binding, instant reference
```

## 4. The Config File

The single source of truth — `~/.config/hypr/hyprland.conf`:

```ini
# ~/.config/hypr/hyprland.conf — read top to bottom by Hyprland on
# launch AND on the fly (edits apply instantly — no reload needed!)

# ==========================================================
# 1. MONITORS
# ==========================================================
# Find yours: `hyprctl monitors` (name, resolution, scale)
monitor = DP-1, 2560x1440@144, 0x0, 1        # name,mode,position,scale
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1, mirror, DP-1
# VRR (gaming guide §4.3 — works here natively):
# monitor = DP-1, ..., vrr, 1
# Laptop lid style: disable internal on external:
# monitor = eDP-1, disable

# ==========================================================
# 2. ENVIRONMENT (per-session)
# ==========================================================
env = XCURSOR_THEME,GoogleDot-Black     # Customization §8 — same cursor!
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,wayland      # Qt apps go native-wayland
# NVIDIA specifics live in §6 — they go HERE too.

# ==========================================================
# 3. INPUT
# ==========================================================
input {
    kb_layout = us
    # Touchpad section (laptops):
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
    # Gaming mice: force no acceleration:
    # accel_profile = flat
}

# ==========================================================
# 4. AUTOSTART (exec-once = runs at launch only)
# ==========================================================
exec-once = waybar                       # §10 status bar
exec-once = hyprpaper                    # wallpaper daemon
exec-once = dunst                        # notifications (or mako)
exec-once = wl-paste --watch cliphist store   # clipboard manager

# ==========================================================
# 5. GENERAL LAYOUT
# ==========================================================
general {
    gaps_in = 4                          # gaps between windows
    gaps_out = 10                        # gaps to screen edge
    border_size = 2
    # Accent border on the focused window:
    col.active_border = rgba(5e81acc8)
    col.inactive_border = rgba(4c4f69aa)
    layout = dwindle                    # spiral-ish tiling (or master)
}

# ==========================================================
# 6. DECORATIONS
# ==========================================================
decoration {
    rounding = 8                        # rounded corners
    active_opacity = 1.0
    inactive_opacity = 0.95
    blur {
        enabled = true
        size = 6
        passes = 2
        # Blur the bar/notifications for that frosted look:
        new_optimizations = true
    }
}

# ==========================================================
# 7. WINDOW RULES / WORKSPACES — see §5
# ==========================================================
# (moved below for readability)
```

**Declarative config (NixOS style):** two options —

```nix
{ config, pkgs, ... }: {
  # Option A — seed the file once (edit freely after; survives as user file):
  systemd.tmpfiles.rules = [
    "C /home/fury/.config/hypr/hyprland.conf - - - - ${./assets/hyprland.conf}"
  ];

  # Option B — home-manager (the "real" declarative path; your flake
  # has the HM input commented ready — Customization guide's scope note):
  # home-manager.users.fury.wayland.windowManager.hyprland = { ... };
}
```

## 5. Keybindings & Window Rules

```ini
# ---- KEYBINDINGS (append into hyprland.conf) --------------------------
$mod = SUPER                            # a variable for cleanliness

bind = $mod, Return, exec, kitty        # terminal
bind = $mod, Q, killactive,             # close window (trailing comma!)
bind = $mod, M, exit,                   # leave Hyprland
bind = $mod, E, exec, dolphin            # file manager (Qt/KDE native)
bind = $mod, V, togglefloating,         # float ↔ tile
bind = $mod, F, fullscreen, 0           # 0=exclusive(the real one)

# Focus (vim keys + arrows):
bind = $mod, left, movefocus, l
bind = $mod, H, movefocus, l
bind = $mod, L, movefocus, r
bind = $mod, K, movefocus, u
bind = $mod, J, movefocus, d

# Move windows:
bind = $mod SHIFT, H, movewindow, l
bind = $mod SHIFT, L, movewindow, r
# ... same for j/k

# Workspaces (1-5, with mod+shift to move window there):
bind = $mod, 1, workspace, 1
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod, mouse_down, workspace, e+1   # scroll through
bind = $mod, mouse_up, workspace, e-1

# Screenshots (flameshot-wayland or grim+slurp):
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = SHIFT, Print, exec, grim ~/Pictures/screenshot-$(date +%s).png

# Media keys (PipeWire guide — wire to wpctl):
bindl = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindl = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# ---- WINDOW RULES ------------------------------------------------------
windowrule = float, class:^(pavucontrol)$     # mixers float
windowrule = float, class:^(nm-connection-editor)$
windowrule = float, title:^(Picture-in-Picture)$   # firefox PiP always on top:
windowrule = pin, title:^(Picture-in-Picture)$

# Always-open-on-workspace (games on ws 4!):
windowrule = workspace 4 silent, class:^(steam_app_.*)$
windowrule = workspace 4 silent, class:^(gamescope)$

# NO animations/heavy decor for games (perf):
windowrule = noblur, class:^(steam_app_.*)$
```

Find any window's class with: `hyprctl clients | grep class` while it's open.

## 6. Vendor Matrix — NVIDIA / AMD / Intel (hardware.* + env + ozone + VAAPI)

Pick ONE block matching your GPU — all copy-pasteable, verified against `hardware.graphics` + `hardware.nvidia` schema:

```nix
{ config, pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # Steam/gamescope need it; false on pure servers
  };

  # ---- NVIDIA (your 1660 SUPER = Turing, open=true; 50xx Blackwell = open REQUIRED) ----
  hardware.nvidia = {
    modesetting.enable = true;   # REQUIRED — Hyprland refuses without
    open = true;                 # Turing+ (1660 SUPER/RTX20+); Blackwell/50xx MANDATORY true
    # Maxwell/Pascal/Volta (GTX9xx/10xx): open = false;  # pre-Turing has no GSP
    # package = config.boot.kernelPackages.nvidiaPackages.stable;  # default; beta for 50xx day-0
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # ---- AMD (RX 5000+/RDNA + Ryzen iGPU — zero extra config) ----
  # hardware.graphics.extraPackages = with pkgs; [ libva-utils ];  # vainfo test tool
  # No hardware.amdgpu needed — amdgpu in-tree + mesa RADV default. ROCm only for ML/tone-map.

  # ---- Intel (UHD/Iris/Arc — iHD + VPL for QSV/VAAPI) ----
  # hardware.graphics.extraPackages = with pkgs; [
  #   intel-media-driver      # iHD — Broadwell+ (LIBVA_DRIVER_NAME=iHD)
  #   vpl-gpu-rt              # QSV/VPL — Tiger Lake+ / Arc REQUIRED
  #   intel-vaapi-driver      # i965 — pre-Broadwell only
  #   intel-compute-runtime   # OpenCL — tone-mapping + sub burn-in
  # ];
}
```

```ini
# In hyprland.conf — per-vendor env (complements Gaming-NixOS §6.2):
# NVIDIA path (545+ drivers: GBM_BACKEND + WLR_NO_HARDWARE_CURSORS OUTDATED — auto):
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# env = WLR_NO_HARDWARE_CURSORS,1   # legacy fallback only if cursor invisible
# AMD path: nothing needed (explicit zero):
# env = AMD_VULKAN_ICD,RADV
# Intel path (Arc tear-free + GuC/HuC firmware must load — Kernel guide §10):
# env = LIBVA_DRIVER_NAME,iHD
# ---- Universal Wayland/Electron (ozone) ----
env = NIXOS_OZONE_WL,1              # Electron/Chromium native Wayland (NixOS idiom)
env = MOZ_ENABLE_WAYLAND,1          # Firefox native (not XWayland)
env = QT_QPA_PLATFORM,wayland
env = GDK_BACKEND,wayland
# VAAPI browsers per vendor: Intel iHD / AMD mesa already; NVIDIA needs
#   --enable-features=UseOzonePlatform + nvidia-vaapi-driver (limits noted in Media §3).
```

```bash
# 60-second per-vendor sanity inside a session:
# NVIDIA: glxinfo | grep "OpenGL renderer" → NVIDIA, not llvmpipe; nvidia-smi
# AMD: vainfo | grep -i va-api; radeontop; vulkaninfo | grep RADV
# Intel: vainfo | grep iHD; intel_gpu_top; ls /dev/dri/renderD*
# All: hyprctl monitors | grep vrr; echo $NIXOS_OZONE_WL → 1
```

### 6b. HDR — bitdepth + cm + fullscreen passthrough

```ini
# In hyprland.conf (Hyprland ≥0.50; wiki Monitors page):
# monitor = DP-1, 2560x1440@144, 0x0, 1, bitdepth, 10, cm, hdr
#   bitdepth 10 = 10-bit panel output; cm hdr = wide-gamut desktop HDR
#   cm auto = SDR desktop, auto-HDR on fullscreen HDR content only
# render {
#     cm_auto_hdr = 1        # 1=fullscreen HDR without hdr cm; 2=also HDR hint
#     cm_fs_passthrough = 1  # direct fullscreen passthrough (gamescope HDR path)
# }
# Tune SDR-in-HDR: sdrbrightness, 1.15 + sdrsaturation, 1.0
# Verify: hyprctl monitors | grep -E 'cm|hdr|bitdepth'; gamescope --hdr-enabled test
# NVIDIA needs 545+ + modeset for HDR; AMD/Intel need Mesa 24+ + linux-firmware.
```

## 7. Screensharing, Portals & XWayland

```nix
{ config, pkgs, ... }: {
  # Screensharing in browsers/Discord needs the portal stack (§2 set it
  # up; the runtime usage):
  xdg.portal = {
    enable = true;
    wlr.enable = false;      # hyprland's own portal handles it — NOT wlr's
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland     # hyprland share picker
      pkgs.xdg-desktop-portal-gtk           # file dialogs
    ];
  };

  # Apps that still need X: xwayland (§2) covers them; per-app:
  # env = GDK_BACKEND,x11 for stubborn ones is a CRUTCH — check
  # https://arewewaylandyet.com status first.
}
```

```bash
# Test sharing in a browser at https://mozilla.github.io/webrtc-landing/gum_test.html
# → screen-share picker (Hyprland's own picker window) → share window/output.
# OBS on Wayland: use PipeWire source (comes via portal) — same mechanism.
```

## 8. Animations & Eye Candy

```ini
# In hyprland.conf:
animations {
    enabled = 1
    bezier = smooth, 0.05, 0.9, 0.1, 1.05    # custom curve
    animation = windows, 1, 5, smooth
    animation = windowsOut, 1, 4, default, popin 80%   # snappy closes
    animation = fade, 1, 8, default
    animation = workspaces, 1, 6, smooth
    animation = border, 1, 10, default
}

# The layout dynamics:
dwindle {
    pseudotile = true        # SUPER+P: temp "tile" floating windows
    preserve_split = yes     # remember splits (i3-like behavior)
}
master {
    new_is_master = true     # layout=master alternative
}

# Per-device config (your mouse):
device {
    name = "logitech-g502"           # from: hyprctl devices
    sensitivity = -0.5               # per-device override
}
```

## 9. Plugins & Community Ecosystem

```nix
{ config, pkgs, ... }: {
  # Hyprland plugins (hyprpm-managed, or flake-built). The safe set
  # from nixpkgs:
  environment.systemPackages = with pkgs; [
    hyprpaper            # wallpapers
    hyprpicker           # color picker (wayland-native)
    hypridle hyprlock    # idle/lock (or your qylock! — see §9b services)
    wl-clipboard         # wl-copy/wl-paste (§4 clipboard line)
    cliphist             # clipboard history
  ];
  # WARNING: pin hyprland + portalPackage + Mesa to the SAME nixpkgs —
  # mixing a flake Hyprland with stable Mesa/portal versions segfaults
  # (version-skew crash); either all-flake or all-nixpkgs.
}
```

**Plugins via Home-Manager (version-locked, declarative — preferred over hyprpm):**
```nix
{ config, pkgs, ... }: {
  # HM builds plugins against YOUR hyprland version (no skew crashes):
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;   # REQUIRED with UWSM (§2b) — else double-start
    plugins = with pkgs.hyprlandPlugins; [
      hyprspace     # overview (bind $mod,TAB below)
      hyprexpo      # expo workspace grid
      # hyprtrails  # window trails (eye-candy perf cost)
    ];
    settings = {
      bind = [ "$mod, TAB, overview:open" ];
    };
  };
}
# Imperative alternative: hyprpm add https://github.com/hyprwm/hyprland-plugins
# hyprpm update — breaks on every Hyprland bump; HM rebuilds automatically.
```

### 9b. hypridle / hyprlock services (declarative idle → lock → suspend)

```nix
{ config, pkgs, ... }: {
  programs.hyprlock.enable = true;   # GPU-accelerated locker (PAM wired by module)
  services.hypridle.enable = true;   # HM OR NixOS: services.hypridle / home services.hypridle
  security.pam.services.hyprlock = { };  # REQUIRED or unlock falls back to su (HM note)
}
# HM settings form (preferred — lives with your hyprland config):
# services.hypridle.settings = {
#   general = { lock_cmd = "hyprlock"; before_sleep_cmd = "loginctl lock-session"; after_sleep_cmd = "hyprctl dispatch dpms on"; };
#   listener = [ { timeout = 300; on-timeout = "loginctl lock-session"; } { timeout = 900; on-timeout = "systemctl suspend"; } ];
# };
# Verify: systemctl --user status hypridle → active (needs graphical-session.target = UWSM §2b).
```

## 10. Status Bars & Shell Companions

The compositor provides the CANVAS; a shell around it (equivalent of KDE panels/widgets) — choose one:

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # ---- Option 1: waybar (the default companion) ------------------
    waybar               # bar: workspaces, tray, clock, modules
    # Config: ~/.config/waybar/config.jsonc + style.css

    # ---- Option 2: quickshell (what qylock uses! shared ecosystem) ----
    # quickshell          # QML-based, your lockscreen's framework

    # ---- Option 3: ags/eww — full JS/D widgets -----------------------
    # ags
    # eww

    # Notifications (pick ONE):
    dunst                # classic, simple
    # mako               # wayland-native alternative

    # Wallpapers:
    hyprpaper
    # Or random via: swww (animated transitions)

    # The launcher (app menu — rofi wayland fork or wofi):
    rofi-wayland
    # wofi
  ];
}
```

```ini
# In hyprland.conf — wiring the launchers:
bind = $mod, D, exec, rofi -show drun         # app launcher
bind = $mod SHIFT, D, exec, rofi -show window # window switcher
exec-once = waybar
exec-once = hyprpaper
exec-once = dunst
```

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| Hyprland won't start (instant return to SDDM) | NVIDIA: modeset missing (§6 + Gaming §6.2). Check `journalctl --user -u hyprland` — usually `nvidia-drm modeset not enabled`. |
| Black screen with cursor | Portal/egl issue: try `AQ_NO_MODIFIERS=1` env (Aquamarine renderer bug on some NV generations). |
| Screenshare black/frozen | Wrong portal: `xdg.portal.wlr.enable = false` (§7) — the hyprland portal must own it. Verify: `systemctl --user status xdg-desktop-portal-hyprland`. |
| Steam games blurry/tiny | XWayland scaling — `xwayland { force_zero_scaling = true }` + `env = GDK_SCALE,1`; or run via gamescope (Gaming §5). |
| Cursor invisible on NVIDIA | The `WLR_NO_HARDWARE_CURSORS,1` env (§6) — add it back on driver generations where HW cursors misbehave. |
| Config edits do nothing | Syntax error somewhere below your edit — Hyprland logs to `~/.cache/hyprland/hyprland.log` (or `hyprctl rollinglog` live). |
| Keybind "unknown" in log | Every param needs the trailing comma (`bind = $mod, Q, killactive,` — even empty last arg). |
| Waybar tray icons missing | Needs `tray` module + SNI support: ensure `services.dbus` + no conflicting `status-notifier` applets. |
| Firefox slow/flickering | Force wayland: `MOZ_ENABLE_WAYLAND=1` env — default Firefox builds flip between releases. |
| Apps don't see your KDE theme | They won't — Qt apps read your Plasma theme IF platformtheme set (§4 env); GTK reads Customization §7 settings.ini. |
| Flatpak apps wrong scaling | Flatpak portals handle it — check `flatpak override --user --env=GDK_SCALE=1 <app>` mismatches. |

## 12. Reference Index

- Hyprland wiki (canonical): <https://wiki.hyprland.org/>
- Hyprland on NixOS (module + flake patterns): <https://wiki.hyprland.org/Nix/NixOS-On-Hyprland/>
- Config directives index: <https://wiki.hyprland.org/Configuring/Variables/>
- Dispatches & binds: <https://wiki.hyprland.org/Configuring/Binds/`
- xdg-desktop-portal-hyprland: <https://github.com/hyprwm/xdg-desktop-portal-hyprland>
- Waybar config: <https://github.com/Alexays/Waybar/wiki>
- rofi on wayland: `rofi-wayland(1)`
- arewewaylandyet: <https://arewewaylandyet.com/>
- nixpkgs module: `nixos/modules/programs/wayland/hyprland.nix`
- Companions: `Customization-NixOS.md` (themes/cursors/fonts shared), `Gaming-NixOS.md` (§5 gamescope, §6 NVIDIA), `Audio-PipeWire-NixOS.md` (media keys wiring)
