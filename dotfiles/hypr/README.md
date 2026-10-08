# fury-hyprland-dms

Hyprland 0.55+ Lua config + DMS (DankMaterialShell) keybind setup. JaKooLit-flavored binds, remapped to Mango/DMS muscle memory: DMS owns launcher, clipboard, notifications, screenshots, power — Hyprland owns windows, workspaces, layouts.

## Requirements

- Hyprland **0.55+** (Lua config era — will NOT work with `hyprland.conf`)
- DankMaterialShell **1.6+** installed and working (`dms run` starts the shell)
- Core tools: `kitty`, `rofi`, `satty`, `grim`, `hyprlock`, `hypridle`, `jq`,
  `notify-send` (libnotify), `wl-clipboard` + `cliphist`, a polkit agent
- Optional (graceful if missing): `vicinae`, `swaync`, `waybar`, `brave`,
  `firefox`, `thunar`, `dolphin`, `codium`, `qutebrowser`, `yazi`, `superfile`,
  `zen-beta`, `playerctl`, `pamixer`, `brightnessctl`

## Install (where everything goes)

> This repo mirrors `~/.config/hypr/` file-for-file. Back yours up first:
> `cp -r ~/.config/hypr ~/.config/hypr.bak`

```bash
git clone https://github.com/Hackcoon/fury-hyprland-dms /tmp/fury-hyprland-dms
cp -r /tmp/fury-hyprland-dms/* ~/.config/hypr/
chmod +x ~/.config/hypr/scripts/*.sh
```

| Repo path | Goes to | What it is |
|---|---|---|
| `hyprland.lua` | `~/.config/hypr/hyprland.lua` | main config: env, monitors, layout, autostart (DMS), rules |
| `binds.lua` | `~/.config/hypr/binds.lua` | workspaces/mouse/retired archive (loaded first) |
| `dms/binds.lua` | `~/.config/hypr/dms/binds.lua` | **all active keybinds** + DMS cheatsheet source |
| `dms/*.lua` | `~/.config/hypr/dms/` | DMS-managed colors/layout/cursor/rules fragments |
| `animations/` | `~/.config/hypr/animations/` | 19 animation style presets (`SUPER+ALT+A` picker) |
| `scripts/` | `~/.config/hypr/scripts/` | helper scripts (must be executable) |
| `UserScripts/` | `~/.config/hypr/UserScripts/` | user helper scripts |
| `UserConfigs/` | `~/.config/hypr/UserConfigs/` | defaults + `user_animations.lua` (your picked preset) |
| `hypridle.conf`, `hyprlock.conf` | same names | idle/lock behavior |
| `hyprland-keys-final.md` | docs only | full audited keybind inventory |

`hyprland.lua` must contain (already wired here — keep these lines):
```lua
dofile(os.getenv("HOME") .. "/.config/hypr/binds.lua")
require("dms.binds")
```

Then: start DMS (`dms run`), `hyprctl reload`, press `SUPER+H` — the DMS
cheatsheet should list ~130+ binds. If it's empty, `dms/binds.lua` isn't
loading (check the `require` line).

## ⚠️ NixOS-isms to adjust on other distros

- `hyprland.lua` autostart uses absolute paths (`/run/current-system/sw/bin/dms`,
  `/run/wrappers/bin/gnome-keyring-daemon`). Elsewhere: replace with `which dms`
  / your keyring path (or bare names if they're on `PATH`).
- Env assumes `NIXOS_OZONE_WL`-style session; GTK/Qt theme lines
  (`QT_QPA_PLATFORMTHEME=kde`, Dark Dream colors) are personal — adapt or drop.
- Emoji workspace names + 9 persistent tags are a choice, not a requirement.

## Keybind highlights (full list: `hyprland-keys-final.md`)

`SPACE` spotlight · `ALT+SPACE` vicinae · `V` clipboard · `N` notifs · `W` wallpaper · `O` control center ·
`S` region→satty · `U` special · `J` scratch · `L` layout cycle (dwindle/master/scrolling) ·
`Tab`/wheel hop used workspaces · `1..9` tags · `H` this sheet · `R` restart DMS.
