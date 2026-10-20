# Hyprland on NixOS — The Complete Lua Configuration & Ricing Guide

> **Target reader:** You, on NixOS (26.05 stable flake, NVIDIA + secure boot via lanzaboote, currently KDE/Plasma user), wanting to run Hyprland configured entirely in **Lua** (Hyprland ≥ 0.55 native Lua config), and rice it properly.
>
> **Sources:** Hyprland official wiki (wiki.hypr.land, extracted 2026-09-05), NixOS/HM module docs, real-world Lua dotfiles (3rfaan/dotfiles-hyprland, shadowdevforge/CelestialShade-Config, fancypantalons/hyprland-config), Tide-island & MangoWC project docs.

---

## Table of Contents

1. [What "Hyprland with Lua" means](#1-what-hyprland-with-lua-means)
2. [Big picture: the moving parts](#2-big-picture-the-moving-parts)
3. [Installing Hyprland on NixOS](#3-installing-hyprland-on-nixos)
4. [NVIDIA first (your GPU)](#4-nvidia-first-your-gpu)
5. [First launch & config discovery](#5-first-launch--config-discovery)
6. [The Lua config language — `hl.*` API crash course](#6-the-lua-config-language--hl-api-crash-course)
7. [A full reference `hyprland.lua`](#7-a-full-reference-hyprlandlua)
8. [Monitors](#8-monitors)
9. [Keybinds & submaps](#9-keybinds--submaps)
10. [Window / workspace / layer rules](#10-window--workspace--layer-rules)
11. [Animations & curves (the rice core)](#11-animations--curves-the-rice-core)
12. [Decorations: blur, shadows, glow, wobble, motion blur](#12-decorations-blur-shadows-glow-wobble-motion-blur)
13. [Layouts: dwindle / master / scrolling / monocle](#13-layouts-dwindle--master--scrolling--monocle)
14. [Events — scripting your desktop with Lua callbacks](#14-events--scripting-your-desktop-with-lua-callbacks)
15. [Timers, `hl.exec_cmd`, and the golden rule of non-blocking binds](#15-timers-hlexec_cmd-and-the-golden-rule-of-non-blocking-binds)
16. [Ricing the shell: bar, launcher, notifications, wallpaper, lock](#16-ricing-the-shell-bar-launcher-notifications-wallpaper-lock)
17. [Theming workflow: matugen + a single source of truth](#17-theming-workflow-matugen--a-single-source-of-truth)
18. [Fonts, cursors, GTK/Qt theming on NixOS](#18-fonts-cursors-gtkqt-theming-on-nixos)
19. [Making it all declarative: Home-Manager (or not)](#19-making-it-all-declarative-home-manager-or-not)
20. [NixOS module options cheat-sheet](#20-nixos-module-options-cheat-sheet)
21. [Debugging, hyprctl, logs](#21-debugging-hyprctl-logs)
22. [Common pitfalls on NixOS](#22-common-pitfalls-on-nixos)
23. [Vendor GPU matrix: NVIDIA vs AMD vs Intel](#23-vendor-gpu-matrix-nvidia-vs-amd-vs-intel)
24. [HDR and color management deep dive](#24-hdr-and-color-management-deep-dive)
25. [Plugins on NixOS (hyprpm unsupported)](#25-plugins-on-nixos-hyprpm-unsupported)
26. [UWSM session (recommended launch path)](#26-uwsm-session-recommended-launch-path)
27. [hyprlock / hypridle / hyprpaper fuller reference](#27-hyprlock--hypridle--hyprpaper-fuller-reference)
28. [Missing Lua APIs: gestures, devices, custom layouts](#28-missing-lua-apis-gestures-devices-custom-layouts)
29. [Portals, security, PAM](#29-portals-security-pam)
30. [Laptop specifics: hybrid, power, backlight](#30-laptop-specifics-hybrid-power-backlight)
31. [Further reading](#31-further-reading)

---

## 1. What "Hyprland with Lua" means

Since **Hyprland 0.55**, the compositor accepts a **native Lua configuration** at
`~/.config/hypr/hyprland.lua` (instead of / in addition to the legacy `hyprland.conf`
hyprlang format). Everything you used to write as:

```conf
# old hyprlang
bind = SUPER, Q, exec, kitty
animations { enabled = true }
```

is now Lua:

```lua
-- new Lua
hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
hl.config({ animations = { enabled = true } })
```

Why bother?

- **Logic in your config**: loops, conditionals, functions — no more `genList` hacks in Nix or shell-script `source`d configs.
- **Events**: `hl.on("window.open", function(w) ... end)` — react to your desktop in real time.
- **Timers**: `hl.timer(...)` — polling/repeating logic without external daemons.
- **Better introspection**: `hl.get_active_window()`, `hl.get_workspaces()`, etc., return real objects.
- **LSP support**: there are official Lua stubs; your editor can autocomplete `hl.*` and catch type errors (see the wiki's "Lua code snippets" / LSP section).

Tools that convert old configs: `hyprlang2lua` (Go CLI), `hypr2lua`, `hyprvalidate`.

> **Tip:** the config lives at `~/.config/hypr/hyprland.lua`. `hl` is the global handle Hyprland injects. You can split your config into multiple `require`d/`dofile`d files (e.g. `~/.config/hypr/binds.lua`, `rules.lua`, `theme.lua`).

---

## 2. Big picture: the moving parts

A "riced" Hyprland setup is a small orchestra. Hyprland is only the conductor (compositor + window manager). You pick the rest:

| Role | What it does | Popular choices (all in nixpkgs) |
|---|---|---|
| **Compositor/WM** | windows, animations, keybinds | **Hyprland** |
| **Terminal** | kitty / foot / alacritty / ghostty | kitty is Hyprland's default |
| **Bar** | status bar | **Waybar** (GTK), **ashell** (Rust, ready-to-go), quickshell-based bars |
| **Desktop shell** (bar+launcher+notifications+lock in one) | everything | **Noctalia**, **DankMaterialShell**, Caelestia, Tide Island (island widget — see separate guide) |
| **App launcher** | rofi (now Wayland-native), **fuzzel**, **hyprlauncher** (first-party), tofi, anyrun, walker, bemenu, wofi | |
| **Notifications daemon** | required — apps freeze without one | **dunst**, **mako**, **fnott**, **swaync** |
| **Wallpaper** | hyprpaper (first-party), swaybg, swww (animated), mpvpaper | |
| **Lock screen** | hyprlock (first-party), swaylock-effects | |
| **Idle manager** | hypridle (first-party), swayidle | |
| **Screenshot** | grim + slurp + **satty**/swappy; or Flameshot (portal) | |
| **Clipboard** | wl-clipboard + **cliphist** (history) | |
| **Screen recording** | wf-recorder, OBS | |
| **Polkit agent** | asks for passwords | **hyprpolkitagent** (first-party) |
| **Portals** | file pickers, screen share | xdg-desktop-portal-hyprland |
| **Color temperature / Night Light** | | **hyprsunset** (first-party) |
| **Audio** | PipeWire + wireplumber (never pipewire-media-session) | |
| **Color scheme generator** | theming from wallpaper | **matugen** |

First-party ecosystem (`hypr*`): hyprpaper, hyprlock, hypridle, hyprpolkitagent, hyprsunset, hyprpicker (color picker), hyprland-qt-support (Qt theming integration). On NixOS, all from nixpkgs or the hyprland flake.

---

## 3. Installing Hyprland on NixOS

### Option A — nixpkgs (recommended for stable 26.05)

```nix
# configuration.nix
{
  programs.hyprland.enable = true;
}
```

This gives you:
- the Hyprland binary + `start-hyprland` helper,
- the **NixOS module** (systemd session files, portals, D-Bus, environment glue) — **required** for display managers (you use SDDM),
- xdg-desktop-portal-hyprland in sync.

Add the ecosystem bits and rice tooling:

```nix
{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;   # X11 app support (Steam etc.)
  };

  environment.systemPackages = with pkgs; [
    # first-party ecosystem
    hyprpaper          # wallpaper
    hyprlock           # lock screen
    hypridle           # idle daemon
    hyprpolkitagent    # auth agent
    hyprsunset         # night light
    hyprpicker         # color picker

    # core wayland utilities
    kitty              # terminal (Hyprland default)
    waybar             # bar (or use ashell / a shell)
    fuzzel             # launcher
    dunst              # or mako / swaync notifications
    grim slurp satty   # screenshots + annotation
    wl-clipboard cliphist
    brightnessctl
    pamixer            # or pwvucontrol (pick one — `a or b` is invalid Nix)
    networkmanagerapplet  # nm-applet tray

    # theming
    matugen            # Material You colors from wallpaper
    libsForQt5.qt5ct qt6Packages.qt6ct qt6Packages.qtstyleplugin-kvantum  # Qt theming
    nerd-fonts.jetbrains-mono   # see fonts section
  ];
}
```

> **Cachix:** to avoid compiling Hyprland from source, enable the Hyprland cachix **before** adding the flake input (must be enabled before flake builds — rebuild at least once first, see wiki `/nix/cachix/`):
> ```nix
> {
>   nix.settings = {
>     substituters = [ "https://hyprland.cachix.org" ];
>     trusted-substituters = [ "https://hyprland.cachix.org" ];
>     trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
>   };
>   nix.settings.trusted-users = [ "root" "@wheel" ];
> }
> ```

### Option B — the Hyprland flake (bleeding edge, needed if you want latest Lua features immediately)

Your flake already pins stable 26.05 with NVIDIA concerns. If the nixpkgs Hyprland version is < 0.55, the Lua config won't exist — then use the flake:

```nix
# flake.nix
{
  inputs.hyprland.url = "github:hyprwm/Hyprland";

  outputs = { nixpkgs, ... } @ inputs: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

```nix
# configuration.nix
{ inputs, pkgs, ... }: {
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
}
```

**Mesa mismatch fix** (lag in games/Blender when mixing flake Hyprland with stable mesa — likely relevant to you):

```nix
{ pkgs, inputs, ... }: let
  pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  hardware.graphics = {
    package = pkgs-unstable.mesa;
    enable32Bit = true;                       # for Steam
    package32 = pkgs-unstable.pkgsi686Linux.mesa;
  };
}
```

> Keep Hyprland + XDPH from the **same source** (both nixpkgs, or both flake). Never mix.

### How you'll start it

You currently boot to a display manager (you have SDDM artifacts). Supported managers: **SDDM (works flawlessly, ≥ 0.20.0)**, greetd/regreet, ly, GDM (crashes on first launch), plasma-login-manager. Since the NixOS module installs the session file, you'll simply pick the "Hyprland" session in SDDM. From a TTY: `start-hyprland`.

Do **not** run Hyprland as root.

---

## 4. NVIDIA first (your GPU)

NVIDIA works on Hyprland, with setup. On NixOS most of the pain (modeset, early KMS, suspend services) is already handled by `hardware.nvidia` options. What matters from the wiki:

```nix
# configuration.nix — the NixOS side
{ ... }: {
  hardware.nvidia = {
    modesetting.enable = true;      # equivalent of nvidia_drm modeset=1 (default after 535)
    # WARNING: powerManagement.enable is experimental and can break suspend/resume on some systems.
    powerManagement.enable = true;  # nvidia suspend/resume services + PreserveVideoMemoryAllocations
    # open = true;  # REQUIRED for 50xx (5090/5080) cards; recommended for Turing+ (16xx/20xx and newer)
  };
}
```

The Hyprland-side environment (put in `hyprland.lua`):

```lua
-- NVIDIA environment variables
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Electron/Chromium flicker fix (native Wayland):
hl.env("NIXOS_OZONE_WL", "1")            -- works, but official NixOS way is environment.sessionVariables.NIXOS_OZONE_WL = "1" (preferred; hl.env also works)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- VA-API hardware video accel (optional, pairs with nvidia-vaapi-driver):
-- hl.env("NVD_BACKEND", "direct")
```

Known NVIDIA-on-Hyprland gotchas:

| Symptom | Fix |
|---|---|
| Electron/CEF flicker | `NIXOS_OZONE_WL=1` + recent driver ≥ 555 (explicit sync); or per-app `--enable-features=WaylandLinuxDrmSyncobj` |
| Xwayland games flicker/frame-order issues | xwayland ≥ 24.1, wayland-protocols ≥ 1.34, driver ≥ 555 |
| Multi-monitor on hybrid (Intel+NVIDIA) laptop | switch BIOS to discrete-only; or `AQ_DRM_DEVICES` to pick primary GPU |
| Secondary GPU monitor slow/broken | `AQ_FORCE_LINEAR_BLIT=0` (slower but working) |
| Suspend/wake blackscreen | `hardware.nvidia.powerManagement.enable = true;` |
| Games lag (flake Hyprland + stable mesa) | use hyprland flake's nixpkgs mesa (snippet above) |

Tearing for competitive games:

```lua
hl.config({ general = { allow_tearing = true } })
hl.window_rule({ match = { class = "cs2|gamescope" }, immediate = true })
```
(Tearing only engages when the game is fullscreen and the only visible layer.)

---

## 5. First launch & config discovery

After rebuild + reboot, pick Hyprland in SDDM. Default binds: `SUPER+Q` opens kitty, `SUPER+M` exits.

Config file: `~/.config/hypr/hyprland.lua` (create it — Lua config replaces `hyprland.conf` entirely on 0.55+).

**Reload**: config auto-reloads on save (unless `misc.disable_autoreload = true`), or `hyprctl reload`. A quick edit-reload loop is the heart of ricing.

Structure your config as a small project:

```
~/.config/hypr/
├── hyprland.lua        # entry: requires the rest
├── theme.lua           # colors, curves, animations  (single source of truth)
├── binds.lua
├── rules.lua
├── autostart.lua
└── events.lua          # hl.on() callbacks
```

In `hyprland.lua`:

```lua
dofile("/home/YOU/.config/hypr/theme.lua")
-- or package.path trickery for require()
```

> The wiki's LSP page provides **Lua stubs** for the `hl` API so lua-language-server gives you autocomplete + type checking while you rice. Search "Lua code snippets" on the wiki. There is also a community validator: `hyprvalidate` (converts .conf → Lua and validates against Hyprland's real schema).

---

## 6. The Lua config language — `hl.*` API crash course

Everything is a call on the global `hl` table.

### Config options — `hl.config()`

```lua
-- many at once
hl.config({
  general  = { gaps_in = 4, gaps_out = 8, layout = "dwindle" },
  input    = { kb_options = "ctrl:nocaps" },
})

-- or a few, with the dotted form
hl.config({ ["general.gaps_in"] = 0 })
```

Multiple `hl.config()` calls merge; last write wins per-option. You can also change options at runtime: `hyprctl eval 'hl.config({ ... })'` (resets on reload).

Types you'll use: `int`, `float`, `bool`, `string`, `table`, `vec2 = {x, y}`, `css_gaps` (int or `{top=,left=,right=,bottom=}`), `gradient` (color or `{colors={c1,c2}, angle=}`), colors as `"#RRGGBB(AA)"` / `"rgb(...)"` / `"rgba(...)"` / legacy `0xaarrggbb`.

### Monitors — `hl.monitor()`

```lua
hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "auto", scale = 1, vrr = 1 })
-- fallback for any unplanned output:
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

### Environment — `hl.env()`

```lua
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
```

### Binds — `hl.bind()`

```lua
hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + X", function() --[[ lua logic ]] end)
```

### Rules — `hl.window_rule()` / `hl.workspace_rule()` / `hl.layer_rule()`

```lua
hl.window_rule({ match = { class = "kitty" }, opacity = "0.95 0.85" })
```

### Animations — `hl.animation()` and curves — `hl.curve()`

```lua
hl.curve("overshoot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "overshoot", style = "popin 80%" })
```

### Events — `hl.on()`

```lua
hl.on("workspace.active", function(ws) print("now on " .. tostring(ws.id)) end)
```

### Convenience getters (verified)

`hl.get_monitor(name)`, `hl.get_workspace(name)`, `hl.get_active_workspace()`, `hl.get_active_special_workspace()`, `hl.get_config(path?)`, `hl.version()`. Others seen in the wild (`get_active_window`, `get_windows`/`get_workspaces`, `get_monitors({all})`, `get_layers`, `get_current_submap`, `get_active_monitor`, `get_cursor_pos`, `get_loaded_plugins`, `is_key_down`) are unverified — check the wiki before relying on them.

### Dispatchers — `hl.dsp.*` (returned as *descriptors*, must be executed via `hl.dispatch()` or fed to `hl.bind()`)

```lua
-- WRONG (does nothing):
hl.dsp.window.close()
-- RIGHT:
hl.dispatch(hl.dsp.window.close())
-- RIGHT (bind executes it for you):
hl.bind("SUPER + C", hl.dsp.window.close())
```

`hl.dsp` families: `exec_cmd`, `exec_raw`, `focus`, `exit`, `reload_config`, `submap`, `pass`, `send_shortcut`, `layout`, `dpms`, `global`, `no_op`, `window.*` (close/kill/float/fullscreen/move/swap/center/pin/tag/set_prop/...), `workspace.*` (change_id/rename/move/swap_monitors/toggle_special), `group.*`, `cursor.*`.

`hl.exec_cmd()` spawns **asynchronously** — never append `& disown`.

---

## 7. A full reference `hyprland.lua`

One file, heavily commented — the kitchen sink. Steal pieces.

```lua
-- ~/.config/hypr/hyprland.lua
-- Hyprland Lua config (>= 0.55)

-- ============ 0. Variables ============
local M = "SUPER"             -- main mod
local S = "SUPER + SHIFT"
local C = "SUPER + CTRL"
local term = "kitty"
local browser = "firefox"
local menu = "fuzzel"

-- Your theme tokens (in real life: generated by matugen, read from a file)
local theme = {
  bg        = "rgb(1a1b26)",
  fg        = "rgb(c0caf5)",
  accent    = "rgb(7aa2f7)",
  accent2   = "rgb(bb9af7)",
  inactive  = "rgb(414868)",
}

-- ============ 1. Environment ============
hl.env("NIXOS_OZONE_WL", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- NVIDIA (uncomment if needed):
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- ============ 2. Monitors ============
-- Find names: hyprctl monitors all
hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1 })
-- Laptop panel example:
-- hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "auto", scale = 1.25, vrr = 0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })  -- fallback rule

-- ============ 3. Core config ============
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 10,
    gaps_workspaces = 0,
    border_size = 2,
    layout = "dwindle",
    resize_on_border = true,
    extend_border_grab_area = 15,
    hover_icon_on_border = true,
    col = {
      active_border   = { colors = { theme.accent, theme.accent2 }, angle = 45 },
      inactive_border = theme.inactive,
    },
    snap = { enabled = true, border_overlap = false, respect_gaps = true,
             monitor_gap = 10, window_gap = 10 },
  },

  decoration = {
    rounding = 10,
    rounding_power = 2.0,
    active_opacity = 1.0,
    inactive_opacity = 0.95,
    fullscreen_opacity = 1.0,
    dim_inactive = false,
    dim_strength = 0.5,
    shadow = {
      enabled = true, range = 12, render_power = 3, scale = 1.0,
      offset = {0, 3},
      color = "rgba(1a1b26ee)",
      color_inactive = "rgba(1a1b2666)",
    },
    glow = { enabled = false, range = 10, render_power = 3, color = theme.accent },
    blur = {
      enabled = true,
      size = 8, passes = 3,
      noise = 0.0117,
      contrast = 0.8916,
      brightness = 1.0,
      vibrancy = 0.1696,
      vibrancy_darkness = 0.0,
      popups = true, popups_ignorealpha = 0.2,
      ignore_opacity = true,
      new_optimizations = true,
      xray = false,
      -- variant = "acrylic",  -- try: kawase|acrylic|aurora|drops|fluid_jar|frost|haze|heat_shimmer|prism|ripple|water
    },
  },

  animations = { enabled = true, workspace_wraparound = false },

  input = {
    kb_layout = "us",
    kb_options = "",                 -- e.g. "ctrl:nocaps" or "caps:swapescape"
    follow_mouse = 1,
    float_switch_override_focus = 1,
    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,         -- set false if you prefer classic
      clickfinger_behavior = true,
      tap-to-click = true,
      drag_lock = false,
      scroll_factor = 1.0,
    },
    sensitivity = 0.0,               -- -1.0 .. 1.0
    accel_profile = "adaptive",
  },

  gestures = {
    workspace_swipe = true,
    workspace_swipe_fingers = 3,
    workspace_swipe_distance = 300,
    workspace_swipe_invert = false,
    workspace_swipe_forever = false,
    workspace_swipe_numbered = false,
  },

  group = {
    groupbar = {
      enabled = true,
      font_size = 10,
      gradients = true,
      render_titles = false,
      scrolling = true,
    },
  },

  misc = {
    force_default_wallpaper = 0,       -- 0/1 disable anime bg, 2 enable, -1 random
    disable_hyprland_logo = true,
    disable_splash_rendering = false,
    font_family = "JetBrainsMono Nerd Font",
    middle_click_paste = true,
    enable_swallow = false,             -- try true + swallow_regex
    focus_on_activate = false,
    vrr = 0,                            -- 0 off, 1 always, 2 fullscreen, 3 fullscreen+video/game
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = false,
    initial_workspace_tracking = 1,
  },

  binds = {
    focus_preferred_method = 1,        -- 1 = cursor, 0 = focus history
    scroll_event_delay = 150,
    drag_threshold = 10,
  },

  xwayland = { force_zero_scaling = true },
})

-- ============ 4. Curves & animations ============
hl.curve("smooth",     { type = "spring", mass = 1.0, stiffness = 300, dampening = 28 })
hl.curve("snappy",     { type = "spring", mass = 1.0, stiffness = 800, dampening = 40 })
hl.curve("overshoot",  { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1} } })
hl.curve("fadeq",      { type = "bezier", points = { {0.25, 0.9}, {0.25, 1.0} } })

hl.animation({ leaf = "global",     enabled = true, speed = 5, spring = "smooth" })
hl.animation({ leaf = "windows",     enabled = true, speed = 5, spring = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5, spring = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 4, spring = "smooth", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "smooth" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4, spring = "smooth", style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 4, spring = "smooth", style = "fade" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4, bezier = "fadeq" })
hl.animation({ leaf = "border",      enabled = true, speed = 6, spring = "snappy" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 12, bezier = "default", style = "loop" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, spring = "smooth", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, spring = "smooth", style = "slidevert" })

-- ============ 5. Autostart ============
-- exec-once equivalents (run on hyprland.start)
local function once(cmd) hl.exec_cmd(cmd) end

hl.on("hyprland.start", function()
  -- the essential trio
  once("hyprpaper")                       -- wallpaper
  once("dunst")                           -- notification daemon (or mako/swaync)
  once("hyprpolkitagent")                 -- auth agent

  -- bars & launchers
  once("waybar")
  -- once("ashell")                       -- alternative bar

  -- session glue (critical on NixOS with systemd)
  once("dbus-update-activation-environment --systemd --all WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  once("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- your island/shell (see TIDE-ISLAND guide)
  -- once("tide-island") or systemctl --user start tide-island

  -- idle daemon
  once("hypridle")
  -- cliphist history:
  once("wl-paste --type text --watch cliphist store")
end)

-- ============ 6. Keybinds ============
-- see section 9 for full explanation
require("binds").setup(M, term, browser, menu)  -- if you split files; inline otherwise

-- ============ 7. Rules ============
-- see section 10
```

---

## 8. Monitors

Full field list for `hl.monitor()`:

| Field | Type | Default | Notes |
|---|---|---|---|
| `output` | str | *required* | name or `desc:...` description prefix |
| `disabled` | bool | false | removes from layout (use `dpms` dispatcher for "screensaver off") |
| `mode` | str | "preferred" | `"WxH@Hz"`, `preferred`/`highres`/`highrr`/`maxwidth` |
| `scale` | float/str | "auto" | `"auto"` = PPI-based |
| `position` | str | "auto" | `"1920x1080"`, `auto` places right of previous |
| `transform` | int | 0 | 0–7 rotation/flip |
| `mirror` | str | empty | mirror another output |
| `bitdepth` | int | 8 | 8/10 |
| `vrr` | int | 0 | Adaptive sync per-monitor (overrides misc.vrr) |
| `icc` | str | empty | absolute path to ICC profile |
| `reserved_area` | css_gaps | 0 | force free space (for custom bars) |
| `cm` | str | "srgb" | color preset: `auto`, `srgb`, `wide`, `dcip3`, `dp3`, `adobe`, `edid`, `hdr`, `hdredid` (experimental) |
| `sdr_eotf` | str | "default" | SDR transfer fn: `default` (follows `render:cm_sdr_eotf`), `gamma22`, `srgb` |
| `supports_wide_color` | int | 0 | force wide gamut: -1 off, 0 auto, 1 on |
| `supports_hdr` | int | 0 | force HDR: -1 off, 0 auto, 1 on |
| `sdrbrightness` | float | 1.0 | SDR brightness in HDR mode (typical 1.0–2.0) |
| `sdrsaturation` | float | 1.0 | SDR saturation in HDR mode |
| `sdr_min_luminance` | float | 0.2 | SDR→HDR min mapping (0.005 = true-black match) |
| `sdr_max_luminance` | int | 80 | SDR→HDR max (reasonable 80–400, often 200–250) |
| `min_luminance` / `max_luminance` / `max_avg_luminance` | float/int/int | -1/-1/-1 | monitor EDID overrides; unset = from EDID |

Discovery: `hyprctl monitors all` (lists `availableModes`, current mode, scale, reserved, dpms, vrr, mirror state, `colorManagementPreset`, `sdrBrightness`, `sdrSaturation`, `sdrMinLuminance`, `sdrMaxLuminance`...). See §24 for HDR usage.

```lua
-- 10-bit HDR-ish setup:
hl.monitor({ output = "DP-1", mode = "3840x2160@144", scale = 2, bitdepth = 10, vrr = 1 })

-- Portrait secondary on the right:
hl.monitor({ output = "desc:BNQ BenQ GW2765", mode = "2560x1440@60",
             position = "2560x0", transform = 1 })
```

Reserved areas stack with bars' own space; use one custom reserved rule per monitor max.

---

## 9. Keybinds & submaps

### Basics

```lua
hl.bind("SUPER + Q", hl.dsp.exec_cmd(term))
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
```

Modifiers: `SUPER`, `CTRL`, `ALT`, `SHIFT`, plus raw keysyms (`Super_L`, `Alt_R`...). Keysyms come from `xkbcommon-keysyms.h` (name = segment after `XKB_KEY_`). Use `wev` to discover key names. Keycodes: `"code:28"`.

**⚠ The golden rule:** bind callbacks run on the compositor event loop. **Never** do blocking work (`io.popen`, network, `wl-paste`, sleeps) inside them — it freezes your whole desktop. Spawn via `hl.dsp.exec_cmd` instead.

### All bind flags

```lua
hl.bind("KEY", dsp, { flag = true })
```

| Flag | Effect |
|---|---|
| `locked` | works while an input inhibitor (lock screen) is active |
| `release` | trigger on key release |
| `click` / `drag` | trigger on release if cursor stayed inside / moved outside `binds.drag_threshold` |
| `long_press` | long-press trigger |
| `repeating` | repeat while held |
| `non_consuming` | also pass the key to the focused window |
| `auto_consuming` | pass key on unless the dispatcher succeeded |
| `mouse` | mouse bind (movement-aware, see below) |
| `transparent` | cannot be shadowed by other binds |
| `ignore_mods` | ignore modifiers |
| `dont_inhibit` | bypass app keybind-inhibition |
| `submap_universal` | active in every submap |
| `device` | per-device bind: `{ device = { inclusive = true, list = { "name1", "name2" } } }` — inclusive=true: only listed devices fire; false: all *except* listed. Tags allowed. Names from `hyprctl devices`. See §28. |
| `separate` | don't merge with other binds (see wiki Binds) |
| `bypass` | bypass inhibit / special handling (see wiki Binds) |
| `description` | text shown by tools reading binds (`hyprctl binds`; use `{ description = "..." }`) |

### Mouse binds

```lua
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),    { mouse = true })  -- LMB move
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(),  { mouse = true })  -- RMB resize
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e-1" }))       -- wheel = prev ws
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))       -- wheel = next ws
```

(`mouse:272/273/274` = left/right/middle. Horizontal: `mouse_left`, `mouse_right`.)

### Workspaces — generated binds (why Lua wins)

```lua
for i = 1, 9 do
  hl.bind(M .. " + " .. i,        hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(S .. " + " .. i,        hl.dsp.window.move({ workspace = tostring(i), follow = true }))
  hl.bind(C .. " + " .. "down",   hl.dsp.window.move({ workspace = "e+1", follow = true }))
  hl.bind(M .. " + mouse_down",   hl.dsp.focus({ workspace = "e-1" }))
end

-- Named + special workspaces (the "scratchpad"):
hl.bind(S .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(M .. " + S", hl.dsp.workspace.toggle_special("magic"))
```

Workspace selectors (memorize these — they're everywhere): `previous`, `previous_per_monitor`, `special` / `special:name`, `name:Web`, `m`/`r`/`e` + `+n`/`-n`/`~n` (relative search on monitor / range / everywhere), `empty`, `emptym`, `emptynm`. Props: `r[A-B]` id-range, `m[monitor]`, `w[t1]` window-count, `f[state]` fullscreen-state, `n[...]` name ops. Numerical IDs: 1..2147483647 only.

### Submaps (modes à la i3)

```lua
hl.bind("SUPER + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
  hl.bind("right", hl.dsp.window.resize({ x =  10, y =  0, relative = true }), { repeating = true })
  hl.bind("left",  hl.dsp.window.resize({ x = -10, y =  0, relative = true }), { repeating = true })
  hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("down",  hl.dsp.window.resize({ x = 0, y =  10, relative = true }), { repeating = true })
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("catchall", hl.dsp.submap("reset"))   -- any unknown key exits
end)
```

Submaps can nest, auto-advance (`hl.define_submap("a", "b", function() ... end)`), or have universal binds. If you get stuck: `hyprctl dispatch --instance 0 'hl.dsp.submap("reset")'` from a TTY.

### The conditional-bind pitfall

```lua
-- WRONG — evaluated once at load:
hl.bind("SUPER + L", hl.dsp.exec_cmd("foot", { float = not (hl.get_active_window().title == "foot") }))
-- RIGHT — evaluated on every press:
hl.bind("SUPER + L", function()
  local is_foot = hl.get_active_window().title == "foot"
  hl.dispatch(hl.dsp.exec_cmd("foot", { float = not is_foot }))
end)
```

### Auto-consuming conditional binds (pass-through if not applicable)

```lua
hl.bind("p", function()
  local w = hl.get_active_window()
  if w and w.title == "some cool app" then
    hl.dispatch(hl.dsp.exec_cmd("another_cool_app"))
  else
    return { ok = false }   -- pass the 'p' to the app
  end
end, { auto_consuming = true })
```

---

## 10. Window / workspace / layer rules

### Window rules

```lua
hl.window_rule({
  name? = str,          -- optional named rule (for later removal)
  match = { ... },      -- one or more props
  effect = value,       -- effects at top level
})
```

**Match props:** `class`, `initial_class`, `title`, `initial_title`, `content` ("game"/"video"/"photo"), `focus`, `float`, `fullscreen`, `fullscreen_state_client/_internal`, `group`, `modal`, `pin`, `tag`, `workspace`, `xdg_tag`, `xwayland` (RegEx where noted; RE2 syntax; negate with `negative:` prefix).

**Static effects** (evaluated once at open — so they match `initial_class`/`initial_title`):
`float`, `tile`, `center`, `fullscreen`, `maximize`, `monitor` (`"1"`, `"DP-1"`, `" silent"` suffix), `move` (`{x,y}` or expressions like `{"cursor_x-(window_w*0.5)","cursor_y-(window_h*0.5)"}`), `size` (`{w,h}` or expressions with `monitor_w/h`, `window_w/h`, `cursor_x/y`), `workspace` (also `"unset"` / `" silent"`), `pin`, `pseudo`, `group` ("set"/"new"/"lock always"/"deny"/"barred"/"invade"/"override"...), `content`, `fullscreen_state`, `no_initial_focus`, `no_close_for` (ms), `scrolling_width`, `suppress_event` ("fullscreen maximize activate ...").

**Dynamic effects** (re-evaluated on every property change — the rice toys):
`animation` ("popin", "popin 80%"), `border_color` (color/gradient/two gradients), `border_size`, `rounding`, `rounding_power`, `opacity` ("0.8" / "0.9 0.7" / "1.0 0.8 0.9" + ` override`), `idle_inhibit` ("none"/"always"/"focus"/"fullscreen"), `tag`, `min_size`/`max_size`/`persistent_size`, `dim_around`, `decorate`, `focus_on_activate`, `keep_aspect_ratio`, `nearest_neighbor`, `no_anim`, `no_auto_hdr`, `no_blur`, `no_dim`, `no_focus`, `no_follow_mouse`, `no_shadow`, `no_glow`, `no_screen_share` (blacks the window in shares!), `no_vrr`, `no_wobble`, `opaque`, `immediate` (tearing), `xray`, `render_unfocused`, `confine_pointer` (lock cursor — great for games), `scroll_mouse`/`scroll_touchpad`, `tonemap`, `sync_fullscreen`, `allows_input`, `persistent_size`...

```lua
-- A small ruleset
hl.window_rule({ match = { class = "kitty" }, opacity = "0.95 0.85" })
hl.window_rule({ match = { class = "^(firefox|chromium)$", xwayland = false },
                 opacity = "1.0 0.9", no_blur = false })

-- Picture-in-picture floats pinned small bottom-right:
hl.window_rule({
  match = { title = ".*(Picture in Picture|PiP).*" },
  float = true, pin = true,
  size = { "(monitor_w*0.25)", "(monitor_h*0.25)" },
  move = { "(monitor_w-(monitor_w*0.25)-20)", "(monitor_h-(monitor_h*0.25)-20)" },
  no_anim = false, animation = "popin",
})

-- Games tear + fullscreen content type:
hl.window_rule({ match = { class = "^(cs2|steam_app_.*)$" }, immediate = true, content = "game" })

-- Steam: float the small windows only
hl.window_rule({ match = { class = "steam", title = "^(Friends List|Steam Settings|.*Sign in to Steam)$" },
                 float = true })

-- Launch with rules inline (uses spawned PID):
hl.bind("SUPER + E", hl.dsp.exec_cmd("kitty --class floating-kitty", { float = true, move = {0, 0} }))
```

### Workspace rules

```lua
hl.workspace_rule({ workspace = "5", on_created_empty = "[float] firefox" })
hl.workspace_rule({ workspace = "name:code", monitor = "DP-1", default = true,
                    gaps_in = 0, gaps_out = 0, border_size = 0, no_border = true,
                    decorate = false, layout = "scrolling" })
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = "foot" })
```

Available rule keys: `animation`, `monitor`, `default`, `float_gaps`, `gaps_in`, `gaps_out`, `border_size`, `no_border`, `no_shadow`, `no_rounding`, `decorate`, `persistent`, `on_created_empty`, `default_name`, `layout`, `layout_opts`.

### Layer rules (for your bar, launcher, notifications, island!)

```lua
hl.layer_rule({ match = { namespace = "waybar" }, blur = true })
hl.layer_rule({ match = { namespace = "fuzzel" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
```

Layer match props: `namespace` only. Effects: `above_lock`, `animation`, `blur`, `blur_popups`, `dim_around`, `ignore_alpha`, `no_anim`, `no_screen_share`, `order`, `xray`. **Important for Tide Island / quickshell setups** — layer rules control whether your island gets blur and how it animates.

---

## 11. Animations & curves (the rice core)

Animations form a **tree**; unset leaves inherit from the parent:

```
global
 ├ windows (slide|popin|gnomed)      ├ fade (fadeIn, fadeOut, fadeSwitch, fadeShadow,
 ├ windowsIn / windowsOut            │        fadeGlow, fadeDim, fadeLayersIn/Out,
 ├ windowsMove                       │        fadePopupsIn/Out, fadeDpms)
 ├ layers (slide|popin|fade)         ├ border, borderangle (once|loop), shadowangle, glowangle
 ├ layersIn / layersOut              ├ workspaces (slide|slidevert|fade|slidefade|slidefadevert)
                                     │   ├ workspacesIn/Out
                                     │   └ specialWorkspace (In/Out)
                                     ├ zoomFactor, monitorAdded
```

```lua
-- official keys are bezier= / spring= (see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/)
hl.animation({ leaf = str, enabled = bool, speed = float, bezier = name })
-- or spring = name instead of bezier
-- speed unit: deciseconds (speed=1 → 100ms)
```

Curves:

```lua
hl.curve("myBezier", { type = "bezier", points = { {X0,Y0}, {X1,Y1} } })
hl.curve("mySpring", { type = "spring", mass = 1.0, stiffness = 300, dampening = 28 })
```

Spring physics: more stiffness = faster; more damping = less bounce. ζ = c/(2√(km)); ζ=1 critical (fast, no overshoot), ζ>1 overdamped (slow, no bounce), ζ<1 underdamped (bounces). **Recommended damping ratio ~0.6–0.8 for a responsive feel.** Design béziers at cssportal.com / easings.net.

Styles extras: `popin 80%` (start at 80% size), `slide left|right|top|bottom` (forced side), `slidefade 20%` (move 20% of screen width). **Warning:** `loop` style on `*angle` animations forces constant rendering at refresh rate — battery/CPU hit.

A tasteful "juicy" animation set:

```lua
hl.curve("windowIn", { type = "spring", mass = 1, stiffness = 200, dampening = 22 })   -- slight bounce
hl.curve("windowMove", { type = "spring", mass = 1, stiffness = 500, dampening = 35 })  -- crisp
hl.animation({ leaf = "windows", speed = 5, spring = "windowIn", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", speed = 4, spring = "windowMove" })
hl.animation({ leaf = "workspaces", speed = 6, spring = "windowMove", style = "slide" })
hl.animation({ leaf = "specialWorkspace", speed = 6, spring = "windowMove", style = "slidevert" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default", style = "loop" })
-- ^ pairs with a gradient active border for the flowing rainbow border look
```

---

## 12. Decorations: blur, shadows, glow, wobble, motion blur

The `decoration` tree beyond rounding/opacity:

| Section | Notable options |
|---|---|
| `decoration.blur` | `enabled`, `size`, `passes` (increase passes for big sizes!), `noise`, `contrast`, `brightness`, `vibrancy`, `vibrancy_darkness`, `popups`, `popups_ignorealpha`, `input_methods`, `ignore_opacity`, `new_optimizations` (leave on), `xray`, and **`variant`** |
| `decoration.blur` variants | `kawase` (default), `acrylic` (liquid glass: `aberration`, `bulb`, `clarity`, `refraction`, `tint`), `aurora` (`color1`, `color2`, `intensity`, `speed`), `drops`, `fluid_jar`, `frost`, `haze`, `heat_shimmer`, `prism`, `ripple`, `water` |
| `decoration.shadow` | `enabled`, `color`/`color_inactive` (alpha = opacity), `offset` (vec2), `range` (px), `render_power` (1–4 falloff), `scale`, `sharp` |
| `decoration.glow` | `enabled` (inner glow), `color`, `color_inactive`, `range`, `render_power` |
| `decoration.motion_blur` | `enabled` (blur while moving/resizing), `samples` [1-64] — very "rice", costs GPU |
| `decoration.wobble` | jelly windows while moving/resizing: `mesh`, `stiffness`, `damping`, `mass`, `intensity`, `value/velocity_epsilon` |

Blur rules of thumb: `size=8, passes=3` is safe; go `size=12, passes=4` on strong GPUs. `blur.size`/`passes` must be ≥1. `xray=true` makes floating bars (waybar) look great for cheap.

The liquid-glass rice:

```lua
hl.config({
  decoration = {
    rounding = 14, rounding_power = 2.0,
    blur = { enabled = true, size = 12, passes = 4, noise = 0.02,
             contrast = 0.9, brightness = 1.05, popups = true, xray = true,
             variant = "acrylic",
             acrylic = { aberration = 0.03, bulb = 40, clarity = 0.85, refraction = 20,
                         tint = "rgba(26,27,38,0.6)" } },
    shadow = { enabled = true, range = 20, render_power = 4, scale = 1.1,
               offset = {0, 5}, color = "rgba(000000aa)", color_inactive = "rgba(00000044)" },
  },
})
```

---

## 13. Layouts: dwindle / master / scrolling / monocle

`general.layout` picks the default; per-workspace override via workspace rules.

### Dwindle (BSPWM-like binary tree — default)

Splits are dynamic (W>H → side-by-side) unless `preserve_split = true`.

```lua
hl.config({
  dwindle = {
    force_split = 0,              -- 0 mouse, 1 left, 2 right
    preserve_split = false,       -- true = permanent splits
    smart_split = false,          -- cursor-triangle split decision (enables preserve_split)
    smart_resizing = true,        -- resize direction from mouse corner
    permanent_direction_override = false,
    special_scale_factor = 1.0,   -- window scale in special ws
    split_width_multiplier = 1.0, -- for ultrawide
    use_active_for_splits = true,
    default_split_ratio = 1.0,
    split_bias = 0,               -- 0 directional / 1 current window
    precise_mouse_move = false,
  },
})
```

Dwindle-specific dispatcher / layout messages:

```lua
hl.bind("SUPER + SHIFT + P", hl.dsp.window.pseudo())
hl.bind("SUPER + A", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + CTRL + H", hl.dsp.layout("splitratio -0.1"))
hl.bind("SUPER + CTRL + L", hl.dsp.layout("splitratio +0.1"))
hl.bind("SUPER + CTRL + G", hl.dsp.layout("splitratio 1.0 exact"))
-- also: swapsplit, rotatesplit [-90|90|180], preselect <dir>, movetoroot [window, [unstable]]
```

### Master (main window + stack)

```lua
hl.config({
  master = {
    new_status = "master",         -- or "slave", or "inherit"
    new_on_top = false,
    mfact = 0.55,                  -- master width ratio (also via layout("mfact 0.6"))
    special_scale_factor = 1.0,
    orientation = "left",          -- left|right|top|bottom|center
    always_center_master = false,
    allow_small_split = false,
    smart_resizing = true,
  },
})
-- messages: hl.dsp.layout("mfact 0.6"), "orientationcenter", "orientationright",
-- "addmaster", "removemaster" (also dedicated hl.dsp.master.* dispatchers)
```

### Scrolling (paperwm-like columns) & monocle

Set per-workspace with `hl.workspace_rule({ workspace = "2", layout = "scrolling" })` or globally. Scrolling config keys live under `scrolling.*` (column width/scale...). `monocle` = one window fullscreened per ws (great with tabs/groups).

---

## 14. Events — scripting your desktop with Lua callbacks

Register as many handlers as you like with `hl.on()`:

```lua
hl.on("window.active", function(w, reason)
  -- e.g. update a state file your bar reads
end)
```

Full event list (parameters in parentheses):

| Event | Fires when | Params |
|---|---|---|
| `hyprland.start` / `hyprland.shutdown` | once | — |
| `window.open` / `window.open_early` | mapped (early = pre-rules) | Window |
| `window.close` / `window.destroy` / `window.kill` | closed / post-animation / killed | Window |
| `window.active` | focus change | Window, int reason |
| `window.urgent` / `window.bell` | urgency / system bell (even muted) | Window |
| `window.title` / `window.class` / `window.pin` / `window.fullscreen` / `window.update_rules` | property changed | Window |
| `window.move_to_workspace` | moved | Window, Workspace |
| `window.minimize` | minimize request | Window, bool |
| `layer.opened` / `layer.closed` | layer surfaces (bar, island...) | LayerSurface |
| `monitor.added` / `monitor.removed` / `monitor.focused` / `monitor.layout_changed` | hotplug etc. | Monitor |
| `workspace.active` / `workspace.special_active` / `workspace.created` / `workspace.removed` / `workspace.move_to_monitor` | workspace life | Workspace [, Monitor] |
| `config.reloaded` / `config.unload` / `config.props_refreshed` | config lifecycle | — |
| `keybinds.submap` | submap changed | String |
| `screenshare.state` | share start/stop | Bool, Int, Str |
| `input.keyboard.key` | any key press/release/repeat | keycode, ts, state(0/1/2) |

Recipe examples:

```lua
-- Auto-float a window whose title changes AFTER opening (static rules can't):
hl.on("window.title", function(w)
  if w ~= nil and w.title == "foo" then
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
  end
end)

-- Focus-flash the border when something urgent happens:
hl.on("window.urgent", function(w)
  if w then hl.notification.create({ text = "Urgent: " .. w.title, duration = 3000, icon = "warning" }) end
end)

-- Save/restore on config unload:
hl.on("config.unload", function() --[[ flush state, kill timers ]] end)
```

Also: `hl.notification.create({ text = ..., duration = ..., icon = ..., color = ..., font_size = ... })` is built in (that's the OSD/notify popup you see on volume changes in default configs).

**Prop refreshes:** rule-creating events are batched — if you need a rule's effect *immediately* in the same Lua function, call `hl.exec_scheduled_prop_refresh_immediately()` (sparingly — it can slow things down; watch `config.props_refreshed`).

---

## 15. Timers, `hl.exec_cmd`, and the golden rule of non-blocking binds

```lua
local demo = hl.timer(function()
  print("tick")
end, { timeout = 1000, type = "repeat" })     -- ms; "oneshot" also valid

demo:set_enabled(false)
hl.bind("SUPER + X", function() demo:set_enabled(not demo:is_enabled()) end)
```

**Pattern: debounce a wallpaper/theme switcher:**

```lua
local t
hl.on("workspace.active", function(ws)
  if t then t:set_enabled(false) end
  t = hl.timer(function()
    hl.exec_cmd("switch-wallpaper.sh " .. tostring(ws.id))   -- async spawn
  end, { timeout = 300, type = "oneshot" })
end)
```

`hl.exec_cmd(cmd)` = async `sh -c` — the escape hatch for anything blocking; `hl.exec_raw(cmd)` skips the shell. Inside binds prefer building `hl.dsp.exec_cmd(...)` descriptors. To probe the system from Lua (rare), bound it with `timeout`.

---

## 16. Ricing the shell: bar, launcher, notifications, wallpaper, lock

### Waybar (safe default)

`waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css`. Module prefixes are **hyprland/**: `hyprland/workspaces`, `hyprland/window` (title — not wlr!), `hyprland/submap`. Start it in your `hyprland.start` event (or `systemctl --user enable --now waybar.service` under uwsm).

Blurb from the wiki FAQ: replace `#workspaces button.focused` with `button.active` in CSS; workspace scrolling needs custom `"on-scroll-up": "hyprctl dispatch 'hl.dsp.focus({workspace=\"e+1\"})'"`.

```jsonc
// config.jsonc excerpt
"modules-left": ["hyprland/workspaces", "hyprland/submap"],
"modules-center": ["hyprland/window"],
"modules-right": ["tray", "pulseaudio", "network", "cpu", "memory", "clock"],
"hyprland/workspaces": { "format": "{icon}", "format-icons": ["₁","₂","₃","₄","₅","₆","₇","₈","₉"] },
```

Blur it: `hl.layer_rule({ match = { namespace = "waybar" }, blur = true })`.

### ashell — the zero-config bar

Rust + iced, ready out of the box with workspaces/battery/network/clock. Choose it if you don't want to fight CSS. Limited tweaking.

### Desktop shells (bar+launcher+notifications+lock in one)

- **Noctalia** — minimal, calm look, theming with presets, wallpaper-based color generation, DND, plugin system, built on Quickshell.
- **DankMaterialShell** — Material 3 design, replaces waybar+fuzzel+mako+swaylock at once, GUI settings app, wallpaper theming that reaches GTK/Qt, Quickshell + Go. Optimized for Hyprland among others.
- Also notable: **Caelestia**, and **Tide Island** as an add-on island (separate guide of yours).

### Launcher

**hyprlauncher** (first-party) or **fuzzel** (fast, simple) or **rofi** (now Wayland-native since 2025, unlimited plugins), tofi (single frame!), anyrun, walker, bemenu, wofi.

```lua
hl.bind(M .. " + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind(M .. " + SHIFT + D", hl.dsp.exec_cmd("fuzzel --log-indicator"))  -- etc
```

Layer-rule your launcher for the rice: blur + ignore_alpha:

```lua
hl.layer_rule({ match = { namespace = "fuzzel" }, blur = true, ignore_alpha = 0.4 })
```

### Notifications

**dunst** (classic, dunstify to test), **mako**, **fnott**, or **swaync** (notification *center* with panel UI — pairs beautifully with an island-less setup). Remember: some apps (Discord) freeze without any daemon running.

### Wallpaper

- **hyprpaper** — first-party, `~/.config/hypr/hyprpaper.conf` (`preload =`, `wallpaper = DP-1,/path.png`).
- **swww** — animated transitions between wallpapers (the ricer's choice): `swww img ~/walls/wall.png --transition-type grow --transition-fps 60`.
- **mpvpaper** — video wallpaper.
- Switch with a bind:

```lua
local walls = { "/home/YOU/walls/a.png", "/home/YOU/walls/b.png", "/home/YOU/walls/c.png" }
local i = 1
hl.bind(M .. " + W", function()
  i = (i % #walls) + 1
  hl.exec_cmd("swww img " .. walls[i] .. " --transition-type random --transition-duration 2")
end)
```

### Lock + idle

hyprlock (first-party, GPU-accelerated blur!) + hypridle:

```nix
# nixpkgs
environment.systemPackages = with pkgs; [ hyprlock hypridle ];
```

```lua
-- hyprland.lua glue
hl.on("hyprland.start", function() hl.exec_cmd("hypridle") end)
hl.bind(M .. " + ESCAPE", hl.dsp.exec_cmd("hyprlock"))  -- demo; real bind via loginctl lock
```

```
# ~/.config/hypr/hypridle.conf (hyprlang — hypridle doesn't take Lua)
# Full key reference: general { lock_cmd, unlock_cmd, on_lock_cmd, on_unlock_cmd,
#   before_sleep_cmd, after_sleep_cmd, ignore_dbus_inhibit, ignore_systemd_inhibit,
#   ignore_wayland_inhibit, inhibit_sleep (0 disable / 1 normal / 2 auto / 3 lock) }
# listener { timeout, on-timeout, on-resume, ignore_inhibit } — see §27.
general {
    lock_cmd = pidof hyprlock || hyprlock   # avoid stacking lock instances
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
listener {
    timeout = 600
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
    on-resume  = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}
```

```
# ~/.config/hypr/hyprlock.conf (hyprlang — hyprlock doesn't take Lua)
# Note: background blur keys are blur_passes / blur_size (NOT size/passes).
# Blur params (noise, contrast, brightness, vibrancy, vibrancy_darkness) inherit
# Hyprland blur defaults unless overridden here. See §27 for full widget list.
background {
    monitor =
    path = /home/YOU/walls/lock.png
    blur_passes = 3
    blur_size = 8
}
input-field {
    monitor =
    size = 250, 50
    outline_thickness = 2
    dots_size = 0.2
    placeholder_text =
    fail_text = $FAIL <span foreground="##f7768e">WRONG</span>
}
```

### Clipboard

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
end)
hl.bind(M .. " + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
```

### Screenshots

```lua
hl.bind("Print",       hl.dsp.exec_cmd('grim -g "$(slurp)" - | satty -f - --copy-command wl-copy'))
hl.bind("SUPER + Print", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"))   -- full screen
```

Or **Flameshot** (you already have it on this system) — works via portal; ensure xdg-desktop-portal-hyprland is the picked portal for screenshots.

---

## 17. Theming workflow: matugen + a single source of truth

The pro move: **generate your whole palette from your wallpaper** with **matugen** (Material You), then feed every app.

1. `matugen image ~/walls/wall.png -t scheme-palette && cat ~/.config/matugen/config.toml`
2. Template output files (matugen writes CSS variables / JSON / whatever you template) — e.g. `~/.cache/matugen/material.css` with `@define-color accent #...`.
3. `@import` it in waybar's `style.css`, fuzzel's `ini`, kitty theme, and generate the Hyprland side with a small script that writes `~/.config/hypr/theme.lua`:

```lua
-- theme.lua (auto-generated; keep in git for reproducibility)
return {
  accent = "rgb(7aa2f7)",
  accent2 = "rgb(bb9af7)",
  bg = "rgb(1a1b26)",
  fg = "rgb(c0caf5)",
  inactive = "rgb(414868)",
}
```

Then `hyprland.lua`:

```lua
local theme = dofile(os.getenv("HOME") .. "/.config/hypr/theme.lua")
hl.config({
  general = { col = { active_border = { colors = { theme.accent, theme.accent2 }, angle = 45 } } },
  decoration = { shadow = { color = theme.bg .. "ee" } },
})
```

4. Re-run matugen in your wallpaper-switch bind → entire desktop recolors.

Community dots to study: **3rfaan/dotfiles-hyprland** (307★ Lua config + ricing), **CelestialShade-Config** (self-contained Lua-driven ecosystem), **fancypantalons/hyprland-config** ("pushes Lua to the limit"), **Noctalia**/**DankMaterialShell** (Quickshell shells with built-in wallpaper theming).

---

## 18. Fonts, cursors, GTK/Qt theming on NixOS

```nix
# fonts
fonts.packages = with pkgs; [
  nerd-fonts.jetbrains-mono
  nerd-fonts.symbols-only # icon fallback
  noto-fonts
  noto-fonts-cjk-sans
];
```

In config: `misc.font_family = "JetBrainsMono Nerd Font"` (and `misc.splash_font_family`).

**Cursors** (the notorious pain): set via Home-Manager if you adopt it:

```nix
home.pointerCursor = {
  gtk.enable = true;
  package = pkgs.bibata-cursors;
  name = "Bibata-Modern-Classic";
  size = 24;
};
```

Without HM, use dconf:

```nix
programs.dconf.profiles.user.databases = [{
  settings."org/gnome/desktop/interface" = {
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Classic";
    font-name = "Sans 11";
  };
}];
```

**GTK/Qt apps**: use `nwg-look` (GTK) and `hyprland-qt-support` (Qt6 style integration — "hyprqt6engine" per the master tutorial). NixOS quirk: GTK themes need `programs.dconf.enable = true;` and packages installed; QT needs `qt = { enable = true; platformTheme = "qt5ct"; style = "kvantum"; }` or similar.

---

## 19. Making it all declarative: Home-Manager (or not)

Your flake has Home-Manager staged but disabled. Options, honestly ranked for you:

### Option A — imperative `~/.config/hypr/` (totally fine!)

The wiki: "you can still do it imperatively by simply putting your hyprland.lua in ~/.config/hypr/. While that is not the recommended method, it is still an option in which neither of the two ways described below are needed." Keep your dots in git (a bare repo or chezmoi); iterate fast; no rebuild needed for config changes. **Recommended while learning** — reload takes 1 second vs. rebuilds taking minutes.

### Option B — Home-Manager module (declarative)

```nix
# flake.nix
home-manager = {
  url = "github:nix-community/home-manager";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# home.nix
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;        # use the NixOS module's Hyprland (keep in sync!)
    portalPackage = null;
    systemd.variables = [ "--all" ];   # fixes services not seeing env
    # settings = { ... };  # generate hyprland.conf — SKIP when using Lua!
    # The HM module's `settings` generates hyprlang. For Lua, use:
    # importantConfigFiles or extraConfig... the cleanest path on Lua-era
    # Hyprland: manage hyprland.lua as a dotfile (home.file) instead:
  };

  home.file.".config/hypr/hyprland.lua".source = ./hyprland.lua;
}
```

> The `wayland.windowManager.hyprland.settings` option emits **hyprlang conf**, not Lua. With Hyprland 0.55+ Lua configs, the idiomatic declarative approach is `home.file.".config/hypr/hyprland.lua".source = ...` (and friends for theme.lua etc.). (Also possible: [hjem](https://wiki.hypr.land/nix/configuring-hyprland-with-hjem/) — a lighter HM alternative for pure file-linking.)

The NixOS module stays **required** (session files, portals) even when HM manages config. Plugin management differs on Nix: `hyprpm` unsupported; use `wayland.windowManager.hyprland.plugins = [ pkgs.hyprlandPlugins.<name> ]` or the hyprland-plugins flake with `inputs.hyprland-plugins.inputs.hyprland.follows = "hyprland"`.

### Option C — NixOS-only, config written by `writeText`

```nix
environment.etc."xdg/hypr/hyprland.lua".source = pkgs.writeText "hyprland.lua" ''
  hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
'';
```
(`$XDG_CONFIG_DIRS` lookup — works, but home files are nicer.)

**Hybrid sweet spot (my actual recommendation for you):** NixOS module for system glue + packages; keep `~/.config/hypr/*.lua` as plain files in a git repo; enable HM later for terminal/ssh/git and adopt the Hyprland files then.

---

## 20. NixOS module options cheat-sheet

```nix
programs.hyprland = {
  enable = true;            # NixOS module: session, portals, env
  package = <hyprland pkg>; # defaults to pkgs.hyprland
  portalPackage = <xdph>;   # keep in sync with package
  xwayland.enable = true;   # also: xwayland force_zero_scaling via config
  # withUWSM = true;        # run via Universal Wayland Session Manager (systemd session, recommended)
};
```

Package overrides:

```nix
(pkgs.hyprland.override {
  enableXWayland = true;
  withSystemd = true;
})
# or overrideAttrs: (hyprland.overrideAttrs (s: super: { cmakeBuildType = "Debug"; }))
# nix repl: :lf github:hyprwm/Hyprland  →  :bl outputs.packages.x86_64-linux.hyprland
```

Systemd env note (fixes "works in terminal, not in services"):

```nix
wayland.windowManager.hyprland.systemd.variables = [ "--all" ];
# equivalent Lua:
hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)
```

---

## 21. Debugging, hyprctl, logs

```bash
hyprctl version
hyprctl reload                      # reload config
hyprctl monitors all                # outputs + availableModes
hyprctl clients                     # windows: class, title, xwayland?, at/size, workspace
hyprctl workspaces
hyprctl layers                     # layer surfaces (bars, launchers, island)
hyprctl binds                      # incl. descriptions from the description flag
hyprctl dispatch 'hl.dsp.focus({workspace="e+1"})'   # dispatch Lua-style
hyprctl eval 'hl.config({ ["general.gaps_in"] = 0 })'  # runtime config change
hyprctl kill <address>              # kill a window
hyprctl activewindow
hyprctl globalshortcuts             # D-Bus global shortcuts state
```

IPC socket exists (`$HYPRLAND_INSTANCE_SIGNATURE`), but the wiki is blunt: *"It's recommended to use Lua in most cases. Lua is faster, less error-prone, has more features, and is generally more integrated."*

Logs/errors: run `Hyprland` from a TTY and read stdout; config errors also print on `hyprctl reload`. `journalctl --user -u hyprland*` when under uwsm/systemd. `hyprctl rollinglog` for recent log lines. Disable watchdog warnings with `misc.disable_watchdog_warning = true` if you don't use `start-hyprland`.

---

## 22. Common pitfalls on NixOS

1. **Mixing Hyprland/XDPH versions** (flake + nixpkgs) → portals misbehave. Always same source.
2. **`settings` vs Lua** — HM's `settings` writes hyprlang. If `hyprland.conf` exists, **remove it** when you switch to `hyprland.lua`, or the conf may take precedence/shadow.
3. **Blocking binds** freeze the desktop — no `io.popen`, no `wl-paste` in callbacks; use `hl.exec_cmd`.
4. **Dispatchers inside functions need `hl.dispatch()`** — `hl.dsp.x()` alone is a no-op.
5. **NVIDIA Electron flicker** — `NIXOS_OZONE_WL=1` early (it's a NixOS-ism), driver ≥ 555.
6. **No notification daemon** → Discord/Electron hangs. autostart `dunst`.
7. **Cursor wrong in some apps** → `home.pointerCursor.gtk.enable` + `XCURSOR_SIZE` env.
8. **Systemd user services can't find commands** → `dbus-update-activation-environment --systemd --all` on start (HM `systemd.variables = ["--all"]`).
9. **SDDM + Hyprland** works; keep SDDM ≥ 0.20.0 (you have a recent one).
10. **Tearing "not working"** — game must be fullscreen, alone on the output, `immediate = true` rule + `allow_tearing` master toggle, and monitor tearing state: check `hyprctl monitors` → `activelyTearing` / `tearingBlockedBy`.
11. **`hl.config` "didn't apply"** — scheduled prop refresh batching; you rarely need `hl.exec_scheduled_prop_refresh_immediately()`.
12. **Numerical workspaces 0/negative** — forbidden (1..2147483647).

---

## 23. Vendor GPU matrix: NVIDIA vs AMD vs Intel

Same Hyprland, very different NixOS glue. Pick your row:

| | **NVIDIA (proprietary)** | **AMD (amdgpu, open)** | **Intel (i915 / Xe, open)** |
|---|---|---|---|
| Kernel driver | `nvidia` / `nvidia_drm` (out-of-tree) | `amdgpu` (in-tree, auto-loaded) | `i915` (older) / `xe` (Arc / Battlemage B580+, Lunar Lake+) |
| Modesetting / early KMS | `hardware.nvidia.modesetting.enable = true` (= `nvidia_drm modeset=1`; default after 535, still set it explicitly) | late KMS by default; early KMS via `hardware.amdgpu.initrd.enable = true` (sets `boot.initrd.kernelModules = [ "amdgpu" ]`) — mainly for Plymouth flicker-free boot | automatic; force-probe new chips with `boot.kernelParams = [ "i915.force_probe=<id>" ]` or `xe.force_probe=e20b` + `i915.force_probe=!e20b` |
| Firmware | bundled with driver | `hardware.firmware = [ pkgs.linux-firmware ]` if you see `amdgpu: Failed to get gpu_info firmware` | `hardware.enableRedistributableFirmware = true` + GuC/HuC: `boot.kernelParams = [ "i915.enable_guc=3" ]` |
| Base graphics | `hardware.graphics.enable = true` | same | same + `hardware.graphics.extraPackages = [ intel-media-driver vpl-gpu-rt ]` (+ `intel-compute-runtime` for OpenCL on Arc/Xe) |
| Env vars needed? | **yes** (see below) | **no** — HDR / wide-color just works, no special env | **no**, except VA-API driver select (`LIBVA_DRIVER_NAME=iHD` only if autodetect fails) |
| VA-API video decode | `nvidia-vaapi-driver` + `LIBVA_DRIVER_NAME=nvidia` + `NVD_BACKEND=direct` (EGL backend broken ≥525; direct is default) | mesa built-in (`radeonsi`); nothing to set | `intel-media-driver` (iHD, Broadwell+) provides VA-API; legacy `libva-intel-driver` (i965) only for GMA4500–Coffee Lake |
| Explicit sync / flicker floor | driver **≥555** + xwayland **≥24.1** + wayland-protocols **≥1.34** (Electron 35/Chromium 134+ syncobj path) | n/a | n/a |
| Power / laptop | `powerManagement.enable` (suspend services + `NVreg_PreserveVideoMemoryAllocations`); `finegrained` for Turing+ offload (experimental) | `power-profiles-daemon` + `AQ_DRM_DEVICES` for hybrid (see §30) | low-power by default; `power-profiles-daemon` |
| Brightness | `brightnessctl` via `nvidia` backlight or ddcci; often desktop-only | `brightnessctl` device `amdgpu_bl*` | `brightnessctl` device `intel_backlight` |

### NVIDIA snippet (your case — extends §4)

```nix
{ pkgs, ... }: {
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];  # enables the NixOS nvidia module
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;  # experimental; can break suspend on some boxes — test
    # open = true;                   # REQUIRED for 50xx (Blackwell); recommended Turing+ (16xx/20xx+)
    # package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  # VA-API on NVDEC (Firefox decode):
  hardware.graphics.extraPackages = with pkgs; [ nvidia-vaapi-driver libva ];
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";           # official NixOS way to hint Electron/CEF → Wayland
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";  # only if Xwayland GL picks wrong vendor
  };
}
```

Lua side stays minimal (`hl.env` also works, but `environment.sessionVariables` survives systemd/uwsm better):

```lua
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
-- hl.env("NVD_BACKEND", "direct")  -- if not set via NixOS env above
```

### AMD snippet

```nix
{ pkgs, ... }: {
  hardware.graphics.enable = true;
  hardware.amdgpu.initrd.enable = true;   # early KMS (optional; best with Plymouth)
  hardware.firmware = [ pkgs.linux-firmware ];
  # services.xserver.videoDrivers = [ "amdgpu" ];  # only needed to force the driver / non-hybrid
}
```
No Hyprland env vars. HDR/wide-color (§24) works out of the box; verify with `hyprctl monitors all`.

### Intel snippet

```nix
{ pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver   # VA-API iHD (Broadwell+ / Xe / Arc)
      vpl-gpu-rt           # oneVPL/QSV runtime
      # intel-compute-runtime  # OpenCL NEO, optional
    ];
  };
  hardware.enableRedistributableFirmware = true;  # GuC/HuC firmware
  boot.kernelParams = [ "i915.enable_guc=3" ];    # if FFmpeg/VAAPI/QSV init fails on Arc/i915
}
```

> Never set `LIBVA_DRIVER_NAME=nvidia` on AMD/Intel or hybrid boxes — it breaks video accel. One vendor per variable. Check with `vainfo` + `nix-shell -p libva-utils --run vainfo`.

---

## 24. HDR and color management deep dive

Hyprland exposes monitor color plumbing directly in `hl.monitor()` (full field list in §8):

```lua
hl.monitor({
  output = "DP-1",
  mode = "3840x2160@144",
  bitdepth = 10,          -- recommended when the panel supports it (8bit+FRC panels lie)
  cm = "hdr",             -- see presets below
  sdrbrightness = 1.2,    -- typical 1.0–2.0
  sdrsaturation = 0.98,
})
```

**`cm` presets** (`colorManagementPreset` in `hyprctl monitors all`): `auto` (srgb@8bpc, wide@10bpc — recommended default), `srgb` (default), `wide` (BT.2020), `dcip3`, `dp3` (Apple P3), `adobe`, `edid` (inaccurate), `hdr` / `hdredid` (wide gamut + PQ transfer, experimental).

**`sdr_eotf`**: `default` (follows `render:cm_sdr_eotf`), `gamma22`, `srgb` (piecewise). An applied `icc = "/absolute/path.icm"` forces `sdr_eotf` to sRGB and **overrides** `cm` — and ICCs are fundamentally incompatible with HDR gaming.

**EDID / SDR→HDR mapping overrides:**

```lua
hl.monitor({
  output = "DP-1",
  supports_wide_color = 1,  -- -1 off, 0 auto, 1 force
  supports_hdr = 1,         -- -1 off, 0 auto, 1 force (needs wide gamut)
  sdr_min_luminance = 0.005,-- 0.005 = true-black match; default 0.2
  sdr_max_luminance = 200,  -- default 80; reasonable 80–400
  -- min_luminance / max_luminance / max_avg_luminance: monitor physical limits, from EDID unless forced
})
```

Fullscreen HDR without `cm="hdr"` is possible when `render:cm_auto_hdr` is enabled (auto-adds `hdr`/`hdredid` for fullscreen HDR content):

```lua
hl.config({ render = { cm_auto_hdr = 1, cm_fs_passthrough = 0 } })
```

**Verify:**

```bash
hyprctl monitors all   # check colorManagementPreset, sdrBrightness/Saturation/Min/MaxLuminance, currentFormat (want XRGB2101010 @10bit)
```

Per-window HDR opt-out: `hl.window_rule({ match = { class = "..." }, no_auto_hdr = true })`.

> AMD/Intel: wide-color/HDR needs no env vars. NVIDIA: HDR path is driver-sensitive — keep driver ≥555 and prefer DisplayPort.

---

## 25. Plugins on NixOS (hyprpm unsupported)

**`hyprpm` does not work on NixOS.** Plugins must be built against your exact Hyprland revision. Two supported paths (both require the NixOS or HM module — `wayland.windowManager.hyprland.plugins`):

**A. nixpkgs plugins (stable Hyprland from nixpkgs):**

```nix
# home.nix
{ pkgs, ... }: {
  wayland.windowManager.hyprland.plugins = [
    pkgs.hyprlandPlugins.hy3
    # pkgs.hyprlandPlugins.hyprexpo etc.
  ];
}
# discover: nix search nixpkgs#hyprlandPlugins
```

**B. `hyprland-plugins` flake (official vaxry plugins: hyprbars, hyprexpo, borders-plus-plus, csgo-vulkan-fix, hyprfocus) — use with the Hyprland flake:**

```nix
# flake.nix
{
  inputs = {
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";  # CRITICAL: locks plugin ABI to your Hyprland
    };
  };
}
# home.nix
{ inputs, pkgs, ... }: {
  wayland.windowManager.hyprland = {
    enable = true;
    plugins = [
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];
  };
}
```

**Custom plugin** via `hyprlandPlugins.mkHyprlandPlugin` (same builder nixpkgs uses):

```nix
# plugin.nix
{ lib, fetchFromGitHub, cmake, hyprland, hyprlandPlugins }: hyprlandPlugins.mkHyprlandPlugin (finalAttrs: {
  pluginName = "hy3";
  version = "0.39.1";
  src = fetchFromGitHub {
    owner = "outfoxxed"; repo = "hy3";
    rev = "hl ${finalAttrs.version}";
    hash = "sha256-...";
  };
  nativeBuildInputs = [ cmake ];
  meta = { homepage = "https://github.com/outfoxxed/hy3"; license = lib.licenses.gpl3; platforms = lib.platforms.linux; };
})
# home.nix: plugins = [ (pkgs.callPackage ./plugin.nix {}) ];
```

Without HM, symlink-join plugin `.so`s and point `HYPR_PLUGIN_DIR` at them, then `hyprctl plugin load "$HYPR_PLUGIN_DIR/lib/libhyprexpo.so"`. Check with `hl.get_loaded_plugins()` / `hyprctl ... plugins`. Always update Hyprland + plugins inputs together.

---

## 26. UWSM session (recommended launch path)

NixOS 24.11+ can launch Hyprland via **UWSM (Universal Wayland Session Manager)** — systemd-integrated session (`graphical-session.target`, `wayland-session@Hyprland.target`). This is the **recommended** standalone path:

```nix
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;   # recommended for most users; auto-enables programs.uwsm
    xwayland.enable = true;
  };
}
```

Rules:

- **HM conflict:** if you use the Home-Manager Hyprland module, you MUST disable its systemd integration — it fights UWSM:
  ```nix
  wayland.windowManager.hyprland.systemd.enable = false;
  ```
- **Launch:** from TTY: `uwsm start select` (picker) or `uwsm start hyprland.desktop`; via loginShellInit: `if uwsm check may-start; then exec uwsm start hyprland.desktop; fi`. Display managers select the `Hyprland (UWSM)` / `hyprland-uwsm.desktop` entry (`uwsm start -F -- .../start-hyprland`). Plain `start-hyprland` remains the non-UWSM TTY path.
- **Env under UWSM:** don't rely on `hl.env` for session-wide vars — export in `~/.config/uwsm/env-hyprland` instead (e.g. `export AQ_DRM_DEVICES="/dev/dri/card0:/dev/dri/card1"`). For autostart daemons prefer `systemctl --user enable --now hypridle.service` over bare `hl.exec_cmd("hypridle")`.
- **Exit correctly:** avoid the raw `exit` dispatcher / killing Hyprland under UWSM (breaks ordered shutdown). Bind `uwsm stop` (or `loginctl terminate-user ""` if units wedge) instead of `hl.dsp.exit()`. `misc.disable_watchdog_warning = true` silences the start-hyprland watchdog notice if you launch unconventionally.

---

## 27. hyprlock / hypridle / hyprpaper fuller reference

All three are **hyprlang, not Lua**. Manage declaratively with HM (`programs.hyprlock.settings`, `services.hypridle.settings`, `services.hyprpaper.settings`) or plain files under `~/.config/hypr/`.

### hyprlock (`~/.config/hypr/hyprlock.conf`)

Widgets: `background`, `image`, `shape`, `input-field`, `label`. Key excerpts (verified against wiki + example.conf):

```
general {
    grace = 0                  # seconds before auth required (also: grace_no_mouse, grace_no_touch)
    hide_cursor = false
    no_fade_in = false
    no_fade_out = false
    ignore_empty_input = false
    immediate_render = false   # draw background:color before background:path loads (--immediate-render)
    fractional_scaling = 2     # 0 off, 1 on, 2 auto
    disable_loading_bar = false
}
background {
    monitor =
    path = screenshot          # or /abs/path.png, or empty → flat color
    color = rgba(17, 17, 17, 1.0)
    blur_passes = 3            # 0 disables; NOTE: blur_passes/blur_size, not size/passes
    blur_size = 8              # default 7
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.05
}
input-field {
    monitor =
    size = 20%, 5%
    outline_thickness = 3
    dots_size = 0.25           # 0.2–0.8; dots_spacing -1.0–1.0; dots_center/rounding/fade_time
    # dots_text_format = *     # letter instead of dots
    # hide_input = true        # swaylock-style indicator (uses hide_input_base_color)
    outer_color = rgba(33ccffee) rgba(00ff99ee) 45deg
    inner_color = rgba(0, 0, 0, 0.0)
    font_color = rgb(143, 143, 143)
    fade_on_empty = false      # + fade_timeout = 2000
    placeholder_text = Input password...
    fail_text = $PAMFAIL       # supports $FAIL / $ATTEMPTS vars; fail_timeout/fail_transition
    check_color = rgba(00ff99ee) rgba(ff6633ee) 120deg
    fail_color = rgba(ff6633ee) rgba(ff0066ee) 40deg
    position = 0, -20
    halign = center
    valign = center
}
label {
    monitor =
    text = cmd[update:1000] echo "$(date +"%H:%M")"  # cmd[] polling, $USER supported
    color = rgba(216, 222, 233, 0.70)
    font_size = 120
    font_family = Noto Sans
    position = 0, 250
    halign = center
    valign = center
}
```

CLI: `hyprlock --grace 5 --immediate-render -c FILE`. If no config is found hyprlock **exits with error and does not lock** — always keep a config.

### hypridle (`~/.config/hypr/hypridle.conf` — required file, won't run without it)

```
general {
    lock_cmd = pidof hyprlock || hyprlock
    unlock_cmd =
    on_lock_cmd =
    on_unlock_cmd =
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
    ignore_dbus_inhibit = false
    ignore_systemd_inhibit = false
    ignore_wayland_inhibit = false
    inhibit_sleep = 2          # 0 disable, 1 normal, 2 auto, 3 lock
}
listener {
    timeout = 150
    on-timeout = brightnessctl -s set 10
    on-resume = brightnessctl -r
}
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
listener {
    timeout = 330
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}
listener {
    timeout = 1800
    on-timeout = systemctl suspend
    # condition_cmd = ~/.config/hypr/scripts/can-suspend.sh  # exit 0 = allow
    # condition_retry = 30
}
```

Notes: quote the whole `hyprctl dispatch '...'` Lua expression with **single quotes** so the shell passes braces through; on NixOS prefer absolute paths (`${pkgs.systemd}/bin/loginctl lock-session`, `${cfg.finalPackage}/bin/hyprctl dispatch dpms on`). `dpms` goes through `hl.dsp.dpms({ action = ... })` — there is no `hl.dsp.dpms` *table* to index, it is a dispatcher call. Never put `dpms`/`force_idle` directly on a keybind — wrap in a oneshot `hl.timer(..., { timeout = 500, type = "oneshot" })` per the dispatchers wiki warning.

### hyprpaper (`~/.config/hypr/hyprpaper.conf`)

```
preload = /home/YOU/walls/a.png
preload = /home/YOU/walls/b.png
wallpaper = DP-1,/home/YOU/walls/a.png
wallpaper = eDP-1,/home/YOU/walls/b.png
wallpaper = ,/home/YOU/walls/fallback.png   # empty monitor = fallback
ipc = true        # enables hyprpaper IPC (needed by some switchers)
splash = false    # disable splash text
```

Reload wallpapers without restart via `hyprctl hyprpaper ...` when `ipc = true`.

---

## 28. Missing Lua APIs: gestures, devices, custom layouts

### Gestures — `hl.gesture()`

```lua
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", mods = "ALT", action = "close" })
hl.gesture({ fingers = 2, direction = "pinch", action = "cursor_zoom", zoom_level = 2.0, mode = "mult" })
-- directions: swipe|horizontal|vertical|left|right|up|down|pinch|pinchin|pinchout
-- actions: workspace|move|resize|special (workspace_name=)|close|fullscreen (mode="maximize")|
--          float (mode="float"|"tile")|cursor_zoom (zoom_level=, mode="mult"|"live")|scroll_move|unset|lua fn
-- opts: mods="SUPER"|"ALT SHIFT", scale=1.5, disable_inhibit=true

-- live Lua gestures: table with start/update/finish
hl.gesture({
  fingers = 3, direction = "vertical",
  action = {
    start  = function(e) hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") end,
    update = function(e) --[[ e.delta.x/y, e.scale, e.rotation, e.fingers, e.time_ms ]] end,
    finish = function(e) --[[ e.cancelled ]] end,
  },
})
```

### Devices — `hl.device()`

All `input.*` options (incl. `input.touchpad.*`) work per-device, EXCEPT `force_no_accel` and window-management keys (`follow_mouse`, `float_switch_override_focus`, `mouse_refocus`, `special_fallthrough`, ...). Plus device-only extras: `output` (tablets — use the `Tablet` name), `keybinds`, `tags`, `resolve_binds_by_sym`.

```lua
hl.device({ name = "my-epic-keyboard", sensitivity = -0.5, kb_layout = "us,cz" })
hl.device({ name = "my-tablet", output = "DP-1" })
```

Pair with per-device binds (§9): `hl.bind("SUPER + Q", dsp, { device = { inclusive = true, list = { "my-epic-keyboard" } } })`.

### Custom layouts — `hl.layout.register(name, { recalculate, layout_msg? })`

Use as `lua:name` (globally or per-workspace rule):

```lua
hl.layout.register("columns", {
  recalculate = function(ctx)
    local n = #ctx.targets
    if n == 0 then return end
    for i, target in ipairs(ctx.targets) do
      target:place(ctx:column(i, n))   -- prefer :place over :set_box (handles gaps/pseudo/reserved)
    end
  end,
  -- layout_msg = function(msg, ctx) --[[ handle hl.dsp.layout("...") strings ]] end,
})
hl.config({ general = { layout = "lua:columns" } })
-- ctx helpers: grid_cell, column, row, split; ctx.area, ctx.targets; target.window (may be nil/groups)
```

### Dotted `hl.config` paths + runtime `eval`

Single-option form (merges like the table form, last write wins):

```lua
hl.config({ ["general.gaps_in"] = 0 })
hl.config({ ["decoration.blur.size"] = 12 })
```

Read-modify-write via getters, and push one-shot changes without reload:

```lua
hl.bind("SUPER + SHIFT + G", function()
  if hl.get_config("general.gaps_in").top == 3 then
    hl.config({ ["general.gaps_in"] = 0 })
  else
    hl.config({ ["general.gaps_in"] = 3 })
  end
end)
```

```bash
hyprctl eval 'hl.config({ ["general.gaps_in"] = 0 })'   # runtime, resets on reload
hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "3" }))'
hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'    # dispatch = shorthand for that eval
hyprctl repl 'hl.get_active_window().class'             # one-shot REPL print
hyprctl repl                                            # interactive Lua REPL
```

Full getter list: `hl.get_config(path?)`, `hl.get_active_window()`, `hl.get_windows()`, `hl.get_window(sel)`, `hl.get_urgent_window()`, `hl.get_workspaces()`, `hl.get_workspace(sel)`, `hl.get_active_workspace()`, `hl.get_active_special_workspace()`, `hl.get_monitors({ all? })`, `hl.get_monitor(sel)`, `hl.get_active_monitor()`, `hl.get_monitor_at({ x, y })`, `hl.get_monitor_at_cursor()`, `hl.get_cursor_pos()`, `hl.get_last_window()`, `hl.get_last_workspace()`, `hl.get_layers()`, `hl.get_workspace_windows(sel)`, `hl.get_current_submap()`, `hl.get_loaded_plugins()`, `hl.is_key_down(key)`, `hl.version()`, `hl.exec_scheduled_prop_refresh_immediately()`.

---

## 29. Portals, security, PAM

```nix
{ pkgs, ... }: {
  # Hyprland's NixOS module already enables xdg.portal + its own portal package.
  # Only ADD the GTK fallback (file pickers); never replace the Hyprland portal.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # hyprlock needs a PAM service or it cannot authenticate (HM-installed hyprlock especially):
  security.pam.services.hyprlock = {};
  # + gnome-keyring unlock via SDDM if you use it:
  # services.gnome.gnome-keyring.enable = true;
  # security.pam.services.sddm.enableGnomeKeyring = true;
}
```

Rules:

- **Same-source rule:** `programs.hyprland.package` and `programs.hyprland.portalPackage` must come from the same source (both nixpkgs or both flake). Mixing breaks screenshots, screen-share, file pickers.
- **Screen-share/global shortcuts:** check `hyprctl globalshortcuts`; Flameshot/OBS work via `xdg-desktop-portal-hyprland` — if the wrong portal answers, pin `xdg.portal.config` per-interface.
- **Polkit:** `hyprpolkitagent` in autostart covers GUI privilege prompts; no extra PAM needed for it.

---

## 30. Laptop specifics: hybrid, power, backlight

**Pick the primary GPU** with `AQ_DRM_DEVICES` (colon-separated, priority order). iGPU-first saves battery; the dGPU path must still be listed if an external monitor is wired to it:

```lua
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")  -- verify with ls -l /dev/dri/by-path/
```

Find cards via `lspci -d ::03xx` + `ls -l /dev/dri/by-path/`. `cardN` symlinks shuffle across boots — prefer stable `/dev/dri/by-path/pci-0000:XX:XX.X-card` paths or a udev symlink (e.g. `/dev/dri/amd-igpu`). Under UWSM export it in `~/.config/uwsm/env-hyprland` instead:

```
export AQ_DRM_DEVICES="/dev/dri/card1:/dev/dri/card0"
```

**Power:**

```nix
{ pkgs, ... }: {
  services.power-profiles-daemon.enable = true;  # balanced/power-saver/performance via GUI
  services.thermald.enable = true;               # Intel laptops
  # services.tlp.enable = false;                 # do NOT run tlp + power-profiles-daemon together
}
```

**Backlight (find yours first: `brightnessctl -l`):**

```bash
brightnessctl -l                          # look for amdgpu_bl* (AMD) vs intel_backlight (Intel)
brightnessctl -d amdgpu_bl0 set 10%       # AMD example
brightnessctl -d intel_backlight set 10%  # Intel example
```

Bind + idle-restore pair:

```lua
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))
```

```
# hypridle.conf — dim on idle, restore on resume (per-device class!)
listener {
    timeout = 150
    on-timeout = brightnessctl -s set 10
    on-resume = brightnessctl -r
}
```

Keyboard backlight variant: `brightnessctl -sd rgb:kbd_backlight set 0` / `brightnessctl -rd rgb:kbd_backlight`.

---

## 31. Further reading

- Wiki (all Lua-era): <https://wiki.hypr.land> — Configuring ▸ Core ▸ (Config options, Binds, Monitors, Rules, Dispatchers, Animations, Advanced configuration ▸ Lua utilities / Lua events / Using hyprctl), Nix section, NVIDIA, Tearing, Useful utilities.
- Lua config references: `3rfaan/dotfiles-hyprland`, `shadowdevforge/CelestialShade-Config`, `fancypantalons/hyprland-config`, converters `EIonTusk/hyprlang2lua`, `Phillezi/hypr2lua`, validator `Paritsingla7/hyprvalidate`.
- Shells to rice with: Noctalia, DankMaterialShell, Caelestia; islands: **Tide-island** (see `TIDE-ISLAND-NIXOS-GUIDE.md`).
- **The companion docs written for you:** `MANGOWC-RICING-GUIDE.md` (dwl-style rice), `TIDE-ISLAND-NIXOS-GUIDE.md` (implementing + extending Tide Island).
- awesome-hyprland (the big list).
