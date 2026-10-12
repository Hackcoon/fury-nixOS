# MangoWC / MangoWM — Comprehensive Hotkeys & Bindings Guide

> **Note:** This project was renamed from **MangoWC** to **MangoWM** (repo moved `DreamMaoMao/mangowc` → `mangowm/mango`). Same maintainer, same compositor — most people still call it "mango" or "mangowc" out of habit. This guide uses current upstream naming.

MangoWM is a dwl-derived, wlroots/SceneFX-based Wayland compositor — think **dwm, but Wayland**. Everything below is configured in text, not source code.

> **Note for an agent using this file:** MangoWM/MangoWC ships breaking changes almost every release. Before relying on any option name here, verify against the live install: `mango -c /path/to/config.conf -p` validates config syntax, `mmsg get ...` / `mmsg watch ...` dumps current compositor state, `mmsg dispatch ...` triggers an action, and for DMS specifically `dms ipc list` prints every valid IPC target/function for the installed version. Treat those three commands as more authoritative than this document if anything conflicts. Also note `MANGOCONFIG` was removed in v0.10.7 — use `mango -c <path>` instead if you see it referenced.

- Main config: `~/.config/mango/config.conf`
- Fallback/system default: `/etc/mango/config.conf` (copy it to get started)
- Autostart script: `~/.config/mango/autostart.sh`
- Custom config location: `mango -c /path/to/config.conf` (the older `MANGOCONFIG` env var was removed in v0.10.7 — don't use it on current versions)
- Some setups split config into `config.d/` files (e.g. `30-keybinds.conf`, `40-mousebinds.conf`) using `source=` — check your distro's layout.

---

## 1. Binding Syntax

### Keyboard binds
```
bind=<MODIFIERS>,<KEY>,<COMMAND>,<PARAMETERS>
bind[flags]=MODIFIERS,KEY,COMMAND,PARAMETERS
```
- `MODIFIERS`: `SUPER`, `CTRL`, `ALT`, `SHIFT`, `NONE` — combine with `+` (e.g. `SUPER+SHIFT`)
- `KEY`: key name (from `xev` or `wev`), or `code:<keycode>` for layout-independent binds. Prefix with `binds=` for keysym-mode matching instead of keycode matching.
- Flags (append to `bind`, combinable — e.g. `bindl=`, `bindsr=`): `l` = fire even when screen locked, `s` = keysym match, `r` = trigger on release, `p` = pass key through to client too, `c` = allow conflict (must be set on *all* conflicting binds).
- Example keycode binds:
  ```
  bind=ALT,code:24,killclient,
  bind=code:64+code:133,code:24,killclient,
  ```

### Mouse binds
```
mousebind=<MODIFIERS>,<BUTTON>,<COMMAND>,<PARAMETERS>
```
- `BUTTON`: `btn_left`, `btn_right`, `btn_middle`, plus `btn_side`, `btn_extra`, `btn_forward`, `btn_back`, `btn_task` — or `code:<NUMBER>` (e.g. `code:272`) for non-standard buttons.
- The moveresize pair is the standard drag binding: `moveresize,curmove` (drag window) / `moveresize,curresize` (drag resize).
- Note: with `NONE` as modifier, only the middle button works in normal mode; left/right with `NONE` only work in **overview mode**.

### Scroll wheel binds
```
axisbind=<MODIFIERS>,<UP/DOWN/LEFT/RIGHT>,<COMMAND>,<PARAMETERS>
```

### Touchpad gesture binds
```
gesturebind=<MODIFIERS>,<up/down/left/right>,<FINGERS 3|4>,<COMMAND>,<PARAMETERS>
```
- 3-finger = window focus, 4-finger = tags/overview by convention (see §4). `gesture_live=1` shows a live preview while dragging for `viewprev_have_client` / `viewnext_have_client` / `toggleoverview`; `0` acts on release only.

### Lid-switch binds
```
switchbind=<fold/unfold>,<COMMAND>,<PARAMETERS>
```
- `fold` = lid closed, `unfold` = lid opened. Disable systemd lid handling first (`HandleLidSwitch=ignore`, `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore` in `/etc/systemd/logind.conf`), e.g.:
  ```
  switchbind=fold,spawn,swaylock -f -c 000000
  switchbind=unfold,spawn,wlr-dpms on
  ```

### Key Modes (submaps, like Hyprland "modes")
```
keymode=common          # binds here apply in EVERY mode
bind=SUPER,r,reload_config

keymode=default          # normal binds (implicit if no keymode set)
bind=SUPER,F,setkeymode,resize

keymode=resize
bind=NONE,Left,resizewin,-10,0
bind=NONE,Right,resizewin,+10,0
bind=NONE,Escape,setkeymode,default
```
Switch modes with `setkeymode`, query the current one with `mmsg get keymode`.

---

## 2. Default Keybindings (stock config)

| Keys | Action |
|---|---|
| `Alt + Return` | Open terminal (foot by default) |
| `Alt + Space` | Open launcher (rofi by default) |
| `Alt + Q` | Kill focused window |
| `Super + M` | Quit MangoWC |
| `Super + F` | Toggle fullscreen |
| `Alt + Arrow keys` | Move focus (left/right/up/down) |
| `Ctrl + 1–9` | Switch to tag 1–9 |
| `Alt + 1–9` | Move focused window to tag 1–9 |
| `Super + Return` | Open terminal (some flavored configs) |
| `Super + Shift + Return` | Open floating terminal |
| `Super + Alt + Return` | Open fullscreen terminal |
| `Super + Shift + F/E/W` | File manager / text editor / browser (if present in your config) |
| `Print` / `Alt+Print` / `Shift+Print` / `Ctrl+Print` | Screenshot / 5s delay / 10s delay / region |

⚠️ These vary by distro/config flavor (Arch/Archcraft rices differ from upstream `mangowm.github.io` defaults). **Always check your own `~/.config/mango/config.conf`** — this is a starting point, not gospel.

---

## 3. Full Command Reference (usable in `bind=`)

| Command | Parameters | Description |
|---|---|---|
| `reload_config` | – | Reload config file |
| `load_config_file` | file path (empty = reset to default) | Load config from a specific file |
| `spawn` | command | Run a shell command (no pipes — use `spawn_shell` for those) |
| `spawn_shell` | shell cmd (pipes/`\|` OK, runs via `/bin/sh -c`) | Run through a shell, e.g. `ps aux \| grep mango \| rofi -dmenu` |
| `spawn_on_empty` | command,tagnumber | Open on an empty tag, or focus if already running |
| `quit` | – | Quit MangoWC |
| `killclient` | – (or `force` = SIGKILL) | Close focused window |
| `focuslast` | – | Focus previously focused window |
| `focusid` | client id (via `mmsg dispatch focusid client,<id>`) | Focus any window by id |
| `focus_window_or_workspace` | left/right/up/down | Focus window in direction, else jump to nearest adjacent tag with clients |
| `overcircle` | next/prev/current_next/current_prev | Open overview if closed; while open, cycle focus (`current_*` = current tagset only) |
| `switcher` | next/prev, all_tag_next/all_tag_prev, all_next/all_prev | Thumbnail switcher (current tag / monitor tags / all); releasing modifiers selects |
| `focusstack` | next/prev | Cycle focus through stack |
| `focusdir` | left/right/up/down | Directional focus |
| `exchange_client` | left/right/up/down | Swap window positions |
| `exchange_stack_client` | next/prev | Exchange window position in stack |
| `toggleglobal` | – | Toggle "global" window state |
| `toggleoverview` | – | Toggle overview mode |
| `togglefloating` | – | Toggle floating state |
| `toggle_all_floating` | – | Toggle floating on all visible clients |
| `toggleoverlay` | – | Toggle always-on-top overlay state |
| `togglemaximizescreen` | – | Toggle maximize |
| `togglefullscreen` | – | Toggle fullscreen |
| `togglefakefullscreen` | – | Toggle fake fullscreen (no compositor-level fullscreen) |
| `centerwin` | – | Center floating window (scroller: center tiled window; no-op on fullscreen/maximized) |
| `minimized` | – | Minimize window |
| `restore_minimized` | – | Restore minimized window |
| `toggle_special_tag` | – | Toggle special-workspace overlay (tiling scratchpad) |
| `tag_special_tag` | – | Move focused window to/from the special workspace |
| `tag_special_silent` | – | Same, without focusing it |
| `toggle_render_border` | – | Toggle border rendering |
| `toggle_scratchpad` | – | Toggle scratchpad |
| `toggle_named_scratchpad` | appid,title,cmd | Toggle a named scratchpad |
| `set_proportion` | float 0.0–1.0 | Set scroller layout window proportion |
| `switch_proportion_preset` | – | Cycle scroller proportion presets |
| `scroller_stack` | left/right/up/down | Move window inside/outside the scroller stack by direction |
| `dwindle_toggle_split_direction` | – | Toggle split direction in dwindle layout |
| `dwindle_split_horizontal` / `dwindle_split_vertical` | – | Force dwindle split direction |
| `dwindle_toggle_current_split` | – | Toggle split direction of current dwindle window |
| `incnmaster` | +1/-1 | Change number of master windows |
| `setmfact` | +val/-val | Adjust master area size (use for master factor; scroller uses `set_proportion` / `switch_proportion_preset`) |
| `zoom` | – | Swap focused window with master |
| `setlayout` | layout_name | Set a specific layout |
| `switch_layout` | – | Cycle through layouts |
| `view` | mask[,synctag] (e.g. `1`, `1\|3\|5`; `0`=all, `-1`=prev) | View tag(s). Tag mask = `1`–`9` joined by `\|` |
| `viewtoleft` / `viewtoright` | [synctag] | Previous / next tag |
| `view_insert` | prev/next | Adjacent tag if empty, else insert an empty tag before/after and switch to it |
| `viewtoleft_have_client` / `viewtoright_have_client` | [synctag] | Prev/next tag, focus client if present (the `axisbind` pair in §4) |
| `viewprev_have_client` / `viewnext_have_client` | – | Same, for `gesturebind` drag previews with `gesture_live=1` |
| `viewcrossmon` | mask,monitor_spec | View tag(s) on a specific monitor |
| `comboview` | mask | View multiple tags simultaneously |
| `tag` | mask[,synctag] (e.g. `1`, `1\|3\|5`) | Move focused window to tag(s) |
| `tagsilent` | mask | Move window without focusing it |
| `tagtoleft` / `tagtoright` | [synctag] | Move window to left / right tag |
| `tagcrossmon` | mask,monitor_spec | Move window to tag(s) on a specific monitor |
| `toggletag` | mask (`0` toggles all tags) | Toggle tag(s) on the window |
| `toggleview` | mask | Toggle tag(s) visibility |
| `focusmon` | left/right/up/down/monitor_spec | Focus a monitor |
| `tagmon` | left/right/up/down/monitor_spec[,keeptag 0/1] | Move window to a monitor |
| `incgaps` | +val/-val | Adjust gap size |
| `togglegaps` | – | Toggle gaps on/off |
| `smartmovewin` | left/right/up/down | Move window an "auto" distance |
| `smartresizewin` | left/right/up/down | Resize window by "auto" amount |
| `movewin` | x,y | Move window by offset |
| `resizewin` | width,height | Resize window (works on tiled too, except grid/monocle) |
| `create_virtual_output` | – | Create a virtual monitor |
| `destroy_all_virtual_output` | – | Destroy all virtual monitors |
| `toggleoverview` | – (or `1` = current tagset only) | Toggle overview mode |
| `enteroverview` / `leaveoverview` | – | Enter / leave overview explicitly (for scripts/modes) |
| `togglejump` | – | Toggle overview with jump mode |
| `toggle_trackpad_enable` | – | Toggle trackpad on/off |
| `setoption` | key,value | Set a config option temporarily (no file write) |
| `sleep_monitor` / `wakeup_monitor` / `sleep_toggle_monitor` | monitor_spec | Power a monitor off / on / toggle (stays configured) |
| `disable_monitor` / `enable_monitor` / `toggle_monitor` | monitor_spec | Remove / add / toggle a monitor |
| `moveresize` | curmove/curresize | Mouse drag move / resize (the `mousebind` pair in §4) |
| `increase_proportion` | float -1→1 | Change scroller proportion incrementally |
| `switch_keyboard_layout` | – | Cycle keyboard layouts |

---

## 4. Example Keybind Block

```ini
# --- Core ---
bind=SUPER,Return,spawn,foot
bind=SUPER,Space,spawn,rofi -show drun
bind=SUPER,Q,killclient
bind=SUPER+SHIFT,M,quit
bind=SUPER,R,reload_config

# --- Focus / Layout ---
bind=SUPER,J,focusstack,next
bind=SUPER,K,focusstack,prev
bind=SUPER,Left,focusdir,left
bind=SUPER,Right,focusdir,right
bind=SUPER,Up,focusdir,up
bind=SUPER,Down,focusdir,down
bind=SUPER,I,incnmaster,+1
bind=SUPER,D,incnmaster,-1
bind=SUPER,H,setmfact,-10
bind=SUPER,L,setmfact,+10
bind=SUPER,T,setlayout,tile
bind=SUPER,Y,setlayout,scroller
bind=SUPER,Tab,switch_layout

# --- Window state ---
bind=SUPER,Space,togglefloating
bind=SUPER,M,togglemaximizescreen
bind=SUPER,F,togglefullscreen
bind=SUPER,O,toggleoverview

# --- Tags ---
bind=SUPER,1,view,1
bind=SUPER,2,view,2
bind=SUPER+SHIFT,1,tag,1
bind=SUPER+SHIFT,2,tag,2

# --- Mouse ---
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize
mousebind=SUPER+CTRL,btn_right,killclient
mousebind=NONE,btn_middle,togglemaximizescreen,0

# --- Scroll ---
axisbind=SUPER,UP,viewtoleft_have_client
axisbind=SUPER,DOWN,viewtoright_have_client

# --- Gestures ---
gesturebind=none,left,3,focusdir,left
gesturebind=none,right,3,focusdir,right
gesturebind=none,up,4,toggleoverview
```

---

## 5. Scratchpad Bindings

```ini
# Sway-style scratchpad
bind=SUPER,I,minimized
bind=ALT,z,toggle_scratchpad
bind=SUPER+SHIFT,I,restore_minimized

# Named scratchpad (dropdown terminal, file manager, etc.)
bind=alt,h,toggle_named_scratchpad,st-yazi,none,1280,800,st -c st-yazi -e yazi
windowrule=isnamedscratchpad:1,width:1280,height:800,appid:st-yazi
```

---

## 6. IPC (mmsg)

You can trigger any bind-able action externally, e.g. from a script or status bar:
```bash
mmsg -g                   # get compositor state
mmsg -d reload_config      # reload config
mmsg -d quit                # quit mango
```

---

## 7. Your Drag-to-Float Question

By default (`drag_tile_to_tile=0`), dragging a tiled window with `Super+LeftClick` pops it into floating mode instead of repositioning it within the layout. This is confirmed straight from the official FAQ:

> "How do I arrange tiled windows with my mouse? You can enable the `drag_tile_to_tile` option in your config. This allows you to drag a tiled window onto another to swap them."

Fix — add to `~/.config/mango/config.conf` and reload (`Super+R` or `mmsg -d reload_config`):
```ini
drag_tile_to_tile=1
```

Two related options worth knowing about:

| Setting | Default | Description |
|---|---|---|
| `drag_tile_to_tile` | 0 | Dragging a tiled window onto another swaps their tiled positions instead of floating it |
| `drag_tile_small` | 1 | While dragging, the tiled window temporarily shrinks (visual feedback during the drag) |
| `drag_corner` | 3 | Which corner is used for drag-to-tile drop detection (0–3 = specific corner, 4 = auto-detect) |
| `drag_warp_cursor` | 1 | Warp the cursor to match when drag-to-tiling |

## 8. Supported Layouts (current)

`tile`, `scroller`, `monocle`, `grid`, `deck`, `center_tile`, `vertical_tile`, `right_tile`, `vertical_scroller`, `vertical_grid`, `vertical_deck`, `dwindle`

(older versions also had `spiral`, which was removed in v0.10.0 — if you see configs referencing it, they're outdated.)

## 9. DMS (DankMaterialShell) Integration

DankMaterialShell (DMS) is a Quickshell+Go desktop shell (replaces waybar/swaylock/swayidle/mako/fuzzel/polkit) with **official first-class MangoWC support**. Config lives at `~/.config/mango/config.conf`; DMS ships pre-made fragments you `source=`.

### 9.1 Install
```bash
curl -fsSL https://install.danklinux.com | sh
# or: paru -S dms-shell-git   (AUR)   /   sudo dnf install dms   (Fedora COPR)
```

### 9.2 Wire DMS's generated config fragments into MangoWC
```bash
mkdir -p ~/.config/mango/dms
touch ~/.config/mango/dms/{colors,layout,outputs}.conf
```
Add to the **end** of `~/.config/mango/config.conf`:
```ini
source=~/.config/mango/dms/colors.conf
source=~/.config/mango/dms/layout.conf
source=~/.config/mango/dms/outputs.conf
```
These are managed/overwritten by DMS itself (Settings → Compositor lets you tweak gaps/radius/colors from the GUI and it rewrites these files).

### 9.3 Autostart DMS
Preferred (systemd user service):
```bash
systemctl --user enable --now dms
```
Or directly in config, no systemd:
```ini
exec-once=dms run
exec-once=wl-paste --type text --watch cliphist store   # optional clipboard history
```

### 9.4 Recommended environment variables
```ini
env=QT_QPA_PLATFORM,wayland
env=ELECTRON_OZONE_PLATFORM_HINT,auto
env=QT_QPA_PLATFORMTHEME,gtk3
```

### 9.5 Recommended appearance settings (matches DMS's Material 3 look)
```ini
border_radius=12
borderpx=0
focused_opacity=1.0
unfocused_opacity=0.9

gappih=5
gappiv=5
gappoh=5
gappov=5

# optional shadows
shadows=1
shadow_only_floating=1
shadows_size=10
shadows_blur=15
```

### 9.6 Layer rule (stop DMS panels from animating oddly)
```ini
layerrule=noanim:1,layer_name:^dms
```

### 9.7 Window rules
```ini
# GNOME apps — no border
windowrule=isnoborder:1,appid:^org\.gnome\.
# Common terminals — no border
windowrule=isnoborder:1,appid:^org\.wezfurlong\.wezterm$
windowrule=isnoborder:1,appid:^Alacritty$
windowrule=isnoborder:1,appid:^com\.mitchellh\.ghostty$
windowrule=isnoborder:1,appid:^kitty$
# Float DMS's own popup windows (spotlight, notepad, etc.)
windowrule=isfloating:1,appid:^org\.quickshell$
```

### 9.8 DMS keybindings (in MangoWC bind= syntax)
Every DMS feature is controlled via `dms ipc call <target> <function> [params]`. Bind them with MangoWC's `spawn` command:
```ini
# --- Application Launchers / Panels ---
bind=SUPER,space,spawn,dms ipc call spotlight toggle
bind=SUPER,v,spawn,dms ipc call clipboard toggle
bind=SUPER,m,spawn,dms ipc call processlist focusOrToggle
bind=SUPER,comma,spawn,dms ipc call settings focusOrToggle
bind=SUPER,n,spawn,dms ipc call notifications toggle
bind=SUPER,y,spawn,dms ipc call dankdash wallpaper

# --- Security ---
bind=SUPER+ALT,l,spawn,dms ipc call lock lock

# --- Audio ---
bind=NONE,XF86AudioRaiseVolume,spawn,dms ipc call audio increment 3
bind=NONE,XF86AudioLowerVolume,spawn,dms ipc call audio decrement 3
bind=NONE,XF86AudioMute,spawn,dms ipc call audio mute
bind=NONE,XF86AudioMicMute,spawn,dms ipc call mic mute

# --- Brightness ---
bind=NONE,XF86MonBrightnessUp,spawn,dms ipc call brightness increment 5
bind=NONE,XF86MonBrightnessDown,spawn,dms ipc call brightness decrement 5

# --- Media / Night / Inhibit ---
bind=NONE,XF86AudioPlay,spawn,dms ipc call mpris playPause
bind=NONE,XF86AudioNext,spawn,dms ipc call mpris next
bind=NONE,XF86AudioPrev,spawn,dms ipc call mpris previous
bind=SUPER,i,spawn,dms ipc call inhibit toggle
bind=SUPER+SHIFT,n,spawn,dms ipc call night toggle

# --- Shell chrome (bar / island / dock / widgets / outputs) ---
bind=SUPER,b,spawn,dms ipc call bar toggle index 0
bind=SUPER,d,spawn,dms ipc call dock toggle
bind=SUPER+SHIFT,d,spawn,dms ipc call dash toggle overview
bind=SUPER,slash,spawn,dms ipc call island toggle home
bind=SUPER,o,spawn,dms ipc call outputs cycleProfile
bind=SUPER,k,spawn,dms ipc call keybinds toggle mangowc
```

### 9.9 Full IPC command reference (targets you can bind to anything)

| Target | Example functions | Example |
|---|---|---|
| `spotlight` | toggle | `dms ipc call spotlight toggle` (app launcher) |
| `clipboard` | toggle | `dms ipc call clipboard toggle` |
| `processlist` | focusOrToggle | `dms ipc call processlist focusOrToggle` (task manager) |
| `settings` | focusOrToggle | `dms ipc call settings focusOrToggle` |
| `notifications` | toggle, dismiss | `dms ipc call notifications toggle` |
| `dankdash` | wallpaper | `dms ipc call dankdash wallpaper` |
| `lock` | lock, lockAndOutputsOff, isLocked | `dms ipc call lock lock` |
| `audio` | setvolume N, increment N, decrement N, mute | `dms ipc call audio setvolume 50` |
| `mic` | setvolume N, increment N, decrement N, mute, status | `dms ipc call mic mute` (separate from `audio micmute` legacy) |
| `night` | toggle, enable, disable, status, gamma [v], contrast [v], setTargetTemp K, setDayTemp K, automation [manual/time/location] | `dms ipc call night toggle` |
| `inhibit` | toggle, enable, disable, status, reason [text] | `dms ipc call inhibit toggle` (idle-inhibit, survives restart) |
| `bar` | reveal/hide/toggle/status/autoHide/manualHide/toggleAutoHide/toggleReveal/getPosition/setPosition `<selector> <value>` | `dms ipc call bar toggle index 0` (selectors: `index`/`id`/`name`) |
| `island` | open/toggle/show/close/cycle/status/notifications `<activity>` (`home`, `media`, `launcher`, `controlcenter`, `wallpaper`, `weather`) | `dms ipc call island toggle home` |
| `dock` | reveal, hide, toggle, status, autoHide, manualHide, toggleAutoHide | `dms ipc call dock toggle` |
| `widget` | list, toggle `<id>`, openWith/toggleWith `<id> <mode>`, status `<id>`, reveal/hide/reset `<id>` | `dms ipc call widget toggle clock` |
| `outputs` | listProfiles, current, setProfile `<name>`, cycleProfile, status, refresh | `dms ipc call outputs cycleProfile` (niri/Hypr/Mango only) |
| `brightness` | set N, increment N, decrement N | `dms ipc call brightness set 70` |
| `mpris` | play, pause, playPause, previous, next, stop, list | `dms ipc call mpris playPause` |
| `powerprofile` | status, list, cycle, set <name> | `dms ipc call powerprofile set balanced` |
| `theme` | settargetdark, settargetlight | `dms ipc call theme settargetdark` |
| `sessions` | list, open, switchTo <user>, activate <id> | `dms ipc call sessions switchTo bob` |
| `wallpaper` | set <path> | `dms ipc call wallpaper set /path/to/image.jpg` |
| `keybinds` | toggle <provider> | `dms ipc call keybinds toggle mangowc` |

**Live discovery** (authoritative, run while DMS is running):
```bash
dms ipc list      # every available target + function on YOUR installed version
dms ipc --help
```

### 9.10 Bonus: built-in MangoWC cheatsheet
DMS ships a keybind cheatsheet viewer that already knows MangoWC:
```bash
dms keybinds list            # all providers + custom cheatsheets in ~/.config/DankMaterialShell/cheatsheets/
dms keybinds show mangowc    # render the MangoWC cheatsheet offline
# or, overlay it inside the shell itself:
dms ipc call keybinds toggle mangowc
dms ipc call keybinds open mangowc            # same, explicit open
dms ipc call keybinds toggleWithPath mangowc ~/.config/mango/config.conf
```

### 9.11 Diagnostics
```bash
dms doctor        # checks compositor detection, services, config dirs (also: Settings → About → Tools → System Check)
dms ipc list      # authoritative target/function list for YOUR running version
pgrep -f "dms run"   # confirm DMS is actually running
```


