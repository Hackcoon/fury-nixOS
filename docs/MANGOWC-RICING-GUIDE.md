# MangoWC (mangowm) — The Complete Ricing Guide

> **What:** Mango (aka MangoWC, package `mangowm`) is a lightweight, feature-rich Wayland compositor built on **dwl** (which is built on wlroots) with **scenefx** visual effects. Philosophy: as light as dwl, builds in seconds, but with daily-driver features — scrolling layout, overview, scratchpads, animations, blur/shadows, IPC, hot-reload config.
>
> **Sources:** mangowm.github.io official docs (Quick Start, Installation, Configuration, Visuals, Window Management, Bindings, IPC, FAQ, Nix options — extracted 2026-09-05), DreamMaoMao/mango-config, tonybtw.com tutorial, community rices (lingllqs/dotfiles, KozmunkasKalman/mangowc-rice, So1d/matugen-mangowc-dots, tonybanters/mangowc-btw), danklinux.com/docs (DMS Compositor Setup + NixOS pages) and docs.noctalia.dev (Noctalia Mango + NixOS pages) — extracted 2026-09-06.

---

## Table of Contents

1. [Mango vs Hyprland — mental model](#1-mango-vs-hyprland--mental-model)
2. [Installing on NixOS](#2-installing-on-nixos)
3. [Config file anatomy & the rice loop](#3-config-file-anatomy--the-rice-loop)
4. [Monitors](#4-monitors)
5. [Input: keyboard, mouse, touchpad, gestures](#5-input-keyboard-mouse-touchpad-gestures)
6. [Keybinds: flags, keymodes, media keys](#6-keybinds-flags-keymodes-media-keys)
7. [Mouse binds, axis binds, gestures, lid switches](#7-mouse-binds-axis-binds-gestures-lid-switches)
8. [Window rules — the rice workhorse](#8-window-rules--the-rice-workhorse)
9. [Tag rules & special workspace (tag 0)](#9-tag-rules--special-workspace-tag-0)
10. [Layer rules (bar, launcher, notifications)](#10-layer-rules-bar-launcher-notifications)
11. [Layouts: scroller, tile, monocle, dwindle, grid, deck, fair...](#11-layouts-scroller-tile-monocle-dwindle-grid-deck-fair)
12. [Scratchpads: pool, named, minimized](#12-scratchpads-pool-named-minimized)
13. [Overview mode & jump labels](#13-overview-mode--jump-labels)
14. [Visuals: gaps, borders, colors, theming](#14-visuals-gaps-borders-colors-theming)
15. [Window effects: blur, shadows, opacity, corner radius](#15-window-effects-blur-shadows-opacity-corner-radius)
16. [Animations](#16-animations)
17. [Misc settings that matter](#17-misc-settings-that-matter)
18. [IPC: `mmsg` — scripting your rice](#18-ipc-mmsg--scripting-your-rice)
19. [XDG portals, screen share, clipboard, keyring](#19-xdg-portals-screen-share-clipboard-keyring)
20. [The full rice: a complete reference config.conf](#20-the-full-rice-a-complete-reference-configconf)
21. [Declarative NixOS/HM configuration for mango](#21-declarative-nixoshm-configuration-for-mango)
22. [Ricing the ecosystem: bar, launcher, notifications, wallpaper, lock](#22-ricing-the-ecosystem-bar-launcher-notifications-wallpaper-lock)
23. [Full desktop shells: DankMaterialShell & Noctalia on Mango](#23-full-desktop-shells-dankmaterialshell--noctalia-on-mango)
24. [Vendor GPUs, NVIDIA / gaming: tearing & syncobj](#24-vendor-gpus-nvidia--gaming-tearing--syncobj)
25. [FAQ / troubleshooting](#25-faq--troubleshooting)
26. [Community configs to steal from](#26-community-configs-to-steal-from)

---

## 1. Mango vs Hyprland — mental model

Coming from the Hyprland guide? Translation table:

| Concept | Hyprland | Mango |
|---|---|---|
| Config language | Lua (`hl.*`) | **plain INI-style `config.conf`** (`key=value`, `bind=...`) |
| Workspaces | workspaces (+special:) | **tags** (dwm-style bitmask, 1–31, tag 0 = special overlay) |
| Reload | `hyprctl reload` | `mmsg dispatch reload_config` (hot-reload, no restart) |
| IPC client | `hyprctl` | **`mmsg`** (get/watch/dispatch) |
| Rules | `hl.window_rule{match=...}` | `windowrule=Param:Value,appid:regex,title:regex` |
| Submaps | `hl.define_submap` | **`keymode=<name>`** blocks |
| Overview | plugins/shells | **built-in** `toggleoverview`, jump labels |
| Effects | built-in blur variants/glow/wobble | scenefx blur/shadows/opacity/radius (simpler set) |
| Config split | dofile/require | `source=`, `source-optional=` |
| Validate | `hyprctl reload` errors | **`mango -c config.conf -p`** (dry-run parse) |

Mango's own doc line on scope: *stability first, practicality over novelty, focused scope.*

Why rice Mango instead of Hyprland? It's **suckless-adjacent**: one config file, dwm-like tags with independent layouts per tag, excellent Xwayland, built-in overview/scratchpads, and it sips resources. If Hyprland is a DE-lego set, Mango is a Swiss knife.

---

## 2. Installing on NixOS

The repo (github.com/mangowm/mango) ships a **flake with NixOS + Home-Manager modules**.

### Flake setup

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # mango needs recent wlroots; consider an unstable slice just for it
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mangowm, ... }@inputs: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        mangowm.nixosModules.mango     # or import in configuration.nix
        ./configuration.nix
      ];
    };
  };
}
```

```nix
# configuration.nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.mangowm.nixosModules.mango ];
  programs.mango = {
    enable = true;
    # package default: mango-nightly
  };
}
```

NixOS module options (auto-generated docs):

| Option | Type | Default | Meaning |
|---|---|---|---|
| `programs.mango.enable` | bool | false | install + register session |
| `programs.mango.package` | package | mango-nightly | the compositor package |
| `programs.mango.addLoginEntry` | bool | **true** | registers a DM login entry (SDDM will show "mango") |

Module side-effects (what `enable = true` pulls in — declare these yourself only if you need to override):
`xdg.portal.config` gets a mango entry + `xdg.portal.extraPortals` gains wlr/gtk portals, `security.polkit.enable` on (auth agent still needs a GUI provider — xfce-polkit/polkit-gnome in systemPackages), `programs.xwayland.enable` on, and the mango package lands in session packages so `addLoginEntry` sessions resolve. HM side: the Home-Manager module validates the generated config at build time with `mango -c <generated> -p` — a bad `settings` attr fails `home-manager switch` before it touches your live config. Prefer `settings` (structured, flatten `animation_curve.open` → `animation_curve_open`, lists for duplicate keys); use `extraConfig` only for raw lines the module can't model — anything expressible in `settings` belongs there.

### Launching

Since `addLoginEntry = true` (default), mango appears in SDDM as a session once enabled. Options from the docs:

**A. greetd** (TUI greeter + autologin):

```nix
services.greetd = {
  enable = true;
  settings = {
    initial_session = { command = "mango"; user = "fury"; };
    default_session = { command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd mango"; user = "greeter"; };
  };
};
```

**B. Display-manager autologin** (you already run SDDM):

```nix
services.displayManager = {
  defaultSession = "mango";
  autoLogin = { enable = true; user = "fury"; };
};
```

**C. getty TTY autologin**:

```nix
services.getty.autologinUser = "fury";
environment.loginShellInit = ''
  [ "$(tty)" = /dev/tty1 ] && exec mango
'';
```

### Companion packages (the rice ecosystem)

```nix
environment.systemPackages = with pkgs; [
  # mango's recommended companions
  foot                    # terminal (mango default)
  rofi-wayland           # launcher (mango default) — or fuzzel/wmenu/bemenu
  waybar                 # bar (or build mangobar from source — see §22)
  swaybg                 # wallpaper (or swww)
  dunst or swaync        # notifications
  wl-clipboard cliphist wl-clip-persist
  grim slurp satty       # screenshots
  brightnessctl pamixer  # brightness/volume
  wlr-randr              # monitor introspection
  wlsunset               # night light (mango has no built-in)
  xfce.polkit or polkit_gnome  # auth agent (xfce-polkit per docs)
  swaylock-effects       # lock screen (docs' choice) or hyprlock
  wlogout                # logout menu
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
  font-awesome  # icons (bar glyphs)
];
```

### Non-NixOS quick reference (for completeness)

- Arch: `yay -S mangowc-git` (AUR) — config default at `/etc/mango/config.conf`
- Fedora: Terra repo `dnf install mangowm`
- Gentoo: GURU overlay `gui-wm/mangowm` (+`gui-libs/scenefx` unmask)
- FreeBSD has it too: `x11-wm/mango` (`pkg install x11-wm/mango`)
- From source: build wlroots 0.20.2 → scenefx 0.5 → mango (meson/ninja, deps: wayland, wayland-protocols, libinput, libdrm, libxkbcommon, pixman, libdisplay-info, libliftoff, hwdata, seatd, pcre2, pango, cjson, xorg-xwayland, libxcb).

---

## 3. Config file anatomy & the rice loop

Config lives in **`~/.config/mango/config.conf`** (launch with custom path: `mango -c /path/config.conf`). Copy the default from `/etc/mango/config.conf` to start.

```bash
mkdir -p ~/.config/mango
cp /etc/mango/config.conf ~/.config/mango/config.conf   # non-NixOS default location
```

**Split into files:**

```bash
source=~/.config/mango/bind.conf       # import binds
source=./theme.conf                    # relative path
source-optional=~/.config/mango/local.conf   # skip silently if missing
```

**Validate without starting:**

```bash
mango -c ~/.config/mango/config.conf -p
```

**Hot-reload** — keybind `bind=SUPER,R,reload_config` (or `mmsg dispatch reload_config`). The docs' rice loop is 10x faster than NixOS rebuilds: edit config → reload → observe.

Format basics:

```bash
# comments with #
key=value
env=VARNAME,value          # env vars (reset on every reload!)
exec-once=waybar           # run once at startup
exec=bash ~/.config/mango/reload-settings.sh   # run on EVERY reload
bind=SUPER,Return,spawn,foot
windowrule=isfloating:1,appid:firefox
monitorrule=name:^eDP-1$,width:1920,height:1080
```

> ⚠ `env=` values are **reset on every config reload** — don't put session-critical state there. Prefer NixOS `environment.sessionVariables` for sticky vars.

Suggested structure:

```
~/.config/mango/
├── config.conf        # sources the rest + core settings
├── binds.conf
├── rules.conf
├── theme.conf          # colors, effects, animations
├── autostart.sh
└── wallpaper/
```

---

## 4. Monitors

Syntax:

```
monitorrule=name:Values,Parameter:Values,Parameter:Values
```

Matching: if any of `name`, `make`, `model`, `serial` are set, **all set ones must match**. Names support regex — exact match needs `^...$`. Find your identifiers: `wlr-randr`.

| Parameter | Type | Notes |
|---|---|---|
| `name` `make` `model` `serial` | string | matchers (name = regex) |
| `width` `height` | 0–9999 | resolution |
| `refresh` | float | Hz |
| `x` `y` | int | position in layout |
| `scale` | float 0.01–100 | HiDPI |
| `vrr` | 0/1 | adaptive sync |
| `hdr` `hdr_min_lum` `hdr_max_lum` `hdr_max_avg_lum` `hdr_force` | | HDR (wl-only branch, needs `env=WLR_RENDERER,vulkan`) |
| `icc` | path | ICC profile; mutually exclusive with hdr (hdr wins; set `hdr:0` for ICC) |
| `rr` | 0–7 | transform: 0 none, 1 90°ccw, 2 180°, 3 270°, 4 vflip, 5–7 flips+rotations |
| `custom` | 0/1 | custom mode (may black-screen!) |
| `disable` | 0/1 | remove from layout |

> **XWayland rule:** never use negative monitor coordinates if you run X11 apps via Xwayland — clicks misfire (known XWayland bug). Start at 0,0 and extend positive.

```
# Laptop panel exact-match:
monitorrule=name:^eDP-1$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1

# By make/model:
monitorrule=make:Chimei Innolux Corporation,model:0x15F5,width:1920,height:1080,refresh:60

# External high-refresh + VRR:
monitorrule=name:^DP-1$,width:2560,height:1440,refresh:165,x:1920,y:0,vrr:1

# Disable the laptop screen when docked:
monitorrule=name:^eDP-1$,disable:1
```

Runtime monitor control (also keybindable): `sleep_monitor`, `wakeup_monitor`, `sleep_toggle_monitor`, `disable_monitor`, `enable_monitor`, `toggle_monitor` — all take a **monitor spec**:

```
name:xxx&&make:xxx&&model:xxx&&serial:xxx   # any subset, any order; bare string = monitor name
mmsg dispatch toggle_monitor,eDP-1
```

**Tearing (game mode):** global `allow_tearing=0|1|2` (2 = fullscreen only); per-window `windowrule=force_tearing:1,...`. Matrix: window `force_tearing` UNSPECIFIED follows `tearing_hint` when global=1 (fullscreen-only when global=2); ENABLED allows (fullscreen-only when global=2); DISABLED never tears; global=0 disables all. Some GPUs need `env=WLR_DRM_NO_ATOMIC,1` before mango starts (see §24).

### HDR (wl-only branch)

HDR needs the Vulkan renderer — scenefx isn't supported there yet:

```
env=WLR_RENDERER,vulkan
monitorrule=name:^DP-1$,...,hdr:1,hdr_max_lum:616,hdr_max_avg_lum:400
# relogin once after setting
```

| Setting | Meaning |
|---|---|
| `hdr_depth` | 0 default / 1 HDR8 / 2 HDR10 |
| `hdr_min_lum` / `hdr_max_lum` / `hdr_max_avg_lum` | mastering-display metadata in cd/m² (0 = unset; `hdr_max_lum` also sent as max_cll). Get values from `di-edid-decode` → *HDR Static Metadata Data Block* |
| `hdr_force` | 1 = enable HDR even when EDID hides the HDR block (DisplayID 2.0 / CTA nested containers wlroots can't see). Still requires `WLR_RENDERER=vulkan` |
| `icc` | ICC profile path — **mutually exclusive with HDR: HDR wins**; set `hdr:0` to use ICC |

Runtime toggle (no reload; reload re-applies `monitorrule` over it — sway-style `output hdr on|off|toggle` equivalent):

```
mmsg dispatch togglehdr              # focused monitor
mmsg dispatch togglehdr,on
mmsg dispatch togglehdr,off,eDP-1
mmsg dispatch togglehdr,toggle,all   # one decision for all: if anything on → all off; non-HDR outputs skipped
```

> `hdr_min_lum` is a no-op on wlroots 0.20.x (atomic.c underflow bug; fixed upstream `f6a01b40`, not backported).

---

## 5. Input: keyboard, mouse, touchpad, gestures

### Keyboard (globals)

```
repeat_rate=25          # repeats/second
repeat_delay=600        # ms before repeat
numlockon=0             # NumLock on start
xkb_rules_layout=us,de  # layouts
xkb_rules_variant=dvorak
xkb_rules_options=caps:escape,ctrl:nocaps
```

Layout switching:

```
xkb_rules_layout=us,us
xkb_rules_variant=,dvorak
xkb_rules_options=grp:lalt_lshift_toggle
bind=alt,shift_l,switch_keyboard_layout      # or bind manually; mmsg get keyboardlayout to query
```

### Mouse

| Setting | Default | Meaning |
|---|---|---|
| `mouse_natural_scrolling` | 0 | invert scroll |
| `mouse_accel_profile` | 2 | 0 none / 1 flat / 2 adaptive |
| `mouse_accel_speed` | 0.0 | -1.0..1.0 |
| `mouse_left_handed` | 0 | swap buttons |
| `mouse_middle_button_emulation` | 0 | |
| `mouse_scroll_method` | 1 | 1 two-finger / 2 edge / 4 button |
| `mouse_scroll_button` | 274 | 272 LMB … 279 task |
| `mouse_click_method` | 1 | 1 button-areas / 2 clickfinger |
| `mouse_send_events_mode` | 0 | 0 on / 1 off / 2 off-when-external-pointer |
| `axis_scroll_factor` | 1.0 | 0.1–10.0 |

### Touchpad (some need relogin)

`disable_trackpad`, `tap_to_click` (1), `tap_and_drag` (1), `trackpad_natural_scrolling`, `trackpad_accel_profile/speed`, `trackpad_scroll_method/button`, `trackpad_click_method`, `trackpad_send_events_mode`, `drag_lock` (1), `trackpad_disable_while_typing` (1), `trackpad_left_handed`, `trackpad_middle_button_emulation`, `swipe_min_threshold` (1), `button_map` (0 left/right/middle, 1 left/middle/right), `trackpad_scroll_factor` (1.0).

### Gesture live-preview (trackpad swipe feel)

```
gesture_live=1                     # 1 = drive tag/focus/overview transition while fingers move; 0 = act only on release
gesture_swipe_distance=300         # px of finger travel = one full page transition
gesture_swipe_cancel_ratio=0.5     # release past this fraction commits the page; below it animates back
gesture_swipe_min_speed_to_force=10  # avg per-event px speed that forces a commit (quick flicks) even below cancel ratio
```

Live preview only animates bound `gesturebind` commands that transition state (e.g. `viewprev_have_client`/`viewnext_have_client`, `toggleoverview`); with `gesture_live=0` everything fires on release. Tune: lower `gesture_swipe_distance` (e.g. 220) for shorter strokes, raise `cancel_ratio` (e.g. 0.65) if pages commit too eagerly.

### Touchscreen

`touch_enable` (1), `touch_enable_mouse_emulation` (0). No `touch_map_to_mon` — pin touch/tablet via devicerule, e.g. `devicerule=name:ELAN Touchscreen,monitor:HDMI-A-1` (unset = follow current screen).

### Per-device overrides (`devicerule`)

Find device names by using them:

```
mmsg watch all-devices     # move mouse / type — prints the device name per event
mmsg get all-devices       # list everything
```

```
devicerule=name:AT Translated Set 2 keyboard,kb_layout:ru
devicerule=name:A4Tech USB Mouse,natural_scrolling:1,accel_speed:0.1
devicerule=type:touchpad,tap_to_click:1
```

Rule options: keyboard (`kb_layout`, `kb_variant`, `kb_options`, `kb_rules`, `kb_model`, `repeat_rate`, `repeat_delay`) and pointer (`accel_speed`, `accel_profile`, `natural_scrolling`, `left_handed`). Exact-name rules beat `type:` rules; first match wins. A rule with kb_* options makes that keyboard **independent** (own keymap/repeat) — unmatched keyboards stay synchronized in one group.

### IME (Fcitx5 example)

```
env=GTK_IM_MODULE,fcitx
env=QT_IM_MODULE,fcitx
env=QT_IM_MODULES,wayland;fcitx
env=SDL_IM_MODULE,fcitx
env=XMODIFIERS,@im=fcitx
env=GLFW_IM_MODULE,ibus
```
(requires WM restart to take effect)

---

## 6. Keybinds: flags, keymodes, media keys

### Syntax & flags

```
bind[flags]=MODIFIERS,KEY,COMMAND,PARAMETERS
```

- Modifiers: `SUPER CTRL ALT SHIFT NONE`, combined with `+` (e.g. `SUPER+CTRL+ALT`).
- Key: keysym name from `wev`/`xev`, or `code:NN` keycode.
- `bind` converts keysym→keycode (layout-proof-ish, occasionally imprecise → use `code:24` style, or `binds=` for keysym matching).

| Flag | Letter | Effect |
|---|---|---|
| locked | `l` | works while screen locked |
| keysym | `s` | bind by keysym, not keycode |
| release | `r` | trigger on release |
| pass | `p` | pass the key to the client too |
| conflict | `c` | allow duplicate binds (must set on **all** conflicting binds) |

```
bind=SUPER,Q,killclient
bindl=SUPER,L,spawn,swaylock
bind=NONE,XF86MonBrightnessUp,spawn,brightnessctl set +5%
bind=alt,shift_l,switch_keyboard_layout
bindr=Super,Super_L,spawn,rofi -show run    # on release of Super key
bindc=SUPER,a,resizewin,+10,0               # conflict-tolerant
bindc=SUPER,a,centerwin
```

### Keymodes (submaps)

```
keymode=common
bind=SUPER,r,reload_config

keymode=default
bind=ALT,Return,spawn,foot
bind=SUPER,F,setkeymode,resize

keymode=resize
bind=NONE,Left,resizewin,-10,0
bind=NONE,Right,resizewin,+10,0
bind=NONE,Escape,setkeymode,default
```

- Binds after `keymode=<name>` belong to that mode; without → `default`.
- `common` applies across all modes.
- **Keymodes apply to mousebind, axisbind, gesturebind, switchbind too.**
- Query: `mmsg get keymode`.

### Dispatcher cheat-sheet (the ones you'll actually bind)

**Windows:** `killclient [force]`, `togglefloating`, `toggle_all_floating`, `togglefullscreen`, `togglefakefullscreen`, `togglemaximizescreen`, `toggleglobal` (sticky all tags), `toggle_render_border`, `centerwin`, `minimized`, `restore_minimized`, `toggle_scratchpad`, `toggle_named_scratchpad,appid,title,cmd`, `toggle_special_tag`, `tag_special_tag`, `tag_special_silent`.

**Focus/move:** `focusid`, `focusdir,left|right|up|down`, `focus_window_or_workspace,dir` (focus window else jump to adjacent non-empty tag), `focusstack,next|prev`, `overcircle,next|prev|current_next|current_prev` (overview+cycle; `current_*` restricts overview to current tagset), `focuslast`, `switcher,next|prev|all_tag_next|all_tag_prev|all_next|all_prev` (thumbnail switcher — `next/prev` = current tag, `all_tag_*` = all tags on monitor, `all_*` = all monitors; pick on modifier release!), `exchange_client,dir`, `exchange_stack_client,next|prev`, `move_client,left|right|up|down` (dwindle: re-insert next to neighbor keeping row/column; other layouts: swap like `exchange_client`; no-neighbor + `exchange_cross_monitor=1` = push onto adjacent monitor), `zoom` (swap with master).

**Groups:** `groupjoin,dir`, `groupfocus,prev|next`, `groupleave`.

**Tags/monitors** — masks! `3` = tag 3, `1|3|5` = tags 1,3,5, `0` = all, `-1` = previous tagset:

`view,mask[,synctag]`, `viewtoleft[,synctag]`, `viewtoright[,synctag]`, `view_insert,prev|next` (insert empty tag), `viewtoleft_have_client` / `viewtoright_have_client` (step + focus client if present), `viewcrossmon,mask,monitor_spec`, `tag,mask` (move window), `tagsilent,mask` (move w/o focus), `tagtoleft`, `tagtoright`, `tagcrossmon,mask,monitor_spec`, `toggletag,mask`, `toggleview,mask`, `comboview,mask` (view several tags at once), `focusmon,dir|monitor_spec`, `tagmon,dir|monitor_spec[,keeptag]`.

**Layouts:** `setlayout,name`, `switch_layout` (cycles `circle_layout`), `incnmaster,+1|-1`, `setmfact,+0.05`, `set_proportion,float` (scroller width), `switch_proportion_preset`, `scroller_stack,dir`, `incgaps,+/-v`, `togglegaps`, dwindle: `dwindle_toggle_split_direction` / `dwindle_split_horizontal` / `dwindle_split_vertical` / `dwindle_toggle_current_split`.

**System:** `spawn,cmd` (no pipes!), `spawn_shell,cmd` (pipes OK), `spawn_on_empty,cmd,tagmask` (run cmd on an empty tag), `reload_config`, `load_config_file,path` (load another file live; empty path = reset to default location), `quit`, `toggleoverview[,1]` (`1` = current tagset only), `enteroverview` / `leaveoverview`, `togglejump`, `create_virtual_output` / `destroy_all_virtual_output` (VNC/Sunshine), `toggleoverlay` (pin focused window as overlay), `toggle_trackpad_enable`, `setkeymode,mode`, `switch_keyboard_layout,[index]`, `setoption,key,value` (temporary — lost on next reload/restart; script via `mmsg dispatch setoption,animations,0`), `sleep_monitor`/`wakeup_monitor`/`sleep_toggle_monitor`/`disable_monitor`/`enable_monitor`/`toggle_monitor` + `monitor_spec`.

**Floating move/resize:** `moveresize,curmove|curresize` (mouse-drag verbs), `smartmovewin,dir` / `smartresizewin,dir` (nudge by snap distance), `movewin,x,y` / `resizewin,w,h`.

**Media keys:**

```
bind=NONE,XF86MonBrightnessUp,spawn,brightnessctl s +2%
bind=SHIFT,XF86MonBrightnessUp,spawn,brightnessctl s 100%
bind=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind=SHIFT,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_SOURCE@ toggle
bind=NONE,XF86AudioPlay,spawn,playerctl play-pause
bind=NONE,XF86AudioNext,spawn,playerctl next
bind=NONE,XF86AudioPrev,spawn,playerctl previous
```

---

## 7. Mouse binds, axis binds, gestures, lid switches

### mousebind

```
mousebind=MODIFIERS,BUTTON,COMMAND,PARAMETERS
```
Buttons: `btn_left btn_right btn_middle btn_side btn_extra btn_forward btn_back btn_task` or `code:272...`.

> ⚠ With `NONE` modifiers only `btn_middle` works in normal mode; `btn_left/right` only in overview mode.

```
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize
mousebind=SUPER+CTRL,btn_right,killclient
```

`moveresize,curmove` / `moveresize,curresize` = drag the focused window to move/resize with the cursor (the standard SUPER-drag pair).

### axisbind (scroll wheel)

```
axisbind=MODIFIERS,DIRECTION,COMMAND,PARAMETERS
axisbind=SUPER,UP,viewtoleft_have_client
axisbind=SUPER,DOWN,viewtoright_have_client
```

Directions: `UP DOWN LEFT RIGHT`. Rapid-scroll flood guard: `axis_bind_apply_timeout=100` (ms window for consecutive scroll events, §17).

### gesturebind (touchpad)

```
gesturebind=MODIFIERS,DIRECTION,FINGERS,COMMAND,PARAMETERS
gesturebind=none,left,3,focusdir,left
gesturebind=none,right,3,focusdir,right
gesturebind=none,up,4,toggleoverview
gesturebind=none,down,4,toggleoverview
```

- Directions: `up down left right`; fingers: `3` or `4`.
- Drag-preview pair: `gesturebind=none,right,4,viewprev_have_client` + `gesturebind=none,left,4,viewnext_have_client` animates live when `gesture_live=1` (see §5); `gesture_live=0` fires on release only.
- See §5 for `gesture_swipe_distance` / `gesture_swipe_cancel_ratio` / `gesture_swipe_min_speed_to_force` tuning.

### switchbind (lid)

```
switchbind=FOLD_STATE,COMMAND,PARAMETERS
switchbind=fold,spawn,swaylock -f -c 000000
switchbind=unfold,spawn,wlr-dpms on
```

`FOLD_STATE` is `fold` (lid closed) or `unfold` (lid opened) — no modifiers/key field.
Requires disabling systemd-logind lid handling (`HandleLidSwitch=ignore` etc.) — on NixOS: `services.logind.lidSwitch = "ignore";`.

---

## 8. Window rules — the rice workhorse

Format (one line, multiple params; **appid AND title must both match if both set**; both are regex):

```
windowrule=Parameter:Values,Parameter:Values,appid:regex,title:regex
# ...-once variant: applies ONLY the first time the window opens (re-open re-applies; reload doesn't re-fire):
windowrule-once=Parameter:Values,appid:regex,title:regex
```

**State & behavior:** `isfloating:0/1`, `isfullscreen`, `isfakefullscreen`, `isglobal` (sticky), `isoverlay` (always top), `isopensilent` (no focus), `istagsilent`, `force_fakemaximize`, `ignore_maximize`, `ignore_minimize`, `force_tiled_state` (lie to the window so it accepts its box), `noopenmaximized`, `single_scratchpad`, `allow_shortcuts_inhibit`, `idleinhibit_when_focus` (keep awake while focused), `vrr_only_fullscreen`, `shield_when_capture` (black in screenshots/shares), `force_render`, `activation_bypass` (skip xdg-activation auth).

**Geometry:** `width`/`height` (float <1 = % of screen, else px), `offsetx`/`offsety` (-999..999, **% from center**, ±100 = screen edge with outer gap), `monitor` (monitor spec), `tags` (mask: `3`, `1|3|5`, **`0` = special workspace**), `no_force_center`, `isnosizehint`.

**Visuals:** `noblur`, `isnoborder`, `isnoshadow`, `isnoradius`, `isnoanimation`, `focused_opacity`/`unfocused_opacity` (0.0–1.0), `allow_csd`.

**Scroller:** `scroller_proportion`, `scroller_proportion_single`.

**Animation:** `animation_type_open/close: zoom|slide|fade|none`, `nofadein`, `nofadeout`.

**Swallowing:** `isterm:1` (this window gets replaced by the next GUI window you open from it), `noswallow:1` (never replace a terminal).

**Global/special:** `globalkeybinding:ctrl+alt-o,...` (give apps global hotkeys, Wayland-only), `isunglobal:1` (unmanaged always-on-top window — **desktop pets, camera overlays**), `isnamedscratchpad:1` (see §12).

**Performance:** `force_tearing:1`.

Examples:

```
# Size+position by center-percentage offsets:
windowrule=width:1000,height:900,appid:yesplaymusic,title:Demons

# PiP-ish floating player anywhere:
windowrule=isfloating:1,width:0.3,height:0.25,offsetx:35,offsety:40,appid:mpv

# OBS global hotkeys, open silently:
windowrule=globalkeybinding:ctrl+alt-o,appid:com.obsproject.Studio
windowrule=globalkeybinding:ctrl+alt-n,appid:com.obsproject.Studio
windowrule=isopensilent:1,appid:com.obsproject.Studio

# Games:
windowrule=force_tearing:1,title:Counter-Strike 2

# Auto-open into special workspace (tag 0):
windowrule=tags:0,appid:spotify
windowrule=tags:0,appid:discord

# Opacity ricing:
windowrule=focused_opacity:0.95,appid:firefox
windowrule=unfocused_opacity:0.85,appid:foot

# Selection tools shouldn't blur:
windowrule=noblur:1,appid:slurp

# Send to tag 9 on HDMI-A-1:
windowrule=tags:9,monitor:HDMI-A-1,appid:discord

# Terminal swallowing:
windowrule=isterm:1,appid:st
windowrule=noswallow:1,appid:foot

# Unmanaged desktop pet:
windowrule=isunglobal:1,appid:cheese

# Named scratchpad:
windowrule=isnamedscratchpad:1,width:1280,height:800,appid:st-yazi
```

---

## 9. Tag rules & special workspace (tag 0)

```
tagrule=id:Values[,monitor_name:x,monitor_make:x,monitor_model:x,monitor_serial:x],Parameter:Values
tagrule=id:*,layout_name:scroller      # wildcard = all tags
```

Params: `layout_name`, `no_render_border`, `open_as_floating`, `no_hide` (persistent tag), `nmaster`, `mfact`, `scroller_default_proportion`, `scroller_default_proportion_single`, `scroller_ignore_proportion_single`.

> Tag-rule layouts **override** monitor-rule layouts.

```
tagrule=id:1,layout_name:scroller
tagrule=id:2,layout_name:tile,nmaster:2,mfact:0.6
tagrule=id:1,no_hide:1,layout_name:scroller           # persistent tags 1-4
tagrule=id:6,monitor_name:HDMI-A-1,layout_name:monocle,no_render_border:1
```

**Special workspace = tag 0.** An overlay workspace summoned on any monitor with full layout support; underlying windows stay visible:

```
bind=SUPER,s,toggle_special_tag
bind=SUPER+SHIFT,s,tag_special_tag
bind=SUPER+CTRL,s,tag_special_silent
# Auto-assign apps to it:
windowrule=tags:0,appid:spotify
# Looks:
special_dim=0.5              # background dim while open
special_gappih=10 special_gappiv=10 special_gappoh=20 special_gappov=20
```

Tag counts: `tag_num=9` (1–31), `tag_gather=1` compacts occupied tags toward 1.

---

## 10. Layer rules (bar, launcher, notifications)

```
layerrule=layer_name:regex,Parameter:Values
```

Params: `animation_type_open`, `animation_type_close` (zoom/slide/fade/none), `noblur`, `noanim`, `noshadow`, `shield_when_capture` (pair with `noanim:1`).

Debug tip: **`mmsg get last_open_surface`** prints the layer name you just opened — perfect for writing rules.

```
layerrule=layer_name:waybar,noblur:1
layerrule=layer_name:rofi,animation_type_open:zoom
layerrule=layer_name:notifications,animation_type_open:slide,animation_type_close:fade
```

---

## 11. Layouts: scroller, tile, monocle, dwindle, grid, deck, fair...

Full list: `tile`, `scroller`, `monocle`, `grid`, `deck`, `center_tile`, `vertical_tile`, `right_tile`, `vertical_scroller`, `vertical_grid`, `vertical_deck`, `dwindle`, `fair`, `vertical_fair`. Assign per tag (§9) or switch live: `bind=SUPER,n,switch_layout` with `circle_layout=grid,scroller,tile`.

### Scroller (the Mango signature — PaperWM-like)

| Setting | Default | Meaning |
|---|---|---|
| `scroller_structs` | 20 | side reserve when ratio=1 |
| `scroller_default_proportion` | 0.9 | new-window width proportion |
| `scroller_focus_center` | 0 | always center focused window |
| `scroller_prefer_center` | 0 | center only if it was off-view |
| `scroller_prefer_overspread` | 1 | let windows overspread free space |
| `edge_scroller_pointer_focus` | 1 | focus partial off-screen windows |
| `edge_scroller_focus_allow_speed` | 0.0 | pointer-focus speed gate |
| `scroller_proportion_preset` | 0.5,0.8,1.0 | presets for `switch_proportion_preset` |
| `scroller_ignore_proportion_single` | 1 | |
| `scroller_default_proportion_single` | 1.0 | needs ignore=0 |

Priority: `prefer_overspread > focus_center > prefer_center` — set higher ones to 0 to let lower ones work.

### Master/stack (tile, center_tile, right_tile...)

`new_is_master=1`, `default_mfact=0.55`, `default_nmaster=1`, `center_master_overspread=0`, `center_when_single_stack=1`.

### Dwindle (spiral binary tree)

`dwindle_split_ratio=0.5` (0.05–0.95), `dwindle_smart_split=0` (cursor-side splits), `dwindle_hsplit=1` (0 cursor / 1 right / 2 left), `dwindle_vsplit=1` (0 cursor / 1 below / 2 above), `dwindle_preserve_split=0`, `dwindle_smart_resize=0`, `dwindle_drop_simple_split=1` (2-zone vs 4-quadrant drag preview), `dwindle_manual_split=0`.

---

## 12. Scratchpads: pool, named, minimized

Three mechanisms:

1. **Standard pool (sway-like):** `bind=SUPER,i,minimized` (send), `bind=ALT,z,toggle_scratchpad` (cycle), `bind=SUPER+SHIFT,i,restore_minimized` (retrieve to current tag).
2. **Named scratchpads** — key-summoned apps that launch-if-absent then toggle:

```
windowrule=isnamedscratchpad:1,width:1280,height:800,appid:st-yazi
bind=alt,h,toggle_named_scratchpad,st-yazi,none,st -c st-yazi -e yazi

windowrule=isnamedscratchpad:1,width:1000,height:700,title:kitty-scratch
bind=alt,k,toggle_named_scratchpad,none,kitty-scratch,kitty -T kitty-scratch
```
(`foot --app-id id` / `kitty -T title` / `st -c class` set the matcher; `none` = don't-care field.)
3. **Special workspace (tag 0)** — see §9. Tiling scratchpad with layouts.

Sizing: `scratchpad_width_ratio=0.8`, `scratchpad_height_ratio=0.9`, `scratchpadcolor=0x516c93ff`.
Related misc: `single_scratchpad=1` (only one visible at a time), `scratchpad_cross_monitor=0` (share pool across monitors).

---

## 13. Overview mode & jump labels

The built-in hycov-style overview:

```
bind=SUPER,o,toggleoverview
bind=SUPER,j,togglejump        # overview + jump mode (press a label letter to warp)
overcircle,next                 # open overview & cycle focus — closes on modifier release
```

Mouse in overview: **LMB** focus, **RMB** close.

Settings: `enable_hotarea=1` + `hotarea_size=10` + `hotarea_corner=0..3` (trigger zone), `overviewgappi=5`, `overviewgappo=30`, `overcircle_center_ratio=0.5`, `jump_labels=HJKLASDFGQWERTYUIOPZXCVBNM` (order of hint chars; limits max hinted windows).

Also: `switcher,next|prev|all_tag_next|all_tag_prev|all_next|all_prev` — thumbnail alt-tab that selects when you release the modifier.

---

## 14. Visuals: gaps, borders, colors, theming

### Dimensions

```
borderpx=4
gappih=5      # inner horizontal
gappiv=5      # inner vertical
gappoh=10     # outer horizontal
gappov=10     # outer vertical
```
Plus `togglegaps` / `incgaps,+5` dispatchers, `smartgaps=0` (kill gaps when single window), `no_border_when_single=0`.

### Colors (0xRRGGBBAA)

```
rootcolor=0x323232ff        # root window bg
bordercolor=0x444444ff      # inactive border
focuscolor=0xc66b25ff       # active border
urgentcolor=0xad401fff      # urgent
dropcolor=0x8FBA7C55        # drag-preview silhouette
splitcolor=0xEB441EFF       # dwindle manual-split marker
# state colors:
maximizescreencolor=0x89aa61ff
scratchpadcolor=0x516c93ff
globalcolor=0xb153a7ff
overlaycolor=0x14a57cff
```

### Jump-label & monocle tab-bar theming

`jump_label_decorate_{fg,bg,focus_fg,focus_bg,border}_color`, `jump_label_decorate_border_width=4`, `jump_label_decorate_corner_radius=5`, `jump_label_decorate_padding_{x,y}=10`, `jump_label_decorate_font_desc=monospace Bold 16`. Same pattern for `group_bar_*` (monocle tab bar, `group_bar_height=50`).

### Cursor

```
cursor_size=24
cursor_theme=Adwaita
```
(on NixOS also set `home.pointerCursor`/dconf for full coverage)

---

## 15. Window effects: blur, shadows, opacity, corner radius

(scenefx-powered)

### Blur

| Setting | Default | Meaning |
|---|---|---|
| `blur` | 0 | blur windows |
| `blur_layer` | 0 | blur layer surfaces (bars!) |
| `blur_optimized` | 1 | cache wallpaper as blur backdrop — **huge perf win, keep on** |
| `blur_params_radius` | 5 | strength |
| `blur_params_num_passes` | 1 | smoother but pricier |
| `blur_params_noise` | 0.02 | |
| `blur_params_brightness` | 0.9 | |
| `blur_params_contrast` | 0.9 | |
| `blur_params_saturation` | 1.2 | |

> `blur_optimized=1` blurs against the **wallpaper**, not true stacked content. `blur_optimized=0` composites real content but can lag weaker GPUs.

### Shadows

```
shadows=1
layer_shadows=1
shadow_only_floating=1     # perf saver
shadows_size=10
shadows_blur=15
shadows_position_x=0
shadows_position_y=0
shadowscolor=0x000000ff
```

### Opacity & radius

```
border_radius=8
border_radius_location_default=0    # 0 all, 1..4 single corner, 5 nearest corner
no_radius_when_single=0
focused_opacity=1.0
unfocused_opacity=0.95
```

The classic mango rice combo:

```
blur=1
blur_layer=1
blur_optimized=1
blur_params_radius=6
blur_params_num_passes=2
border_radius=8
shadows=1
layer_shadows=1
shadow_only_floating=1
shadows_size=12
shadows_blur=15
focused_opacity=1.0
unfocused_opacity=0.92
```

---

## 16. Animations

```
animations=1
layer_animations=1
```

Types (open/close per window AND per layer): `slide`, `zoom`, `fade`, `none`.

```
animation_type_open=zoom
animation_type_close=slide
layer_animation_type_open=slide
layer_animation_type_close=slide
```

Fade: `animation_fade_in=1`, `animation_fade_out=1`, `fadein_begin_opacity=0.5`, `fadeout_begin_opacity=0.5`.
Zoom: `zoom_initial_ratio=0.4`, `zoom_end_ratio=0.8`.

Durations (ms): `animation_duration_move=500`, `animation_duration_open=400`, `animation_duration_tag=300`, `animation_duration_close=300`, `animation_duration_focus=0` (opacity transition).

Custom bézier curves (`x1,y1,x2,y2` — design at cssportal.com / easings.net):

```
animation_curve_open=0.46,1.0,0.29,0.99
animation_curve_move=0.46,1.0,0.29,0.99
animation_curve_tag=0.46,1.0,0.29,0.99
animation_curve_close=0.46,1.0,0.29,0.99
animation_curve_focus=0.46,1.0,0.29,0.99
animation_curve_opafadein=0.46,1.0,0.29,0.99
animation_curve_opafadeout=0.5,0.5,0.5,0.5
```

Tag-switch direction: `tag_animation_direction=1` (1 horizontal, 0 vertical).

A snappy set:

```
animations=1
animation_type_open=zoom
animation_type_close=fade
animation_duration_open=250
animation_duration_close=200
animation_duration_move=180
animation_duration_tag=220
animation_curve_open=0.2,0.9,0.3,1.05      # slight overshoot
animation_curve_close=0.4,0,0.6,1
animation_curve_move=0.2,0.8,0.2,1
zoom_initial_ratio=0.85
```

---

## 17. Misc settings that matter

**System:** `xwayland_persistence=1` (keep Xwayland warm — less lag), `xwayland_ignore_scale=0`, `syncobj_enable=1` (drm_syncobj — gaming stutter fix, needs restart), `allow_lock_transparent=0`, `allow_shortcuts_inhibit=1`.

**Focus:** `focus_on_activate=1`, `sloppyfocus=1` (focus follows mouse), `warpcursor=1` (center cursor on keyboard focus), `cursor_hide_timeout=0`, `cursor_hide_on_keypress=0`.

**Dragging:** `drag_tile_to_tile=0` (swap tiles by drag), `drag_tile_small=1`, `drag_corner=3` (0 none, 1–3 corners, 4 auto), `drag_warp_cursor=1`, `drag_tile_refresh_interval=8.0`, `drag_floating_refresh_interval=8.0` (1–16; too low = app lag), `axis_bind_apply_timeout=100`.

**Multi-monitor/tags:** `focus_cross_monitor=0`, `focusdir_only_zone_overlap=1` (1 = directional focus only picks windows overlapping on the perpendicular axis; 0 = nearest in direction wins), `exchange_cross_monitor=0` (gates **both** `exchange_client` and `move_client` — without it neither crosses monitors; with it `exchange_client` swaps monitors, `move_client` pushes onto the adjacent monitor when no neighbor), `focus_cross_tag=0`, `view_current_to_back=0` (1 = re-viewing current tag jumps back to previous tagset), `tag_num=9`, `tag_gather=0`.

**Windows:** `enable_floating_snap=0` + `snap_distance=30`, `smartgaps`, `no_border_when_single`, `idleinhibit_ignore_visible=0` (1 = invisible clients like background audio players **cannot** inhibit idle — set 1 if music keeps your screen awake), `tag_carousel=0` (1 = `viewtoleft`/`viewtoright` wrap around the ends).

---

## 18. IPC: `mmsg` — scripting your rice

`mmsg` talks to the running compositor over a unix socket (`MANGO_INSTANCE_SIGNATURE`). Two modes: **get** (one-shot JSON) and **watch** (streaming JSON), plus **dispatch**.

### get

```
mmsg get version
mmsg get cursorpos
mmsg get keymode
mmsg get keyboardlayout
mmsg get monitor eDP-1
mmsg get focusing-client
mmsg get client <id>
mmsg get tag <mon> <idx>
mmsg get tags <mon>
mmsg get all-clients
mmsg get all-monitors
mmsg get all-devices
mmsg get all-tags
mmsg get last_open_surface [<mon>]
```

### watch (JSON streams — feed waybar/eww/quickshell!)

```
mmsg watch all-tags          # tag state for bars
mmsg watch all-clients
mmsg watch all-monitors
mmsg watch focusing-client
mmsg watch keymode
mmsg watch all-devices
mmsg watch keyboardlayout
mmsg watch last_open_surface
```

### dispatch

```
mmsg dispatch reload_config
mmsg dispatch focusid client,375
mmsg dispatch exchange_client,left client,375
mmsg dispatch setoption,animations,0     # temporary!
mmsg dispatch toggle_monitor,name:xxx&&serial:yyy
```

Scripting example — a wallpaper-follows-tag cycler driven from `watch`:

```bash
#!/usr/bin/env bash
mmsg watch all-tags | while read -r line; do
  # naive JSON scrape; use jq for real
  focus=$(echo "$line" | jq -r '.[] | select(.focused==1) | .idx' 2>/dev/null)
  [[ -n "$focus" ]] && swww img ~/.walls/tag$focus.png --transition-type random
done
```

---

## 19. XDG portals, screen share, clipboard, keyring

Portal config: `~/.config/xdg-desktop-portal/mango-portals.conf` (fallback `/usr/share/xdg-desktop-portal/mango-portals.conf`). Mango now auto-imports `WAYLAND_DISPLAY` etc. to the activation environment — **remove any manual `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots` from old configs.**

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.Secret=gnome-keyring
org.freedesktop.impl.portal.Inhibit=none
```

- **Screen share:** `pipewire`, `pipewire-pulse`, `xdg-desktop-portal-wlr`; optionally autostart `/usr/lib/xdg-desktop-portal-wlr &`. Known: window-share quirks (#184), recording stutter (xwlr#351).
- **Clipboard (persistent + history):** autostart

```
wl-clip-persist --clipboard regular --reconnect-tries 0 &
wl-paste --type text --watch cliphist store &
```
bind: `cliphist list | rofi -dmenu | cliphist decode | wl-copy` (via `spawn_shell`).
- **Keyring:** `gnome-keyring` for VS Code/MC launchers.

---

## 20. The full rice: a complete reference config.conf

```
# ~/.config/mango/config.conf — reference rice
source=~/.config/mango/binds.conf
source-optional=~/.config/mango/theme.local

# ---------- env ----------
env=QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env=XDG_CURRENT_DESKTOP,wlroots

# ---------- monitors ----------
# monitorrule=name:^eDP-1$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1
# monitorrule=name:^DP-1$,width:2560,height:1440,refresh:165,x:1920,y:0,vrr:1
monitorrule=name:.*,width:0,height:0            # auto/fallback-ish

# ---------- look ----------
borderpx=2
gappih=6 gappiv=6 gappoh=12 gappov=12
smartgaps=1
no_border_when_single=1
rootcolor=0x1a1b26ff
bordercolor=0x414868ff
focuscolor=0x7aa2f7ff
urgentcolor=0xf7768eff
splitcolor=0xff9e64ff
maximizescreencolor=0x9ece6aff
scratchpadcolor=0x516c93ff
globalcolor=0xbb9af7ff
overlaycolor=0x7dcfffec

# ---------- effects ----------
blur=1
blur_layer=1
blur_optimized=1
blur_params_radius=6
blur_params_num_passes=2
blur_params_noise=0.02
border_radius=8
no_radius_when_single=1
shadows=1
layer_shadows=1
shadow_only_floating=1
shadows_size=12
shadows_blur=15
shadowscolor=0x000000aa
focused_opacity=1.0
unfocused_opacity=0.92

# ---------- animations ----------
animations=1
layer_animations=1
animation_type_open=zoom
animation_type_close=fade
animation_duration_open=250
animation_duration_close=200
animation_duration_move=180
animation_duration_tag=220
animation_curve_open=0.2,0.9,0.3,1.05
animation_curve_move=0.2,0.8,0.2,1
zoom_initial_ratio=0.85

# ---------- layouts ----------
tag_num=9
circle_layout=scroller,tile,grid,monocle
# per-tag:
tagrule=id:1,layout_name:scroller,no_hide:1
tagrule=id:2,layout_name:tile
tagrule=id:3,layout_name:monocle,no_render_border:1
new_is_master=1
default_mfact=0.55
scroller_default_proportion=0.9
scroller_focus_center=1

# ---------- input ----------
repeat_rate=35
repeat_delay=300
xkb_rules_layout=us
xkb_rules_options=ctrl:nocaps
trackpad_natural_scrolling=1
trackpad_disable_while_typing=1
devicerule=name:Logitech G Pro,natural_scrolling:1

# ---------- focus / misc ----------
sloppyfocus=1
warpcursor=1
focus_on_activate=1
xwayland_persistence=1
syncobj_enable=1
allow_tearing=2            # fullscreen only
vrr handling per monitorrule
idleinhibit_ignore_visible=1

# ---------- overview ----------
enable_hotarea=1
hotarea_size=10
hotarea_corner=2           # bottom-left triggers overview
overviewgappi=5
overviewgappo=30

# ---------- special workspace ----------
special_dim=0.5
special_gappih=10 special_gappiv=10 special_gappoh=20 special_gappov=20

# ---------- rules ----------
# (see §8 full menu)
windowrule=isfloating:1,width:0.85,height:0.7,offsety:-10,appid:pavucontrol
windowrule=isterm:1,appid:foot
windowrule=noswallow:1,appid:foot
windowrule=isnamedscratchpad:1,width:1280,height:800,appid:foot-scratch
windowrule=noblur:1,appid:slurp
windowrule=tags:0,appid:spotify
windowrule=tags:0,appid:discord
windowrule=isopensilent:1,appid:com.obsproject.Studio

layerrule=layer_name:waybar,animation_type_open:none,animation_type_close:none
layerrule=layer_name:rofi,animation_type_open:zoom

# ---------- autostart ----------
exec-once=waybar -c ~/.config/mango/waybar/config.jsonc -s ~/.config/mango/waybar/style.css
exec-once=swaybg -i ~/.config/mango/wallpaper/current.png -m fill
exec-once=dunst
exec-once=wl-clip-persist --clipboard regular --reconnect-tries 0
exec-once=wl-paste --type text --watch cliphist store
exec-once=/usr/libexec/xfce-polkit &
exec-once=wl-paste --watch cliphist store
exec-once=swww-daemon &   # if you use swww instead of swaybg
```

With `binds.conf`:

```
# core
bind=SUPER,Return,spawn,foot
bind=SUPER,d,spawn,rofi -show drun
bind=SUPER,q,killclient
bind=SUPER+SHIFT,q,killclient force
bind=SUPER+SHIFT,m,quit
bind=SUPER,space,togglefloating
bind=SUPER,f,togglefullscreen
bind=SUPER,Tab,focusstack,next
bind=SUPER+SHIFT,Tab,focusstack,prev
bind=SUPER,bracketleft,focuslast

# focus
bind=SUPER,left,focus_window_or_workspace,left
bind=SUPER,right,focus_window_or_workspace,right
bind=SUPER,up,focus_window_or_workspace,up
bind=SUPER,down,focus_window_or_workspace,down
bind=SUPER+SHIFT,left,exchange_client,left
bind=SUPER+SHIFT,right,exchange_client,right
bind=SUPER+SHIFT,up,exchange_client,up
bind=SUPER+SHIFT,down,exchange_client,down

# tags
bind=SUPER,1,view,1
bind=SUPER,2,view,2
bind=SUPER,3,view,3
bind=SUPER,4,view,4
bind=SUPER,5,view,5
bind=SUPER,6,view,6
bind=SUPER,7,view,7
bind=SUPER,8,view,8
bind=SUPER,9,view,9
bind=SUPER+SHIFT,1,tag,1
bind=SUPER+SHIFT,2,tag,2
bind=SUPER+SHIFT,3,tag,3
bind=SUPER+SHIFT,4,tag,4
bind=SUPER+SHIFT,5,tag,5
bind=SUPER+SHIFT,6,tag,6
bind=SUPER+SHIFT,7,tag,7
bind=SUPER+SHIFT,8,tag,8
bind=SUPER+SHIFT,9,tag,9
bind=SUPER,0,toggle_special_tag
bind=SUPER+SHIFT,0,tag_special_tag

# layouts & sizing
bind=SUPER,n,switch_layout
bind=SUPER,t,setlayout,tile
bind=SUPER,s,setlayout,scroller
bind=SUPER,g,togglegaps
bind=SUPER,i,incnmaster,+1
bind=SUPER+SHIFT,i,incnmaster,-1
bind=SUPER,equal,setmfact,+0.05
bind=SUPER,minus,setmfact,-0.05
bind=SUPER,w,set_proportion,0.9
bind=SUPER,p,switch_proportion_preset

# scratchpad & overview
bind=SUPER,minus2... # (mask binds as needed)
bind=SUPER,o,toggleoverview
bind=SUPER,j,togglejump
bind=SUPER,grave,toggle_named_scratchpad,foot-scratch,none,foot --app-id foot-scratch
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize

# resize keymode
keymode=common
bind=SUPER,r,reload_config
keymode=default
bind=SUPER,R,setkeymode,resize
keymode=resize
bind=NONE,Left,resizewin,-40,0
bind=NONE,Right,resizewin,+40,0
bind=NONE,Up,resizewin,0,-40
bind=NONE,Down,resizewin,0,+40
bind=NONE,Escape,setkeymode,default

# screenshots
bind=NONE,Print,spawn_shell,grim -g "$(slurp)" - | satty -f - --copy-command wl-copy
bind=SUPER,Print,spawn_shell,grim -g "$(slurp -d)" - | wl-copy

# media (locked flags)
bindl=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindl=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl=NONE,XF86MonBrightnessUp,spawn,brightnessctl s +2%
bindl=NONE,XF86MonBrightnessDown,spawn,brightnessctl s 2%-

# gestures (laptop)
gesturebind=none,left,3,focus_window_or_workspace,left
gesturebind=none,right,3,focus_window_or_workspace,right
gesturebind=none,left,4,viewtoleft_have_client
gesturebind=none,right,4,viewtoright_have_client
gesturebind=none,up,4,toggleoverview
gesturebind=none,down,4,toggleoverview

# scroll = tag switch
axisbind=SUPER,UP,viewtoleft_have_client
axisbind=SUPER,DOWN,viewtoright_have_client
```

Validate: `mango -c ~/.config/mango/config.conf -p` → reload bind or `mmsg dispatch reload_config`.

---

## 21. Declarative NixOS/HM configuration for mango

The **Home-Manager module** (`wayland.windowManager.mango`) generates `~/.config/mango/config.conf` from Nix attrs:

```nix
# home.nix
{
  wayland.windowManager.mango = {
    enable = true;
    # package = null;  # use the NixOS module's package (keep in sync)

    autostart_sh = ''
      waybar &
      dunst &
      wl-paste --type text --watch cliphist store &
    '';                      # written to ~/.config/mango/autostart.sh + exec-once added

    settings = {
      # effects
      blur = 1;
      blur_optimized = 1;
      blur_params = { radius = 5; num_passes = 2; };
      border_radius = 6;
      focused_opacity = 1.0;

      # animations — nested attrs flatten: animation.duration_open -> animation_duration_open
      animations = 1;
      animation_type_open = "slide";
      animation_type_close = "slide";
      animation_duration_open = 400;
      animation_duration_close = 800;
      animation_curve = {
        open  = "0.46,1.0,0.29,1";
        close = "0.08,0.92,0,1";
      };

      # duplicate keys = lists
      bind = [
        "SUPER,r,reload_config"
        "Alt,space,spawn,rofi -show drun"
        "Alt,Return,spawn,foot"
        "ALT,R,setkeymode,resize"
      ];

      tagrule = [
        "id:1,layout_name:tile"
        "id:2,layout_name:scroller"
      ];

      # keymodes (submaps)
      keymode = {
        resize.bind = [
          "NONE,Left,resizewin,-10,0"
          "NONE,Escape,setkeymode,default"
        ];
      };
    };

    extraConfig = ''
      # raw lines for anything the module doesn't model
    '';

    systemd = {
      enable = true;    # mango-session.target → graphical-session.target, imports env
      variables = [ "DISPLAY" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" "XDG_SESSION_TYPE" "NIXOS_OZONE_WL" ];
      # extraCommands default: reset-failed + start mango-session.target
    };
  };
}
```

Notes:
- `bottomPrefixes` (e.g. `["source"]`) sorts those attrs to the bottom of the generated file (config order matters for `source`).
- With `systemd.enable`, user services/graphical-session.target work like on any DE — use it for hypridle-style daemons via systemd instead of autostart.

Keep `programs.mango.enable = true;` (NixOS) for the session entry, and `wayland.windowManager.mango.package = null;` to reuse the same package (mixing versions breaks).

---

## 22. Ricing the ecosystem: bar, launcher, notifications, wallpaper, lock

### mangobar — the first-party bar

Built on wlr-layer-shell, talks IPC (tags/layouts/windows stay in sync). Modules: workspaces, layout, window title, keymode, keyboard layout, CPU/mem, brightness, volume, clock, network, battery, tray, and `custom/<name>` user modules.

- Arch: `yay -S mangobar-git`; source: `github.com/mangowm/mangobar` (meson build).
- Config: `$MANGOBAR_CONFIG` or `~/.config/mangobar/config.jsonc` + `style.css`.
- Start: `exec-once=mangobar`.

### Waybar (most riced)

Waybar has native **`mango/*` modules**:

```jsonc
{
  "modules-left": ["mango/workspaces", "mango/layout", "mango/window"],
  "modules-right": ["mango/language", "mango/keymode", "pulseaudio", "network", "clock"],
  "mango/workspaces": {
    "format": "{icon}",
    "hide-empty": true,
    "on-click": "activate",
    "on-click-right": "toggle",
    "overview-label": "OVERVIEW"
  },
  "mango/keymode": {
    "format": "{}",
    "format-default": "Default",   // per-mode: "format-<name>": "…"
    "format-resize": "Resize"
  },
  "mango/window":  { "format": "{}", "icon-size": 20 },
  "mango/layout": {
    "format": "{}",
    "format-S": "Scroller",        // per-layout single-letter overrides
    "format-T": "Tile"
  },
  "mango/language": { "format": "{short}" }   // "{short}" = abbreviated layout
}
```

style.css classes: `#workspaces button` states `.hidden .visible .active .urgent .overview`, plus `#window #layout #language #keymode`. `window#waybar.empty #window` zeroes the title module when nothing focused. Per-mode/per-layout `format-*` keys pick the string shown for that keymode/layout; `overview-label` is the workspaces button text shown while overview is open. Start with a dedicated config dir so it doesn't clash with other compositors' waybar:

```
exec-once=waybar -c ~/.config/mango/waybar/config.jsonc -s ~/.config/mango/waybar/style.css
```

Blur it: `blur_layer=1` + `layerrule=layer_name:waybar,...`. Reference config: DreamMaoMao/waybar-config.

### Launcher / notifications / wallpaper / lock / night light

- Launcher: rofi (default), wmenu (dmenu clone), fuzzel, bemenu — all work.
- Notifications: swaync (has a control center) / dunst / mako.
- Wallpaper: swaybg (static) or **swww** (animated transitions — the ricer pick) or mpvpaper (video).
- Lock: swaylock-effects (blurred screenshots) — docs' default; wlogout for the exit menu; dimland-git to dim idle screen.
- Night light: **wlsunset** or gammastep (Mango has no built-in equivalent).
- OSD: swayosd / wob for volume/brightness popups.
- Auth: xfce-polkit (docs) or polkit-gnome.

DreamMaoMao's own dependency list for the full experience:

```
rofi foot xdg-desktop-portal-wlr swaybg waybar wl-clip-persist cliphist wl-clipboard
wlsunset xfce-polkit swaync pamixer wlr-dpms sway-audio-idle-inhibit-git swayidle
dimland-git brightnessctl swayosd wlr-randr grim slurp satty swaylock-effects-git wlogout sox
```

And his full config: `git clone https://github.com/DreamMaoMao/mango-config.git ~/.config/mango`

### Shells that work with mango

DankMaterialShell (explicitly optimized for MangoWC) and Noctalia both run on wlroots compositors — full setup for both below. Note: Hyprland-specific shells (hyprlock/hypridle integrations, `hyprctl` hooks) don't apply — use `mmsg watch` instead.

---

## 23. Full desktop shells: DankMaterialShell & Noctalia on Mango

Both are **all-in-one shells** — one process replaces bar, launcher, notifications, control center, lock screen, idle manager, clipboard history, polkit agent, and wallpaper tool. Either one plus Mango is a complete desktop with nothing else to rice.

| | **DankMaterialShell (DMS)** | **Noctalia** |
|---|---|---|
| Stack | Quickshell (QML) + Go daemon (`dms`) | Native C++ (Wayland + OpenGL ES, no Qt/GTK) |
| Config | GUI settings + TOML/JSON in `~/.config/DankMaterialShell/` | TOML (`~/.config/noctalia/`) with hot reload + GUI overrides |
| IPC | `dms ipc call <target> <cmd>` | `noctalia msg <command>` |
| Mango support | First-class (MangoWC listed as "works best") | First-class (dedicated Mango backend) |
| Extras | matugen dynamic theming, plugin registry, `dgop` system monitoring | Plugin system, template-based app theming |
| NixOS | `programs.dms-shell` (nixpkgs) or flake | `noctalia` (nixpkgs unstable) or flake |

Key mental-model shift vs §22: with a shell you **delete** the waybar/rofi/dunst/swaylock/polkit lines from `exec-once` — the shell owns all of those surfaces itself.

### 23.1 DankMaterialShell on Mango

#### Install (NixOS)

```nix
# Native nixpkgs module (simplest):
programs.dms-shell = {
  enable = true;
  systemd = {
    enable = true;             # systemd user service auto-start (recommended)
    restartIfChanged = true;
  };
  # Feature toggles (each pulls its own deps):
  enableSystemMonitoring = true;   # dgop widgets
  enableDynamicTheming = true;    # matugen wallpaper-based theming
  enableCalendarEvents = true;
};

# Or via flake (fresher updates) — add input:
#   dms.url = "github:AvengeMedia/DankMaterialShell/stable";
# then: package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
```

The NixOS module installs DMS but does **not** write compositor config — deploy the Mango fragments with `dms setup` (see below), or write them by hand.

#### DMS-managed config fragments (the slick way)

DMS can generate `colors/layout/outputs` fragments that keep Mango's gaps, radius, and colors in sync with DMS's theme — customize them in **Settings → Compositor**:

```bash
# Add to the END of ~/.config/mango/config.conf:
source=~/.config/mango/dms/colors.conf
source=~/.config/mango/dms/layout.conf
source=~/.config/mango/dms/outputs.conf

# Create the files first (DMS fills them on reload):
mkdir -p ~/.config/mango/dms
touch ~/.config/mango/dms/{colors,layout,outputs}.conf
```

Note: mango's `source=` needs the files to exist or the config may fail to parse — the `touch` step matters.

#### Manual Mango-side config

```
# ~/.config/mango/config.conf — DMS integration

# Startup (skip if you use programs.dms-shell.systemd.enable):
exec-once=dms run
# Optional: persistent clipboard history
exec-once=wl-paste --type text --watch cliphist store

# Environment
env=QT_QPA_PLATFORM,wayland
env=ELECTRON_OZONE_PLATFORM_HINT,auto
env=QT_QPA_PLATFORMTHEME,gtk3

# Look DMS expects:
border_radius=12
borderpx=0
focused_opacity=1.0
unfocused_opacity=0.9
gappih=5
gappiv=5
gappoh=5
gappov=5
shadows=1
shadow_only_floating=1
shadows_size=10
shadows_blur=15

# DMS surfaces shouldn't animate as windows:
layerrule=noanim:1,layer_name:^dms

# DMS windows float:
windowrule=isfloating:1,appid:^com\.danklinux\.dms$
```

#### DMS keybinds (IPC)

```
# Launcher / clipboard / task manager / settings / notifications / wallpapers
bind=SUPER,space,spawn,dms ipc call spotlight toggle
bind=SUPER,v,spawn,dms ipc call clipboard toggle
bind=SUPER,m,spawn,dms ipc call processlist focusOrToggle
bind=SUPER,comma,spawn,dms ipc call settings focusOrToggle
bind=SUPER,n,spawn,dms ipc call notifications toggle
bind=SUPER,y,spawn,dms ipc call dankdash wallpaper
# Lock screen
bind=SUPER+ALT,l,spawn,dms ipc call lock lock
# Media keys (work while locked with bindl):
bindl=NONE,XF86AudioRaiseVolume,spawn,dms ipc call audio increment 3
bindl=NONE,XF86AudioLowerVolume,spawn,dms ipc call audio decrement 3
bindl=NONE,XF86AudioMute,spawn,dms ipc call audio mute
bindl=NONE,XF86MonBrightnessUp,spawn,dms ipc call brightness increment 5
bindl=NONE,XF86MonBrightnessDown,spawn,dms ipc call brightness decrement 5
```

Other useful IPC targets: `dms ipc call wallpaper set /path/img.jpg`, `dms plugins search`, `dms brightness list`. Full list: danklinux.com/docs/dankmaterialshell/keybinds-ipc.

#### NixOS gotchas

- Lock-screen auth: DMS validates against `/etc/pam.d/login` by default — declare `security.pam.services.dankshell` only to customize the password stack; for FIDO2 keys declare the dedicated key-only `security.pam.services."dankshell-u2f"` (bundled fallback can't load `pam_u2f` on NixOS). Flake-module equivalent: `programs.dank-material-shell.lockscreen.securityKey.enable = true` (see danklinux.com/docs/dankmaterialshell/lock-screen-authentication).
- Deploy compositor fragments with `dms setup`, `dms setup binds`, `dms setup colors`, `dms setup layout` — plus Mango extras `dms setup windowrules` (DMS floating rule → `~/.config/mango/dms/windowrules.conf`, app-id `com.danklinux.dms`), `dms setup cursor`, and niri-only `dms setup alttab`. HM users: generate only the pieces you need so `dms setup` doesn't fight declarative config.
- Discover/install plugins: `dms plugins search` (registry at plugins.danklinux.com), `dms plugins lock --output FILE` / `dms plugins restore FILE [--prune]` to pin exact commits; per-layer blur targets are the `dms:*` namespaces (`dms:bar`, `dms:spotlight`, `dms:control-center`, …) — on Mango collapse them to `layerrule=noanim:1,layer_name:^dms`.
- The old DMS app-id `org.quickshell` was replaced by `com.danklinux.dms` — update any hand-written windowrules.

### 23.2 Noctalia on Mango

#### Install (NixOS)

Noctalia v5 is in nixpkgs unstable (`pkgs.noctalia`), or via flake for the latest git:

```nix
# flake.nix input (omit follows to keep the binary cache usable):
noctalia = {
  url = "github:noctalia-dev/noctalia";           # or /cachix for guaranteed cache hits
  # inputs.nixpkgs.follows = "nixpkgs";            # optional — disables cache
};

# configuration.nix — NixOS module (installs system-wide + recommended services):
programs.noctalia = {
  enable = true;
  recommendedServices.enable = true;   # NetworkManager, Bluetooth, UPower, power-profiles
};

# Or Home Manager module (configure Noctalia's TOML from nix — `inputs.noctalia.homeModules.default`):
programs.noctalia = {
  enable = true;
  settings = {                          # attrs, or a path/string to a .toml file
    theme = { mode = "dark"; source = "builtin"; builtin = "Catppuccin"; };
    wallpaper = {
      enabled = true;
      default.path = "/path/to/wallpaper.png";
    };
  };
  systemd.enable = true;                # user service; then set launch_apps_as_systemd_services so
  launch_apps_as_systemd_services = true; # Noctalia-launched apps survive shell restarts
};
# Binary cache (skip local builds; omit `inputs.nixpkgs.follows` or the hash changes and cache misses):
nix.settings = {
  extra-substituters = [ "https://noctalia.cachix.org" ];
  extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
};
```

Mango's needs (if not already on): `networking.networkmanager.enable`, `hardware.bluetooth.enable`, `services.upower.enable`, and `services.power-profiles-daemon.enable` (or `services.tuned.enable`). Module choice: NixOS module = `inputs.noctalia.nixosModules.default` (system-wide + `recommendedServices.enable` for the four above); HM module = `inputs.noctalia.homeModules.default` (`programs.noctalia.settings`); pin the `cachix` branch (`noctalia.url = "github:noctalia-dev/noctalia/cachix"`) to guarantee cache hits instead of tracking an uncached `main` commit.

#### Mango-side config (from Noctalia's Mango guide)

```
# ~/.config/mango/config.conf

# Startup:
exec-once=noctalia
# (or the systemd user service: programs.noctalia.systemd.enable = true;
#  then also enable launch_apps_as_systemd_services)

# Blur/shadows — SceneFX layer blur doesn't filter by surface opacity, so
# transparent Noctalia surfaces get compositor blur. For the cleanest look:
# window blur ON, LAYER blur/shadows OFF, Noctalia draws its own shadows.
blur=1
blur_layer=0
blur_optimized=1
blur_params_num_passes=2
blur_params_radius=5
blur_params_noise=0.02
blur_params_brightness=0.9
blur_params_contrast=0.9
blur_params_saturation=1.0
layer_animations=0
shadows=1
layer_shadows=0
shadow_only_floating=0
shadows_size=4
shadows_blur=12
shadows_position_x=2
shadows_position_y=2
shadowscolor=0x000000ff
```

Then in `~/.config/noctalia/config.toml`, disable Noctalia's rendered drop shadows (else you get double shadows):

```toml
[bar.default]
shadow = false
contact_shadow = false

[dock]
shadow = false

[shell.panel]
shadow = false
# more than one bar? set shadow=false on each [bar.<name>] too
```

#### Noctalia keybinds (IPC)

```
# Core binds
bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
bind=SUPER,s,spawn,noctalia msg panel-toggle control-center
bind=SUPER,comma,spawn,noctalia msg settings-toggle
# Media keys
bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down
```

Full IPC reference: docs.noctalia.dev/noctalia/ipc (shell, surfaces, media & UI, plugins, system controls).

### 23.3 Choosing between them / running both?

- **DMS** if you want matugen **Material You** dynamic theming from your wallpaper (it themes GTK/Qt/terminals/editors automatically) and a Go-powered system dashboard (`dgop` — the same engine behind the `dgop`/`bt`-style monitors).
- **Noctalia** if you want a **non-Qt**, native binary that sips resources, TOML hot-reload config, and deep template-based app theming (Firefox, VSCode, Steam, Discord templates).
- They can technically run at the same time but will fight over layer-shell bar/lock/notification surfaces and both would grab SNI tray / notification daemons — pick one as *the* shell. If you miss a single piece from the other (e.g. just Noctalia's dock), run the other app piecemeal instead of the whole shell.
- Workspaces: both shells read Mango's tags for their workspace widgets — Noctalia via its compositor-native Mango backend, DMS via Mango's workspace/IPC integration. If tag widgets misbehave, first check `mmsg get all-tags` still reports correctly.

---

## 24. Vendor GPUs, NVIDIA / gaming: tearing & syncobj

### NVIDIA (proprietary)

```
# NixOS: proprietary driver + EGL on Wayland
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;
  open = false;                       # proprietary kernel module (nvkms); `true` = open flavor, worse Wayland compat on some cards
};
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [ nvidia-vaapi-driver libvdpau-va-gl ];
};
environment.sessionVariables = {
  LIBVA_DRIVER_NAME = "nvidia";
  __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  NVD_BACKEND = "direct";             # vaapi <-> NVDEC bridge
};
```

Mango side: `syncobj_enable=1`, `allow_tearing=2`, per-game `windowrule=force_tearing:1,...`, and on many cards `env=WLR_DRM_NO_ATOMIC,1` before mango starts (atomic modesetting + proprietary EGL quirks break tearing/present otherwise). Multi-GPU black screen? Pin with `WLR_DRM_DEVICES=/dev/dri/card1 mango` (`card0:card1` for both).

### AMD (RX / RDNA / APUs)

```
services.xserver.videoDrivers = [ "amdgpu" ];
boot.initrd.kernelModules = [ "amdgpu" ];
hardware.graphics.enable = true;      # mesa RADV/ACO
```

Mango side: VRR (`vrr:1` in monitorrule) and HDR just work; tearing rarely needs `WLR_DRM_NO_ATOMIC`; `syncobj_enable=1` safe. This is the least-friction vendor on Mango.

### Intel (iGPU hosts / Arc dGPU)

```
services.xserver.videoDrivers = [ "modesetting" ];
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [ intel-media-driver intel-vaapi-driver ];
};
# optional GuC/HuC firmware offload: boot.kernelParams = [ "i915.enable_guc=2" ];  # pre-Meteor Lake
```

Mango side: usually hosts the Wayland session while NVIDIA/AMD renders offload — keep `blur_optimized=1` + `shadow_only_floating=1` to stay in iGPU budget; HDR/VRR per monitorrule as panels allow.

Which mango settings differ per vendor: **tearing** (NVIDIA almost always wants `WLR_DRM_NO_ATOMIC,1`; AMD/Intel usually don't), **vrr** (AMD primarily; NVIDIA VRR is panel/driver-lottery), **hdr_depth/mastering** (needs `WLR_RENDERER=vulkan`, §4 — vendor-agnostic but NVIDIA VA-API path needs `nvidia-vaapi-driver`), **blur_optimized** (keep 1 everywhere; only NVIDIA dGPU rigs can afford `blur_optimized=0` + multi-pass blur at high refresh).

```
syncobj_enable=1            # explicit sync — fixes most game stutter; needs compositor restart
allow_tearing=2             # 0 off / 1 on / 2 fullscreen-only
windowrule=force_tearing:1,title:Counter-Strike 2
```

- Some GPUs need `env=WLR_DRM_NO_ATOMIC,1` **before mango starts** for tearing to function. Same var fixes `kitty`-style crashes when `syncobj_enable=1` misbehaves on a given GPU.
- `vrr:1` in monitorrule per-output; `vrr_only_fullscreen:1` window rule keeps VRR for games only (turn `vrr` to 0 in the monitor rule first).
- Sunshine streaming: `create_virtual_output` / `destroy_all_virtual_output` dispatchers.
- `xwayland_persistence=1` keeps X11 games' server warm.

### CPU note (AMD/Intel): Mango is light

Mango sips CPU — no scheduler pinning, no core-count tuning needed, even on low-core APUs. The only knobs that matter on weak silicon: keep `xwayland_persistence=1` (avoids Xwayland cold-start jank) and leave `drag_tile_refresh_interval` / `drag_floating_refresh_interval` at 8.0 (lower = laggier apps during drag-resize, §17). If the iGPU struggles, cut `blur_params_num_passes` to 1 and `animations` durations before touching anything else.

---

## 25. FAQ / troubleshooting

**Mouse-arrange tiled windows?** `drag_tile_to_tile=1`.

**Blur looks wrong / blurry bg?** It blurs transparent window areas; disable with `blur=0`. Perf: keep `blur_optimized=1`.

**Blur shows wallpaper, not real background content?** Expected with `blur_optimized=1` (cached wallpaper backdrop). `blur_optimized=0` for true composition (heavier GPU).

**Games lag/stutter?** `syncobj_enable=1`.

**Games high input latency?** `allow_tearing=1` + `windowrule=force_tearing:1,...` (+ `WLR_DRM_NO_ATOMIC` if needed).

**Pipes in spawn?** `spawn` doesn't do shell pipes — use `spawn_shell`:

```
bind=SUPER,P,spawn_shell,echo "hello" | rofi -dmenu
```

**Key combos dead on my layout?** bind does keysym→keycode conversion; fall back to keycodes from `wev` (`bind=ALT,code:24,...`) or keysym mode (`binds=`).

**Stuck in a keymode?** `mmsg dispatch setkeymode,default` (from another TTY).

**Config typo?** `mango -c config.conf -p` parses without launching.

**Reload didn't apply?** `env=` lines reset every reload; some input settings need relogin; syncobj needs restart.

**Xwayland apps mis-click on multi-monitor?** Negative coordinates — rearrange from 0,0 positive.

---

## 26. Community configs to steal from

- **DreamMaoMao/mango-config** — the author's own rice (waybar + rofi + swaync + satty + wlogout). Best starting point.
- **lingllqs/dotfiles** — Arch mangowc + Lua-adjacent utility configs.
- **KozmunkasKalman/mangowc-rice** — shell-heavy rice.
- **So1d/matugen-mangowc-dots** — matugen (Material You) theming for mango — pairs perfectly with §14 colors.
- **tonybanters/mangowc-btw** — Tony's setup (companion to his tutorial: tonybtw.com/tutorial/mangowc).
- **Gur0v/mangobar** (archived) — a suckless-style bar for mangowc.
- **evoziosk/caelestia-shell-mango** — Caelestia shell ported to mango (WIP) — proof the Quickshell shell ecosystem fits.
- **AvengeMedia/DankMaterialShell** — explicitly optimized for MangoWC.

Docs: <https://mangowm.github.io> (configuration/visuals/bindings/IPC/nix-options), GitHub wiki (community), Discord: <https://discord.gg/CPjbDxesh5>.

---

*Companion docs: `HYPRLAND-NIXOS-LUA-GUIDE.md` (main Hyprland rice), `TIDE-ISLAND-NIXOS-GUIDE.md` (Dynamic Island widget for Hyprland).*
