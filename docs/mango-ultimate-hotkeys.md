# Mango Ultimate Hotkeys (fury) — LIVING DOC, keep updated

> Last updated: 2026-09-24 (appendix re-synced to post-swap config: U=special trio, J=scratchpad trio, 157 binds verified). MangoWC 0.17.0 + DMS 1.6 + Noctalia 5.1.0.
> Source of truth: `~/.config/mango/config.conf` (+ `media.conf`, `dms/` fragments).
> This file is the hotkey reference to hand to any AI. When binds change, update this file AND the config together.
> Supersedes `~/mango-dms-hotkeys.md` (left untouched as archive).

## HOW TO READ (config vs comment)

- `#` at column 1 = comment, ignored by mango. Never put `#` inline on a bind line (mango glues it onto the last arg and breaks the bind).
- `bind=MOD,key,action,params` at column 1 = ACTIVE keyboard binding, shows on `SUPER+H`.
- `mousebind=` / `axisbind=` = ACTIVE but **invisible on `SUPER+H`** (DMS parser only reads `bind=`). This doc is their only sheet.
- Indented ` bind=` (one space, `media.conf`) = ACTIVE but hidden from `SUPER+H` on purpose.
- Validate after any edit: `mango -p -c ~/.config/mango/config.conf` must exit 0, no output. Mango hot-reloads valid configs.

## DMS shell

| Shortcut | Action |
|---|---|
| `SUPER + Space` | Spotlight launcher |
| `SUPER + V` | Clipboard history |
| `SUPER + M` | Process list |
| `SUPER + Comma` | DMS settings |
| `SUPER + N` | Notifications panel |
| `SUPER + Shift + N` | Do not disturb toggle |
| `SUPER + W` | Wallpaper switcher |
| `SUPER + O` | Control center |
| `SUPER + Shift + O` | Restart portals (screenshare fix) |
| `SUPER + Shift + C` | Color picker |
| `SUPER + T` | Theme dark/light toggle |
| `SUPER + Alt + L` | Lock screen |
| `SUPER + Semicolon` | Emoji picker (spotlight `:e`, needs emojiLauncher) |
| `CTRL + Alt + P` | Power menu |
| `SUPER + X` | Power menu quick |
| `SUPER + P` | Power profile cycle (perf/balanced/saver) |
| `SUPER + Shift + P` | Media play/pause |
| `SUPER + H` | Cheatsheet (this sheet's live version) |
| `SUPER + Shift + H` | Zsh aliases list (rofi, Enter copies) |
| `SUPER + Shift + R` | Reload mango config (dwm restart parity) |
| `SUPER + R` | Restart DMS shell (bar recovers, windows stay) |
| `CTRL + Alt + SUPER + B` | Toggle DMS bar (island-safe script) |

## Apps

| Shortcut | Action |
|---|---|
| `SUPER + Return` | Kitty |
| `SUPER + Shift + Return` | Kitty dropdown scratchpad |
| `SUPER + D` | Dolphin |
| `SUPER + E` | Thunar |
| `SUPER + B` | Browser (`xdg-open https://` → Brave) |
| `SUPER + Shift + B` | Private Brave window (`--incognito`) |
| `SUPER + F` | Firefox |
| `SUPER + Z` | Zen Browser (beta) |
| `SUPER + Shift + Z` | Private Zen window (`--private-window`) |
| `SUPER + K` | qutebrowser (keyboard-driven, vim bindings) |
| `SUPER + C` | VSCodium |
| `SUPER + Shift + V` | Neovim in Kitty (terminal editor) |
| `SUPER + Y` | Yazi in Kitty (terminal file manager) |
| `SUPER + Shift + Y` | Superfile in Kitty |
| `SUPER + Shift + G` | Brave WebGPU build (heavy, on demand) |

## Layouts (14, per-tag)

`SUPER+L` cycles: tile, scroller, monocle, grid, deck, center_tile, vertical_tile, right_tile, vertical_scroller, vertical_grid, vertical_deck, dwindle, fair, vertical_fair.

| Shortcut | Action |
|---|---|
| `SUPER + L` | Next layout (all 14) |
| `SUPER + A` | Fave-four rotation (tile, scroller, monocle, dwindle) |
| `SUPER + Alt + 1..4` | Jump to tile / scroller / monocle / dwindle |
| `SUPER + I` | More masters (`incnmaster +1`) |
| `SUPER + CTRL + D` | Fewer masters (`incnmaster -1`) |
| `SUPER + CTRL + Return` | Swap with master (`zoom`) |
| `SUPER + Shift + I` | Dwindle toggle split |

## Windows

| Shortcut | Action |
|---|---|
| `SUPER + Q` | Close (`killclient`) |
| `SUPER + Shift + Q` | Force kill (`killclient force`, SIGKILL) |
| `SUPER + Shift + F` | Fullscreen |
| `SUPER + CTRL + F` | Maximize (keeps bar/border) |
| `SUPER + CTRL + Space` | Float current |
| `SUPER + Alt + Space` | Float all |
| `ALT + Tab` / `ALT + Shift + Tab` | Next / prev window (`focusstack`) |
| `SUPER + Arrows` | Focus dir |
| `SUPER + CTRL + Arrows` | Swap tiling window (`exchange_client`) |
| `SUPER + Alt + Arrows` | Move floating (`smartmovewin`) |
| `SUPER + Shift + Arrows` | Resize 50px |
| `SUPER + G` | Group with right neighbor |
| `SUPER + CTRL + K` / `L` | Group left / right |
| `SUPER + CTRL + H` | Leave group |
| `SUPER + CTRL + Tab` / `SUPER + CTRL + Shift + Tab` | Next / prev group member |

## Mouse (NOT on SUPER+H — this table is the sheet)

| Shortcut | Action |
|---|---|
| `SUPER + Left-drag` | Tiled: drag onto another to swap (stays tiled). Floating: move |
| `SUPER + Shift + Left-click` | Float window in place (`togglefloating`; toggles — click again re-tiles). Then `SUPER + drag` to move |
| `SUPER + Right-drag` | Resize |
| `SUPER + Wheel up/down` | Prev / next used tag |

Note: single-gesture SHIFT-drag-float is impossible — mango retiles EVERY tiled-window drag globally, any modifier (tested). The click-then-drag two-step is the closest mango 0.16.2 allows.

## Screenshots (DMS → satty)

| Shortcut | Action |
|---|---|
| `SUPER + S` | Region → satty annotate |
| `SUPER + Shift + S` | Window → satty |
| `SUPER + CTRL + Shift + S` | Fullscreen → satty |
| `Print` | Full save (file + clipboard) |
| `Shift + Print` | Region save |
| `Alt + Print` | Window save |

## Tags (workspaces, 9, carousel wraps 9↔1)

| Shortcut | Action |
|---|---|
| `SUPER + Tab` | Next used tag (skips empty) |
| `SUPER + Shift + Tab` | Prev used tag |
| `SUPER + Period` / `Shift + Period` | Cycle all tags fwd/back (incl. empty, via script) |
| `SUPER + 1..9` | View tag N |
| `SUPER + Shift + 1..9` | Send window to tag + follow |
| `SUPER + CTRL + 1..9` | Send silent (no follow) |
| `SUPER + Shift + [` / `]` | Move window one tag left / right |
| `SUPER + U` | Special workspace overlay |
| `SUPER + Shift + U` | Send window to special |
| `SUPER + CTRL + U` | Send silent to special |
| `SUPER + J` | Tiling scratchpad |
| `SUPER + Shift + J` | Minimize |
| `SUPER + CTRL + J` | Restore minimized |

## Shell modes (DMS + Noctalia, one file)

`keymode=` markers are positional — every bind below one belongs to that mode until the next marker. Mango boots into `default`.

| Shortcut | Action |
|---|---|
| `SUPER + Alt + N` | Switch to Noctalia (stops DMS, starts Noctalia, flips keymode) |
| `SUPER + Alt + D` | Switch to DMS (stops Noctalia, starts DMS, flips keymode) |

- `common` mode: all shell-agnostic binds (tags, layouts, windows, apps) + the two swap binds. Always active.
- `default` mode: the DMS tables above. Active at login.
- `noctalia` mode: mirrors the DMS set via `noctalia msg` — `SUPER+Space` launcher, `SUPER+V` clipboard, `SUPER+Comma` settings, `SUPER+O` control center, `SUPER+W` wallpaper, `SUPER+X`/`CTRL+ALT+P` session menu, `SUPER+P` power profile (`power-cycle`), `SUPER+SHIFT+P` media toggle, `SUPER+T` theme toggle, `SUPER+SHIFT+N` DND, `SUPER+ALT+L` lock, `SUPER+Semicolon` emoji (`launcher /emo`), `SUPER+M` btop, `SUPER+S`/`SHIFT+S`/`CTRL+SHIFT+S` + `Print` trio (region/fullscreen/annotate), `SUPER+R` Noctalia config reload, `SUPER+H` Keybind Cheatsheet plugin panel, `CTRL+ALT+SUPER+B` bar toggle, XF86 volume/brightness, portal-restart dup.
- Intentionally unbound in Noctalia mode (no equivalent): `SUPER+N`, `SUPER+SHIFT+C`.
- `SUPER+H` works in both modes: DMS cheatsheet in `default`, markdown sheet in a pager in `noctalia`.
- `SUPER+H` shows DMS descriptions even in Noctalia mode (it displays the last-parsed bind per key, and the DMS block deliberately parses last); this sheet is the accurate reference.
- Swap scripts verify each step and roll back on failure; never run both shells at once.

## Monitors (dwm parity; inert on single-monitor)

| Shortcut | Action |
|---|---|
| `SUPER + Alt + Comma` | Focus prev monitor |
| `SUPER + Alt + Period` | Focus next monitor |
| `SUPER + Alt + Shift + Comma` | Send window to prev monitor |
| `SUPER + Alt + Shift + Period` | Send window to next monitor |

## Media keys (`media.conf`, hidden from cheatsheet)

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume +3 (dms audio) |
| `XF86AudioLowerVolume` | Volume -3 |
| `XF86AudioMute` | Mute |
| `XF86MonBrightnessUp` | Brightness +5 |
| `XF86MonBrightnessDown` | Brightness -5 |

## Appearance / behavior

`border 1px` red focus, `radius 12`, `gaps 5`, `focused_opacity 1.0`, `unfocused_opacity 0.9`, `shadows on` (floating only, size 10 blur 15). Mouse `accel -0.5 flat`. DMS fragments sourced from `~/.config/mango/dms/` (colors/layout/outputs/cursor/windowrules; `binds.conf` stays empty, DMS-managed). NOTE: the hardcoded Appearance block in `config.conf` comes *after* the `source=` lines, so it overrides `dms/layout.conf` — DMS Settings tweaks to gaps/border won't take effect unless that block is removed.

## FOR AI AGENTS — update rules (follow every time)

1. Source of truth is `~/.config/mango/config.conf` (+ `media.conf`). This doc mirrors it. Change both or neither.
2. Comments start at column 1. Never inline `#` on a bind line. Keep desc comments under ~30 chars (last `#` line above a bind renders on `SUPER+H`).
3. Validate: `mango -p -c ~/.config/mango/config.conf` → exit 0, silent. Then `dms keybinds show mangowc` → check the row. Invalid edits are ignored live (session keeps last-good).
4. `mousebind=`/`axisbind=` never appear on `SUPER+H` — document them ONLY here, in the Mouse table.
5. Keep media keys indented in `media.conf` (hidden from sheet by design). Never use `dms/binds.conf`.
6. Installed mango is 0.16.2 — the docs site tracks dev main, so verify every new dispatcher against the binary (`mango -p` rejects unknowns), not the website.
7. Bump `Last updated` at top and add a Changelog entry below for every change.
8. Refresh the Appendix snapshot below (binds + `media.conf`) so the emergency copy never drifts from the config.

## Changelog

- 2026-09-13: created as the maintained copy (supersedes `mango-dms-hotkeys.md`). Added missing binds (Zen, brave-webgpu, portal restart, prev-group-member), new Mouse table incl. `SUPER+SHIFT+Left-click` float toggle, AI update rules.
- 2026-09-13: added `SUPER+SHIFT+R` reload_config (dwm restart parity), restored missing `SUPER+SHIFT+H` aliases row.
- 2026-09-13: added `SUPER+R` restart DMS shell (`systemctl --user restart dms`, dwm bar-restart parity).
- 2026-09-13: third audit — verified fragments (`binds.conf` empty, scripts match doc), noted Appearance-block-overrides-`layout.conf` gotcha.
- 2026-09-13: added monitor binds (`SUPER+ALT+comma/period` focus, `+SHIFT` send; dwm parity, inert until second monitor).
- 2026-09-13: added direct layout jump (`SUPER+ALT+1..4` → tile/scroller/monocle/dwindle), private Brave (`SHIFT+B`) and private Zen (`SHIFT+Z`).
- 2026-09-13: added Appendix with raw hotkey source (emergency restore copy).
- 2026-09-13: installed qutebrowser 3.7.0 (`nix profile`), bound `SUPER+K`; appendix refreshed.
- 2026-09-15: added `SUPER+semicolon` emoji picker (`spotlight toggleQuery ":e "`, needs emojiLauncher); appendix refreshed.
- 2026-09-15: retired YouTube `SUPER+Y` web app (Brave swallowed `--app` into existing session); `SUPER+Y` is now Yazi, `SUPER+SHIFT+Y` Superfile, both in Kitty; appendix refreshed.
- 2026-09-15: fixed Superfile bind — nixpkgs binary is `superfile`, not upstream `spf`; appendix refreshed.
- 2026-09-15: added `SUPER+SHIFT+V` neovim in Kitty; appendix refreshed.
- 2026-09-15: added `SUPER+J` calculator (qalculate-qt, last free bare SUPER+letter); appendix refreshed.
- 2026-09-15: switched MangoWC 0.16.3 → 0.17.0 (source override until unstable catches up); replaced `SUPER+J` calculator with special workspace trio (`toggle_special_tag` / `tag_special_tag` / `tag_special_silent`); appendix refreshed.
- 2026-09-15: fixed grey desktop on re-login — added `exec-once=systemctl --user start dms` (session target is often already active, so its Wants never refires and DMS stayed dead).
- 2026-09-15: dual-shell keymodes — `noctalia` mode mirroring the DMS set via `noctalia msg`, `SUPER+ALT+N/D` swap scripts (verify + rollback), manual `noctalia.service` (no autostart); appendix refreshed (156 binds).
- 2026-09-15: swapped the complete special-workspace trio from `SUPER+J` to `SUPER+U`; moved regular scratchpad/minimize/restore to the `SUPER+J` trio.
- 2026-09-24: appendix-only fix — snapshot still showed pre-swap J/U actions + stale descs; re-synced 6 lines to live config (157/157 verified), tables needed no change.

## Appendix: raw hotkey source (snapshot 2026-09-24)

> Emergency restore copy — 157 binds, count-verified against `config.conf`. Source of truth stays the config files. Refresh per AI rule 8.

```ini
# Shell modes: default=DMS binds (boot mode), common=both shells,
# noctalia=Noctalia binds (section below). Swap with SUPER+ALT+N/D.
# NOTE: the noctalia section parses FIRST so SUPER+H shows DMS descs
# (correct for the boot/default mode); in noctalia mode shared keys
# still show DMS text — the markdown sheet is the accurate reference.
# Shell modes: default=DMS binds (boot mode), common=both shells,
# noctalia=Noctalia binds (section below). Swap with SUPER+ALT+N/D.
# NOTE: the noctalia section parses FIRST so SUPER+H shows DMS descs
# (correct for the boot/default mode); in noctalia mode shared keys
# still show DMS text — the markdown sheet is the accurate reference.
keymode=noctalia
# Noctalia launcher
bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
# Noctalia clipboard history
bind=SUPER,v,spawn,noctalia msg panel-toggle clipboard
# Process monitor (btop)
bind=SUPER,m,spawn,kitty --class btop -e btop
# Noctalia settings
bind=SUPER,comma,spawn,noctalia msg settings-toggle
# Do not disturb toggle
bind=SUPER+SHIFT,n,spawn,noctalia msg notification-dnd-toggle
# Noctalia wallpaper panel
bind=SUPER,w,spawn,noctalia msg panel-toggle wallpaper
# Noctalia control center
bind=SUPER,o,spawn,noctalia msg panel-toggle control-center
# Theme dark/light toggle
bind=SUPER,t,spawn,noctalia msg theme-mode-toggle
# Lock screen
bind=SUPER+ALT,l,spawn,noctalia msg session lock
# Emoji picker (launcher /emo context)
bind=SUPER,semicolon,spawn,noctalia msg panel-toggle launcher /emo
# Region screenshot
bind=SUPER,s,spawn,noctalia msg screenshot-region
# Fullscreen screenshot
bind=SUPER+SHIFT,s,spawn,noctalia msg screenshot-fullscreen
# Annotate screenshot
bind=SUPER+CTRL+SHIFT,s,spawn,noctalia msg screenshot-annotate
# Fullscreen screenshot save
bind=NONE,Print,spawn,noctalia msg screenshot-fullscreen
# Region screenshot save
bind=SHIFT,Print,spawn,noctalia msg screenshot-region
# Annotate screenshot save
bind=ALT,Print,spawn,noctalia msg screenshot-annotate
# Session / power menu
bind=CTRL+ALT,p,spawn,noctalia msg panel-toggle session
# Session / power menu quick
bind=SUPER,x,spawn,noctalia msg panel-toggle session
# Power profile cycle
bind=SUPER,p,spawn,noctalia msg power-cycle
# Media play pause
bind=SUPER+SHIFT,p,spawn,noctalia msg media toggle
# Reload Noctalia config
bind=SUPER,r,spawn,noctalia msg config-reload
# Toggle Noctalia bar
bind=CTRL+ALT+SUPER,b,spawn,noctalia msg bar-toggle
# Bind sheet (this markdown)
bind=SUPER,h,spawn_shell,kitty --class hotkeys -e bat ~/nixos-backups/mango-ultimate-hotkeys.md
# Portal restart (same shell-agnostic fix as DMS mode)
bind=SUPER+SHIFT,o,spawn_shell,systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr && notify-send 'Portals' 'ScreenCast restarted — retry sharing'
# Volume up
bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
# Volume down
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
# Volume mute
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
# Brightness up
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
# Brightness down
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down
keymode=default
# ---- DMS keybinds ----
# Spotlight launcher
bind=SUPER,space,spawn,dms ipc call spotlight toggle
# Clipboard history
bind=SUPER,v,spawn,dms ipc call clipboard toggle
# Process list
bind=SUPER,m,spawn,dms ipc call processlist focusOrToggle
# DMS settings
bind=SUPER,comma,spawn,dms ipc call settings focusOrToggle
# Notifications panel
bind=SUPER,n,spawn,dms ipc call notifications toggle
# Do not disturb toggle
bind=SUPER+SHIFT,n,spawn,dms ipc call notifications toggleDoNotDisturb
# Wallpaper switcher
bind=SUPER,w,spawn,dms ipc call dankdash wallpaper
# Control center
bind=SUPER,o,spawn,dms ipc call control-center toggle
# Portal restart (screenshare fix — re-registers ScreenCast)
bind=SUPER+SHIFT,o,spawn_shell,systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr && notify-send 'Portals' 'ScreenCast restarted — retry sharing'
# Color picker
bind=SUPER+SHIFT,c,spawn,dms ipc call color-picker toggle
# Theme dark/light toggle
bind=SUPER,t,spawn,dms ipc call theme toggle
# Yazi file manager
bind=SUPER,y,spawn,kitty --class yazi -e yazi
# Superfile file manager
bind=SUPER+SHIFT,y,spawn,kitty --class superfile -e superfile
# Brave WebGPU build (grainrad etc. — heavier XWayland/Vulkan, on demand)
bind=SUPER+SHIFT,g,spawn,brave-webgpu
# Lock screen
bind=SUPER+ALT,l,spawn,dms ipc call lock lock
# Emoji picker (spotlight :e trigger, needs emojiLauncher plugin)
bind=SUPER,semicolon,spawn,dms ipc call spotlight toggleQuery ":e "

keymode=common
# =========================================================================
# PORTED FROM HYPRLAND (full report: ~/.config/mango/KEYBIND-PORT.md)
# Tuned for mango 0.16.2 (nixos-unstable via programs.mangowc.package in
# mango-dms.nix). 0.16 has the new IPC (DMS bar workspaces), groups,
# switcher, special tags, killclient force, dwindle/fair layouts.
# NOTE: mango only strips comments starting at col 1 — never put "#"
# inline on a bind line (it glues onto the last arg and breaks it).
# =========================================================================

# ---- One-key layout cycling: SUPER+L cycles all 14 mango 0.16 layouts ----
circle_layout=tile,scroller,monocle,grid,deck,center_tile,vertical_tile,right_tile,vertical_scroller,vertical_grid,vertical_deck,dwindle,fair,vertical_fair
bind=SUPER,l,switch_layout
# Fave-four rotation (tile, scroller, monocle, dwindle).
# SUPER+L cycles all 14, untouched:
# Cycle fave layouts
bind=SUPER,a,spawn_shell,~/.config/mango/cycle-fav-layouts.sh
# Direct jump to fave-four layouts (SUPER+L cycles all 14)
# Jump to tile layout
bind=SUPER+ALT,1,setlayout,tile
# Jump to scroller layout
bind=SUPER+ALT,2,setlayout,scroller
# Jump to monocle layout
bind=SUPER+ALT,3,setlayout,monocle
# Jump to dwindle layout
bind=SUPER+ALT,4,setlayout,dwindle

# ---- Standard ----
# Dolphin file manager
bind=SUPER,d,spawn,dolphin
# Open browser
bind=SUPER,b,spawn,xdg-open https://
# Private Brave window
bind=SUPER+SHIFT,b,spawn,brave --incognito
# Browser (firefox)
bind=SUPER,f,spawn,firefox
# Zen Browser (HM-managed beta)
bind=SUPER,z,spawn,zen-beta
# Private Zen window
bind=SUPER+SHIFT,z,spawn,zen-beta --private-window
# Keyboard-driven browser (qutebrowser, vim bindings)
bind=SUPER,k,spawn,qutebrowser
# Editor (vscodium)
bind=SUPER,c,spawn,codium
# Editor (neovim in kitty)
bind=SUPER+SHIFT,v,spawn,kitty --class nvim -e nvim
# Terminal (kitty)
bind=SUPER,Return,spawn,kitty
# File manager (thunar)
bind=SUPER,e,spawn,thunar

# ---- Features / extras ----
# Fullscreen toggle
bind=SUPER+SHIFT,f,togglefullscreen
bind=SUPER+CTRL,f,togglemaximizescreen
# SUPER+SPACE is DMS spotlight, so float-current lives on SUPER+CTRL+SPACE:
# Float current window
bind=SUPER+CTRL,space,togglefloating
# Float all windows
bind=SUPER+ALT,space,toggle_all_floating
keymode=default
# Screenshots via DMS piped to satty for annotation
# Region select to satty
bind=SUPER,s,spawn_shell,dms screenshot --stdout --no-file --no-clipboard --no-notify | satty --filename -
# Focused window to satty
bind=SUPER+SHIFT,s,spawn_shell,dms screenshot window --stdout --no-file --no-clipboard --no-notify | satty --filename -
# Fullscreen to satty
bind=SUPER+CTRL+SHIFT,s,spawn_shell,dms screenshot full --stdout --no-file --no-clipboard --no-notify | satty --filename -
# Quick fullscreen save, no annotation (file plus clipboard)
bind=NONE,Print,spawn,dms screenshot full
# Quick region save, no annotation
bind=SHIFT,Print,spawn,dms screenshot
# Quick window save, no annotation
bind=ALT,Print,spawn,dms screenshot window
keymode=common

# ---- System ----
# Close window
bind=SUPER,q,killclient
# 0.16 killclient takes a force arg — SIGKILL, replaces KillActiveProcess.sh.
# (Helper script fallback kept at ~/.config/mango/kill-focused.sh)
# Force kill (SIGKILL)
bind=SUPER+SHIFT,q,killclient,force
keymode=default
# Hide/show the DMS bar (Dank Island). DMS's own `bar hide` IPC refuses
# island bars, so this flips the config's enabled field + reloads:
# Toggle DMS bar
bind=CTRL+ALT+SUPER,b,spawn_shell,~/.config/mango/toggle-dms-bar.sh
# Power menu
bind=CTRL+ALT,p,spawn,dms ipc call powermenu toggle
# Power menu quick
bind=SUPER,x,spawn,dms ipc call powermenu toggle
# Power profile cycle
bind=SUPER,p,spawn,dms ipc call powerprofile cycle
# Media play pause
bind=SUPER+SHIFT,p,spawn,dms ipc call mpris playPause
# This cheatsheet
bind=SUPER,h,spawn,dms ipc call keybinds toggle mangowc
keymode=common
# Zsh aliases list
bind=SUPER+SHIFT,h,spawn_shell,~/.config/mango/zsh-aliases.sh
# Reload mango config
bind=SUPER+SHIFT,r,reload_config
keymode=default
# Restart DMS shell
bind=SUPER,r,spawn_shell,systemctl --user restart dms
keymode=common
# Switch shell to Noctalia
bind=SUPER+ALT,n,spawn_shell,~/.config/mango/to-noctalia.sh
# Switch shell to DMS
bind=SUPER+ALT,d,spawn_shell,~/.config/mango/to-dms.sh

# ---- Master layout ----
# Fewer masters
bind=SUPER+CTRL,d,incnmaster,-1
# More masters
bind=SUPER,i,incnmaster,+1
# Swap with master
bind=SUPER+CTRL,Return,zoom

# ---- Dwindle layout ----
# Toggle dwindle split
bind=SUPER+SHIFT,i,dwindle_toggle_current_split

# ---- Groups (dwl-style directional) ----
# Group with right neighbor
bind=SUPER,g,groupjoin,right
# Next group member
bind=SUPER+CTRL,Tab,groupfocus,next
# Prev group member
bind=SUPER+CTRL+SHIFT,Tab,groupfocus,prev
# Group with left neighbor
bind=SUPER+CTRL,k,groupjoin,left
# Group with right neighbor
bind=SUPER+CTRL,l,groupjoin,right
# Leave group
bind=SUPER+CTRL,h,groupleave

# ---- Window cycling (0.16.2: focusstack; no thumbnail switcher) ----
# Next window
bind=ALT,Tab,focusstack,next
# Prev window
bind=ALT+SHIFT,Tab,focusstack,prev

# ---- Focus / move / swap / resize ----
# Focus left
bind=SUPER,Left,focusdir,left
bind=SUPER,Right,focusdir,right
bind=SUPER,Up,focusdir,up
bind=SUPER,Down,focusdir,down
bind=SUPER+CTRL,Left,exchange_client,left
bind=SUPER+CTRL,Right,exchange_client,right
bind=SUPER+CTRL,Up,exchange_client,up
bind=SUPER+CTRL,Down,exchange_client,down
# Move floating left
bind=SUPER+ALT,Left,smartmovewin,left
# Move floating right
bind=SUPER+ALT,Right,smartmovewin,right
# Move floating up
bind=SUPER+ALT,Up,smartmovewin,up
# Move floating down
bind=SUPER+ALT,Down,smartmovewin,down
bind=SUPER+SHIFT,Left,resizewin,-50,+0
bind=SUPER+SHIFT,Right,resizewin,+50,+0
bind=SUPER+SHIFT,Up,resizewin,+0,-50
bind=SUPER+SHIFT,Down,resizewin,+0,+50

# ---- Tags (workspaces) ----
# tag_carousel=1 enables 9<->1 wrap for viewtoleft/right AND the
# view*left/right_have_client populated-workspace hops below:
tag_carousel=1
# Populated-workspace hopping now on SUPER+Tab (swap with former period
# binds). viewtoright/viewtoleft_have_client skip empty tags, wrap 9<->1
# via tag_carousel, and work from multi-tag views:
# Next used workspace
bind=SUPER,Tab,viewtoright_have_client
# Prev used workspace
bind=SUPER+SHIFT,Tab,viewtoleft_have_client
# Full cycle (every workspace incl. empty) via cycle-tag.sh — immune to
# the multi-tag/overview states that make viewtoright silently no-op:
# Cycle workspaces forward
bind=SUPER,period,spawn_shell,~/.config/mango/cycle-tag.sh next
# Cycle workspaces back
bind=SUPER+SHIFT,period,spawn_shell,~/.config/mango/cycle-tag.sh prev
# Special workspace overlay
bind=SUPER,u,toggle_special_tag
# Send window to special
bind=SUPER+SHIFT,u,tag_special_tag
# Send silent to special
bind=SUPER+CTRL,u,tag_special_silent
# Regular scratchpad toggle
bind=SUPER,j,toggle_scratchpad
# Minimize window
bind=SUPER+SHIFT,j,minimized
# Restore minimized window
bind=SUPER+CTRL,j,restore_minimized
# Named scratchpad: kitty dropdown, spawns if not running.
# 0.16.2 signature is id,title,cmd (guide's width/height args are wrong
# for this version — windowrule sizes it instead). SUPER+CTRL+Return was
# taken (zoom), so the dropdown lives on SUPER+SHIFT+Return:
# Kitty dropdown scratchpad
bind=SUPER+SHIFT,Return,toggle_named_scratchpad,scratch-term,scratch-term,kitty --class scratch-term
windowrule=isnamedscratchpad:1,width:1280,height:800,appid:scratch-term
bind=SUPER,1,view,1,0
bind=SUPER,2,view,2,0
bind=SUPER,3,view,3,0
bind=SUPER,4,view,4,0
bind=SUPER,5,view,5,0
bind=SUPER,6,view,6,0
bind=SUPER,7,view,7,0
bind=SUPER,8,view,8,0
bind=SUPER,9,view,9,0
bind=SUPER+SHIFT,1,tag,1,0
bind=SUPER+SHIFT,2,tag,2,0
bind=SUPER+SHIFT,3,tag,3,0
bind=SUPER+SHIFT,4,tag,4,0
bind=SUPER+SHIFT,5,tag,5,0
bind=SUPER+SHIFT,6,tag,6,0
bind=SUPER+SHIFT,7,tag,7,0
bind=SUPER+SHIFT,8,tag,8,0
bind=SUPER+SHIFT,9,tag,9,0
# Send to tag (no follow)
bind=SUPER+CTRL,1,tagsilent,1
# Send to tag (no follow)
bind=SUPER+CTRL,2,tagsilent,2
# Send to tag (no follow)
bind=SUPER+CTRL,3,tagsilent,3
# Send to tag (no follow)
bind=SUPER+CTRL,4,tagsilent,4
# Send to tag (no follow)
bind=SUPER+CTRL,5,tagsilent,5
# Send to tag (no follow)
bind=SUPER+CTRL,6,tagsilent,6
# Send to tag (no follow)
bind=SUPER+CTRL,7,tagsilent,7
# Send to tag (no follow)
bind=SUPER+CTRL,8,tagsilent,8
# Send to tag (no follow)
bind=SUPER+CTRL,9,tagsilent,9
# Move window one tag left
bind=SUPER+SHIFT,bracketleft,tagtoleft,0
# Move window one tag right
bind=SUPER+SHIFT,bracketright,tagtoright,0

# ---- Monitors (dwm parity; inert on single-monitor, live with two) ----
# Focus prev monitor
bind=SUPER+ALT,comma,focusmon,left
# Focus next monitor
bind=SUPER+ALT,period,focusmon,right
# Send window to prev monitor
bind=SUPER+ALT+SHIFT,comma,tagmon,left
# Send window to next monitor
bind=SUPER+ALT+SHIFT,period,tagmon,right

# ---- Mouse: SUPER+LMB drag (swap if tiled / move if floating), SUPER+SHIFT+LMB force float-drag ----
# HOW TO READ: line starting with # = comment, ignored. Line like 'mousebind=...' = ACTIVE binding that runs.
# Drag window (tiled swaps on drop, floating moves)
mousebind=SUPER,btn_left,moveresize,curmove
# Float on SHIFT+click (mirrors dwm Super+Shift+Left-drag in two steps). Single-gesture SHIFT-drag-float
# is impossible: mango retiles EVERY tiled-window moveresize drag globally, any modifier. So: SHIFT+click
# floats the window in place, then SUPER+Left-drag moves it (floating windows just move, never swap).
# NOTE: it toggles — SHIFT+click on an already-floating window re-tiles it.
mousebind=SUPER+SHIFT,btn_left,togglefloating
# Drag to resize window
mousebind=SUPER,btn_right,moveresize,curresize

# ---- Wheel: SUPER+scroll hops POPULATED workspaces (skips empty
# tags, wraps 9<->1 via tag_carousel) ----
# Wheel to prev used workspace
axisbind=SUPER,UP,viewtoleft_have_client
# Wheel to next used workspace
axisbind=SUPER,DOWN,viewtoright_have_client
```

### media.conf (indented = hidden from SUPER+H by design)

```ini
# Media keys live here on purpose: mango executes indented binds normally,
# but the DMS cheatsheet parser only reads `bind=` at column 1, so these
# stay off Super+H while remaining fully functional.
 bind=NONE,XF86AudioRaiseVolume,spawn,dms ipc call audio increment 3
 bind=NONE,XF86AudioLowerVolume,spawn,dms ipc call audio decrement 3
 bind=NONE,XF86AudioMute,spawn,dms ipc call audio mute
 bind=NONE,XF86MonBrightnessUp,spawn,dms ipc call brightness increment 5
 bind=NONE,XF86MonBrightnessDown,spawn,dms ipc call brightness decrement 5
```
