# hyprland-keys-final — Fury Hyprland audit

> Date: 2026-09-24 (v3 — regenerated live; supersedes `~/hyprland-keys-final.md` v2).
> Source of truth: `~/.config/hypr/dms/binds.lua` (DMS cheatsheet slot, `require`d by `hyprland.lua`) + `binds.lua` (retired archive) + `hyprland.lua` (env/autostart/rules).
> Mango config untouched throughout. Apply = save file (Hyprland hot-reloads; full `hyprctl reload` if stacked).


## Standard
| Chord | Action | Note |
|---|---|---|
| `SUPER + D` | `hl.dsp.exec_cmd("dolphin")` | file manager Dolphin (Mango chord) |
| `SUPER + B` | `hl.dsp.exec_cmd('xdg-open "https://"')` | default browser homepage (Brave) |
| `SUPER + C` | `hl.dsp.exec_cmd("codium")` | editor VSCodium (Mango chord) |
| `SUPER + Return` | `hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf")` | terminal kitty (wallust overlay, Hyprland-only) |
| `SUPER + SHIFT + Return` | `hl.dsp.workspace.toggle_special("scratch-term")` | dropdown scratchpad native (kitty auto-spawns via workspace rule) |
| `SUPER + E` | `hl.dsp.exec_cmd("thunar")` | file manager Thunar |
| `SUPER + SPACE` | `hl.dsp.exec_cmd("dms ipc call spotlight toggle")` | DMS launcher / spotlight |
| `SUPER + F` | `hl.dsp.exec_cmd("firefox")` | browser Firefox (Mango chord) |
| `SUPER + Z` | `hl.dsp.exec_cmd("zen-beta")` | Zen Browser (Mango chord) |
| `SUPER + SHIFT + Z` | `hl.dsp.exec_cmd("zen-beta --private-window")` | private Zen window (Mango chord) |
| `SUPER + K` | `hl.dsp.exec_cmd("qutebrowser")` | keyboard-driven browser (Mango chord) |
| `SUPER + SHIFT + V` | `hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class nvi…` | Neovim in Kitty (Mango chord) |
| `SUPER + Y` | `hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class yaz…` | Yazi file manager (Mango chord) |
| `SUPER + SHIFT + Y` | `hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class sup…` | Superfile manager (Mango chord) |
| `SUPER + SHIFT + B` | `hl.dsp.exec_cmd("brave --incognito")` | private Brave window (Mango chord) |
| `SUPER + SHIFT + H` | `hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/mango/zsh-aliases.sh")` | zsh aliases list (Mango chord+script, read-only use) |

## Features / Extras
| Chord | Action | Note |
|---|---|---|
| `SUPER + T` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ThemeChanger.sh")` | global theme switcher wallust |
| `SUPER + H` | `hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland")` | DMS keybind cheatsheet |
| `SUPER + semicolon` | `hl.dsp.exec_cmd('dms ipc call spotlight toggleQuery ":e "')` | DMS emoji picker (needs emojiLauncher plugin) |
| `SUPER + SHIFT + C` | `hl.dsp.exec_cmd("dms ipc call color-picker toggle")` | DMS color picker (Mango chord) |
| `SUPER + SHIFT + R` | `hl.dsp.exec_cmd("bash -c 'hyprctl reload && notify-send \"Hyprland\" \"Config reloaded\"'"…` | reload Hyprland config (Mango chord) |
| `SUPER + R` | `hl.dsp.exec_cmd("bash -c 'D=$(command -v dms); notify-send \"DMS\" \"Restarting shell\"; p…` | restart DMS shell (Mango chord; bar blinks, windows stay) |
| `SUPER + O` | `hl.dsp.exec_cmd("dms ipc call control-center toggle")` | DMS control center (Mango chord) |
| `SUPER + ALT + O` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ChangeBlur.sh")` | toggle blur (kept Hyprland) |
| `SUPER + SHIFT + G` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/GameMode.sh")` | game mode toggle |
| `SUPER + L` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ChangeLayout.sh")` | cycle Hyprland layouts (Mango chord) |
| `SUPER + V` | `hl.dsp.exec_cmd("dms ipc call clipboard toggle")` | DMS clipboard history (Mango chord) |
| `SUPER + CTRL + R` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/RofiThemeSelector.sh")` | rofi theme selector (undecided) |
| `SUPER + CTRL + SHIFT + R` | `hl.dsp.exec_cmd("bash -c 'pkill rofi || true && /home/fury/.config/hypr/scripts/RofiThemeS…` | rofi theme selector alt (undecided) |
| `SUPER + SHIFT + F` | `hl.dsp.window.fullscreen()` | fullscreen toggle |
| `SUPER + CTRL + F` | `hl.dsp.window.fullscreen({ mode = "maximized" })` | maximize keep bar/border |
| `SUPER + CTRL + SPACE` | `hl.dsp.window.float()` | float current window (Mango chord) |
| `SUPER + ALT + mouse_down` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ZoomIn.sh")` | zoom in (kept Hyprland) |
| `SUPER + ALT + mouse_up` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ZoomOut.sh")` | zoom out (kept Hyprland) |

## Dms Notifications
| Chord | Action | Note |
|---|---|---|
| `SUPER + N` | `hl.dsp.exec_cmd("dms ipc call notifications toggle")` | DMS notifications panel (Mango chord) |
| `SUPER + CTRL + B` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/WaybarStyles.sh")` | waybar styles menu |
| `SUPER + ALT + B` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/WaybarLayouts.sh")` | waybar layout menu |

## Userscripts
| Chord | Action | Note |
|---|---|---|
| `SUPER + W` | `hl.dsp.exec_cmd("dms ipc call dankdash wallpaper")` | DMS wallpaper switcher (Mango chord) |
| `SUPER + CTRL + O` | `hl.dsp.window.set_prop({ prop = "opacity", value = "1 1 toggle" })` | active window opaque toggle |
| `SUPER + SHIFT + A` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AnimationsMenu.sh")` | animations menu |
| `SUPER + ALT + A` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AnimationsPreset.sh")` | animation STYLE presets (ported Hyprland-Dots) |
| `SUPER + SHIFT + O` | `hl.dsp.exec_cmd("bash -c 'systemctl --user restart xdg-desktop-portal xdg-desktop-portal-w…` | restart portals screenshare fix (Mango chord) |
| `SUPER + ALT + C` | `hl.dsp.exec_cmd("qalculate-qt")` | calculator Qalculate (floating rule in hyprland.lua) |
| `SUPER + comma` | `hl.dsp.exec_cmd("dms ipc call settings focusOrToggle")` | DMS settings (Mango chord) |
| `SHIFT_L + ALT_L` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"), { ignore_mod…` | per-window layout switch |

## System
| Chord | Action | Note |
|---|---|---|
| `CTRL + ALT + Delete` | `hl.dsp.exit()` | exit Hyprland |
| `SUPER + Q` | `hl.dsp.window.close()` | close window |
| `SUPER + SHIFT + Q` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/KillActiveProcess.sh")` | force kill SIGKILL script |
| `SUPER + ALT + L` | `hl.dsp.exec_cmd("/run/current-system/sw/bin/hyprlock")` | hyprlock (DMS lock renders nothing on Hyprland; see notes) |
| `CTRL + ALT + P` | `hl.dsp.exec_cmd("dms ipc call powermenu toggle")` | DMS power menu |
| `SUPER + X` | `hl.dsp.exec_cmd("dms ipc call powermenu toggle")` | DMS power menu quick (Mango chord) |
| `SUPER + SHIFT + N` | `hl.dsp.exec_cmd("dms ipc call notifications toggleDoNotDisturb")` | DMS do-not-disturb toggle (Mango chord) |

## Master / Dwindle
| Chord | Action | Note |
|---|---|---|
| `SUPER + CTRL + D` | `hl.dsp.layout("removemaster")` | fewer masters |
| `SUPER + I` | `hl.dsp.layout("addmaster")` | more masters |
| `SUPER + CTRL + Return` | `hl.dsp.layout("swapwithmaster")` | swap with master |
| `SUPER + SHIFT + I` | `hl.dsp.layout("togglesplit")` | toggle dwindle split |
| `SUPER + P` | `hl.dsp.exec_cmd("dms ipc call powerprofile cycle")` | DMS power profile cycle (Mango chord) |
| `SUPER + M` | `hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle")` | DMS process list (Mango chord) |

## Group
| Chord | Action | Note |
|---|---|---|
| `SUPER + G` | `hl.dsp.group.toggle()` | toggle group (kept Hyprland) |
| `SUPER + CTRL + Tab` | `hl.dsp.group.next()` | next group member (Mango chord) |
| `SUPER + CTRL + SHIFT + Tab` | `hl.dsp.group.prev()` | prev group member (Mango chord) |
| `SUPER + CTRL + K` | `hl.dsp.window.move({ into_group = "left" })` | move into group left |
| `SUPER + CTRL + L` | `hl.dsp.window.move({ into_group = "right" })` | move into group right |
| `SUPER + CTRL + H` | `hl.dsp.window.move({ out_of_group = true })` | leave group |
| `ALT + Tab` | `function(` | cycle windows next + raise |

## Media / Function Keys
| Chord | Action | Note |
|---|---|---|
| `SUPER + SHIFT + P` | `hl.dsp.exec_cmd("dms ipc call mpris playPause")` | DMS media play/pause (Mango chord) |
| `XF86AudioRaiseVolume` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --inc"), { repeating = true, lo…` | volume up |
| `XF86AudioLowerVolume` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --dec"), { repeating = true, lo…` | volume down |
| `ALT + XF86AudioRaiseVolume` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --inc-precise"), { repeating = …` | precise volume up |
| `ALT + XF86AudioLowerVolume` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --dec-precise"), { repeating = …` | precise volume down |
| `XF86AudioMicMute` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --toggle-mic"), { locked = true…` | mic mute toggle |
| `XF86AudioMute` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --toggle"), { locked = true }` | output mute toggle |
| `XF86Sleep` | `hl.dsp.exec_cmd("systemctl suspend"), { locked = true }` | suspend |
| `XF86RFKill` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AirplaneMode.sh"), { locked = true }` | airplane mode toggle |
| `XF86AudioPause` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true }` | media play/pause key |
| `XF86AudioPlay` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true }` | media play/pause key alt keysym |
| `XF86AudioNext` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --nxt"), { locked = true }` | next track |
| `XF86AudioPrev` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --prv"), { locked = true }` | prev track |
| `XF86AudioStop` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --stop"), { locked = true }` | stop track |
| `SUPER + S` | `hl.dsp.exec_cmd("bash -c 'dms screenshot --stdout --no-file --no-clipboard --no-notify | s…` | region select to satty (Mango chord) |
| `SUPER + ALT + S` | `hl.dsp.exec_cmd("bash -c '/run/current-system/sw/bin/hyprlock & sleep 2; systemctl suspend…` | lock-then-suspend via hyprlock (deterministic) |
| `SUPER + SHIFT + S` | `hl.dsp.exec_cmd("bash -c 'dms screenshot window --stdout --no-file --no-clipboard --no-not…` | focused window to satty (Mango chord) |
| `SUPER + CTRL + SHIFT + S` | `hl.dsp.exec_cmd("bash -c 'dms screenshot full --stdout --no-file --no-clipboard --no-notif…` | fullscreen to satty (Mango 3rd bind) |
| `SHIFT + Print` | `hl.dsp.exec_cmd("dms screenshot")` | quick region save (Mango chord) |
| `ALT + Print` | `hl.dsp.exec_cmd("dms screenshot window")` | quick window save |
| `Print` | `hl.dsp.exec_cmd("dms screenshot full")` | quick fullscreen save |
| `SUPER + left` | `hl.dsp.focus({ direction = "left" })` | focus left |
| `SUPER + right` | `hl.dsp.focus({ direction = "right" })` | focus right |
| `SUPER + up` | `hl.dsp.focus({ direction = "up" })` | focus up |
| `SUPER + down` | `hl.dsp.focus({ direction = "down" })` | focus down |
| `SUPER + CTRL + left` | `hl.dsp.window.swap({ direction = "left" })` | swap tiled left (Mango exchange) |
| `SUPER + CTRL + right` | `hl.dsp.window.swap({ direction = "right" })` | swap tiled right (Mango exchange) |
| `SUPER + CTRL + up` | `hl.dsp.window.swap({ direction = "up" })` | swap tiled up (Mango exchange) |
| `SUPER + CTRL + down` | `hl.dsp.window.swap({ direction = "down" })` | swap tiled down (Mango exchange) |
| `SUPER + ALT + left` | `hl.dsp.window.move({ direction = "left" })` | move floating left (Mango smartmovewin) |
| `SUPER + ALT + right` | `hl.dsp.window.move({ direction = "right" })` | move floating right (Mango smartmovewin) |
| `SUPER + ALT + up` | `hl.dsp.window.move({ direction = "up" })` | move floating up (Mango smartmovewin) |
| `SUPER + ALT + down` | `hl.dsp.window.move({ direction = "down" })` | move floating down (Mango smartmovewin) |
| `SUPER + SHIFT + left` | `hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true }` | resize left 50px |
| `SUPER + SHIFT + right` | `hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true }` | resize right 50px |
| `SUPER + SHIFT + up` | `hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true }` | resize up 50px |
| `SUPER + SHIFT + down` | `hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true }` | resize down 50px |
| `SUPER + mouse:272` | `hl.dsp.window.drag(), { mouse = true }` | LMB drag: tiled swaps on drop, floating moves (Mango curmove) |
| `SUPER + mouse:273` | `hl.dsp.window.resize(), { mouse = true }` | RMB drag resize |
| `SUPER + SHIFT + mouse:272` | `hl.dsp.window.float(), { mouse = true }` | SHIFT+click floats in place, then drag to move (Mango togglefloating) |
| `SUPER + Tab` | `function() hop_used(1) end` | next USED workspace (Mango have_client) |
| `SUPER + SHIFT + Tab` | `function() hop_used(-1) end` | prev USED workspace (Mango have_client) |
| `SUPER + SHIFT + U` | `hl.dsp.window.move({ workspace = "special" })` | send window to special (silent, like Mango CTRL+U) |
| `SUPER + U` | `hl.dsp.workspace.toggle_special()` | special workspace overlay |
| `SUPER + J` | `hl.dsp.workspace.toggle_special("scratchpad")` | scratch view: own NAMED space, distinct from U (Mango chord) |
| `SUPER + SHIFT + J` | `hl.dsp.window.move({ workspace = "special:scratchpad" })` | send to scratch space (Mango chord) |
| `SUPER + CTRL + J` | `hl.dsp.workspace.toggle_special("scratchpad")` | re-open scratch space (Mango restore chord) |
| `SUPER + 1` | `hl.dsp.focus({ workspace = "1" })` | view tag 1 |
| `SUPER + SHIFT + 1` | `hl.dsp.window.move({ workspace = "1", follow = true })` | send follow tag 1 |
| `SUPER + CTRL + 1` | `hl.dsp.window.move({ workspace = "1" })` | send silent tag 1 |
| `SUPER + 2` | `hl.dsp.focus({ workspace = "2" })` | view tag 2 |
| `SUPER + SHIFT + 2` | `hl.dsp.window.move({ workspace = "2", follow = true })` | send follow tag 2 |
| `SUPER + CTRL + 2` | `hl.dsp.window.move({ workspace = "2" })` | send silent tag 2 |
| `SUPER + 3` | `hl.dsp.focus({ workspace = "3" })` | view tag 3 |
| `SUPER + SHIFT + 3` | `hl.dsp.window.move({ workspace = "3", follow = true })` | send follow tag 3 |
| `SUPER + CTRL + 3` | `hl.dsp.window.move({ workspace = "3" })` | send silent tag 3 |
| `SUPER + 4` | `hl.dsp.focus({ workspace = "4" })` | view tag 4 |
| `SUPER + SHIFT + 4` | `hl.dsp.window.move({ workspace = "4", follow = true })` | send follow tag 4 |
| `SUPER + CTRL + 4` | `hl.dsp.window.move({ workspace = "4" })` | send silent tag 4 |
| `SUPER + 5` | `hl.dsp.focus({ workspace = "5" })` | view tag 5 |
| `SUPER + SHIFT + 5` | `hl.dsp.window.move({ workspace = "5", follow = true })` | send follow tag 5 |
| `SUPER + CTRL + 5` | `hl.dsp.window.move({ workspace = "5" })` | send silent tag 5 |
| `SUPER + 6` | `hl.dsp.focus({ workspace = "6" })` | view tag 6 |
| `SUPER + SHIFT + 6` | `hl.dsp.window.move({ workspace = "6", follow = true })` | send follow tag 6 |
| `SUPER + CTRL + 6` | `hl.dsp.window.move({ workspace = "6" })` | send silent tag 6 |
| `SUPER + 7` | `hl.dsp.focus({ workspace = "7" })` | view tag 7 |
| `SUPER + SHIFT + 7` | `hl.dsp.window.move({ workspace = "7", follow = true })` | send follow tag 7 |
| `SUPER + CTRL + 7` | `hl.dsp.window.move({ workspace = "7" })` | send silent tag 7 |
| `SUPER + 8` | `hl.dsp.focus({ workspace = "8" })` | view tag 8 |
| `SUPER + SHIFT + 8` | `hl.dsp.window.move({ workspace = "8", follow = true })` | send follow tag 8 |
| `SUPER + CTRL + 8` | `hl.dsp.window.move({ workspace = "8" })` | send silent tag 8 |
| `SUPER + 9` | `hl.dsp.focus({ workspace = "9" })` | view tag 9 |
| `SUPER + SHIFT + 9` | `hl.dsp.window.move({ workspace = "9", follow = true })` | send follow tag 9 |
| `SUPER + CTRL + 9` | `hl.dsp.window.move({ workspace = "9" })` | send silent tag 9 |
| `SUPER + SHIFT + bracketleft` | `hl.dsp.window.move({ workspace = "previous" })` | move window previous (closest to Mango tag-left) |
| `SUPER + SHIFT + bracketright` | `hl.dsp.window.move({ workspace = "m+1" })` | move window next (closest to Mango tag-right) |
| `SUPER + CTRL + bracketleft` | `hl.dsp.window.move({ workspace = "previous" })` | move window previous dup mod |
| `SUPER + CTRL + bracketright` | `hl.dsp.window.move({ workspace = "m+1" })` | move window next dup mod |
| `SUPER + mouse_down` | `function() hop_used(1) end` | wheel down: next USED workspace |
| `SUPER + mouse_up` | `function() hop_used(-1) end` | wheel up: prev USED workspace |
| `SUPER + period` | `hl.dsp.focus({ workspace = "e+1" })` | cycle forward (Mango next) |
| `SUPER + SHIFT + period` | `hl.dsp.focus({ workspace = "e-1" })` | cycle back (Mango prev) |
| `SUPER + CTRL + ALT + B` | `hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ToggleDmsBar.sh")` | hide/show DMS bar (Mango chord+script) |
| `SUPER + ALT + comma` | `hl.dsp.focus({ monitor = "left" })` | focus prev monitor (Mango chord) |
| `SUPER + ALT + period` | `hl.dsp.focus({ monitor = "right" })` | focus next monitor (Mango chord) |
| `SUPER + ALT + SHIFT + comma` | `hl.dsp.workspace.move({ monitor = "left" })` | send workspace to prev monitor (Mango tagmon) |
| `SUPER + ALT + SHIFT + period` | `hl.dsp.workspace.move({ monitor = "right" })` | send workspace to next monitor (Mango tagmon) |

## Retired (55 in binds.lua RETIRED block, restorable)
Retired highlights: vicinae/rofi launchers, KeyHints/Keybinds.sh, fury-bar IPCs, Tide 10×, Waybar (later restored? no — restored to dms slot), wallpaper scripts, RofiBeats, zsh-theme, ws10 trio, group-Tab pair, float-ALL (no API), Dropterminal (native scratch-term wins), ScreenShot.sh family, global kbd switch, monitor F9-12, comma-workspace, ALT+C rofi calc, Print-delay shots.
