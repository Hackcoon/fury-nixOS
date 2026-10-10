# Hyprland Implementation Notes

> Personal reference for this Hyprland setup (NixOS · Hyprland 0.55+ · Lua config port of JaKooLit/Hyprland-Dots).
> Config root: `~/.config/hypr/` — main file `hyprland.lua`, keybinds `binds.lua`.

---

## Visual Effects (The Look I Like)

### Window Glow (Shadow)
`hyprland.lua:112` — under `decoration`:
```lua
shadow = { enabled = true, range = 15, render_power = 3, offset = {0, 3} }
```
- `range = 15` → glow spreads 15px around windows
- `render_power = 3` → intensity/darkness of the glow
- `offset = {0, 3}` → shifted slightly down (glow appears mostly bottom/top edges)
- Combined with blur + `ignore_alpha` layer rules, produces the soft neon halo
- Tweaks: raise `range` = wider halo, raise `render_power` = stronger, `offset = {0,0}` = uniform halo

### Blue Gradient Borders (Tokyo Night colors)
`hyprland.lua:24-28` — under `general`:
```lua
border_size = 2,
col = {
  active_border   = { colors = { "rgb(7aa2f7)", "rgb(bb9af7)" }, angle = 45 },  -- blue → purple gradient
  inactive_border = "rgb(414868)",                                             -- muted dark blue
}
```
- Active windows: blue (`7aa2f7`) fading into purple (`bb9af7`) at 45° — Tokyo Night palette
- Inactive windows: dim slate-blue (`414868`)
- `resize_on_border = true` (line 21) — grab the border itself to resize
- The border gradient *animates* — see `borderangle` animation at `hyprland.lua:130` (speed 30, "once" style)

### Blur
`hyprland.lua:107-111`:
```lua
blur = {
  enabled = true, size = 4, passes = 3,
  contrast = 0.8916, brightness = 1.0, vibrancy = 0.1696,
  new_optimizations = true, xray = false, popups = true, popups_ignorealpha = 0.2,
}
```
- Window rounding: 10px (`decoration.rounding`, line 106)
- Layer rules (lines 200-206) apply blur to: tide panels, fury-bar pills, vicinae, rofi, swaync, waybar (all with varying `ignore_alpha`)

---

## Bars / Shells

Three bar shells available, one runs at a time:
| Shell | What it is | Status |
|---|---|---|
| **fury-bar** | quickshell bar (`~/.config/quickshell/fury-bar`) | **MAIN** — autostarted in `hyprland.lua:186` |
| **tide-island** | quickshell island bar | Optional — flip with `SUPER+CTRL+ALT+T` |
| **waybar** | classic waybar | Optional — see below |

- `Refresh.sh` is shell-aware: only restarts the *currently running* shell, never spawns a bar that isn't selected
- Cycle shells: fury-bar → tide → waybar → fury-bar (binds around `binds.lua:199`)
- Stale session reaper at `hyprland.lua:196` kills mango/DMS leftovers so exactly ONE shell runs

### Waybar Setup
- Configs dir: `~/.config/waybar/configs/` (no file extension, e.g. `[TOP] Default`)
- Styles dir: `~/.config/waybar/style/` (`.css` files)
- Active symlinks: `~/.config/waybar/config.jsonc` + `config` → a config; `style.css` → a style
- **Current combo (backed up):** `[TOP & BOT] SummitSplit-glass` layout + `[Transparent] Crystal Clear.css` style
- Backup location: `~/.config/waybar/BACKUP-current/`
- **`SUPER+CTRL+B`** → `WaybarStyles.sh` — rofi menu of all styles (JaKooLit script)
- **`SUPER+ALT+B`** → `WaybarLayouts.sh` — rofi menu of all layouts (created 2026-09-08, mirrors JaKooLit menu style, marks current with 👉)
- Old cycling script `WaybarLayout.sh` still exists if sequential cycling is ever wanted back

---

## Key Mods (binds.lua)
- `SUPER+D` → Vicinae launcher (personalization)
- `SUPER+CTRL+B` / `SUPER+ALT+B` → waybar style / layout menus
- `SUPER+CTRL+ALT+T` → switch shell to tide-island
- Full JaKooLit keybind port — see `binds.lua` directly

## Misc
- Layout: dwindle · gaps 4/10 · animations = JaKooLit "ML4W - high" port (`hyprland.lua:116-133`)
- Autostart: hyprpolkitagent, hypridle, wallpaper (awww + random), vicinae server, wl-paste/cliphist, quickshell fury-bar, session glue
- Notifications: fury-bar registers org.freedesktop.Notifications itself — do NOT run swaync alongside it (D-Bus deadlock); only enable swaync if Tide Island becomes main
- NixOS: tide-island autostart is guarded by its NixOS module — disabling the module makes this line silently fail

---

## Maintenance Log

### 2026-09-08 — WiFi autoconnect fix
- Problem: PC kept randomly joining `Linksys00526` wifi after testing wifi in fury-bar
- Cause: NetworkManager profile had `connection.autoconnect: yes` (any wifi click in a bar saves a profile with autoconnect on)
- Fix: `nmcli connection modify "Linksys00526" connection.autoconnect no` + disconnected `wlp4s0`
- NOTE: if you intentionally want wifi later, either connect manually or re-enable: `nmcli connection modify "Linksys00526" connection.autoconnect yes`

### 2026-09-08 — Cherry-picked updates from KoolDots v2.3.26.3
- Source: `~/Downloads/Hyprland-Dots-Hyprland-Dots-v2.3.26.3` (new upstream = LinuxBeginnings/KoolDots, was JaKooLit)
- **WaybarCava.sh** — replaced with upstream v2.3.26.3 version. Fixes process leak: old script leaked cava processes on every waybar restart (had 19 stale cava+WaybarCava processes). New version: reaps stale cava by unique temp-conf pattern, cleanup trap kills children, no `exec` so trap can fire
- **hypridle.conf** — added `after_sleep_cmd = hyprctl dispatch dpms on` (upstream fix: screens sometimes stay off after suspend); changed `before_sleep_cmd` from `hyprlock --immediate` to `loginctl lock-session` (routes through lock_cmd which is the pidof-guarded hyprlock)
- **hyprlock.conf** — kept ours (custom Tokyo Night); upstream is stock wallust-themed, no fix we need
- **Not applied (irrelevant on this desktop):** touchpad detection, lid switch handling, keyboard backlight, laptop display profiles — this machine is a desktop (Razer peripherals, no lid/touchpad/kbd-backlight)
- Upstream restructured everything (new `lua/` module system, `hyprland.conf` entry) — NOT migrated; our single-file `hyprland.lua` + `binds.lua` stays
- Other script diffs were mostly license headers, `XDG_CONFIG_HOME` fallbacks, and features for hardware we don't have

---

*Last updated: 2026-09-08*
