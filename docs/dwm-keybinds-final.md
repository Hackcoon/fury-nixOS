# dwm-keybinds-final — Fury DWM audit

> Date: 2026-09-24. Source of truth: `~/fury-dwm/suckless/dwm/config.h` (86 explicit binds + TAGKEYS ×12) + `~/.config/suckless/sxhkd/sxhkdrc` (52 hot-reload binds).
> `MODKEY` = SUPER. Rebuild after config.h edits: `make clean install` in `suckless/dwm` + `SUPER+SHIFT+R` (windows survive). sxhkd edits: `SUPER+Escape`.
> Live pair: installed `~/.config/suckless/dwm/config.h` verified identical to repo.

## config.h binds by section

### LAUNCH
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + Return` | `spawn` | `.v = termcmd` | !Terminal (kitty) |
| `SUPER + p` | `spawn` | `.v = dmenucmd` | dmenu_run |

### WINDOW
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + q` | `killclient` | `0` | !Close focused window |
| `SUPER + j` | `focusstack` | `.i = +1` | Focus next window |
| `SUPER + k` | `focusstack` | `.i = -1` | Focus previous window |
| `SUPER + Left` | `focusstack` | `.i = -1` | Focus previous window |
| `SUPER + Right` | `focusstack` | `.i = +1` | Focus next window |
| `SUPER + Up` | `focusstack` | `.i = -1` | Focus previous window |
| `SUPER + Down` | `focusstack` | `.i = +1` | Focus next window |
| `SUPER + SHIFT + j` | `movestack` | `.i = +1` | Move window down in stack |
| `SUPER + SHIFT + k` | `movestack` | `.i = -1` | Move window up in stack |
| `SUPER + SHIFT + Left` | `resizefocused` | `.f = -0.05` | Resize: shrink (matches Mango SHIFT+arrows) |
| `SUPER + SHIFT + Right` | `resizefocused` | `.f = +0.05` | Resize: grow |
| `SUPER + SHIFT + Up` | `resizefocused` | `.f = +0.05` | Resize: grow |
| `SUPER + SHIFT + Down` | `resizefocused` | `.f = -0.05` | Resize: shrink |
| `SUPER + Tab` | `view` | `0` | Toggle previous tag |
| `SUPER + SHIFT + f` | `fullscreen` | `0` | Toggle fullscreen |
| `SUPER + SHIFT + space` | `togglefloating` | `0` | Toggle floating |
| `SUPER + y` | `togglesticky` | `0` | Toggle sticky (show on all tags) |
| `SUPER + CTRL + n` | `togglefollow` | `0` | Toggle window-follow (moved for Mango SUPER+N notifications) |
| `SUPER + CTRL + b` | `togglebar` | `0` | Toggle bar |
| `SUPER + apostrophe` | `spawn` | `SHCMD("rofi -show window -theme \"$HOME/.config/suckles…` | Window switcher (rofi, all tags/monitors) |

### LAYOUT
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + h` | `spawn` | `SHCMD("$HOME/.config/suckless/scripts/help")` | !Keybind cheatsheet (matches Mango SUPER+H) |
| `SUPER + l` | `spawn` | `SHCMD("$HOME/.config/suckless/scripts/dwm-layout-menu.s…` | Layout menu (matches Mango SUPER+L) |
| `SUPER + CTRL + Left` | `movestack` | `.i = -1` | Swap with previous (matches Mango CTRL+arrows) |
| `SUPER + CTRL + Right` | `movestack` | `.i = +1` | Swap with next |
| `SUPER + CTRL + Up` | `movestack` | `.i = -1` | Swap with previous |
| `SUPER + CTRL + Down` | `movestack` | `.i = +1` | Swap with next |
| `SUPER + CTRL + space` | `togglefloating` | `0` | Float current (matches Mango SUPER+CTRL+Space) |
| `SUPER + semicolon` | `resetfacts` | `0` | Reset master + column factors |
| `SUPER + ALT + Tab` | `incnmaster` | `.i = +1` | Master count +1 |
| `SUPER + ALT + SHIFT + Tab` | `incnmaster` | `.i = -1` | Master count -1 |
| `ALT + Tab` | `focusstack` | `.i = +1` | Next window (matches Mango ALT+Tab) |
| `ALT + SHIFT + Tab` | `focusstack` | `.i = -1` | Previous window |
| `SUPER + i` | `incnmaster` | `.i = +1` | More masters (matches Mango SUPER+I) |
| `SUPER + SHIFT + i` | `incnmaster` | `.i = -1` | Fewer masters |
| `SUPER + CTRL + d` | `incnmaster` | `.i = -1` | Fewer masters (matches Mango SUPER+CTRL+D) |
| `SUPER + CTRL + Return` | `zoom` | `0` | Swap with master (matches Mango SUPER+CTRL+Return) |
| `SUPER + CTRL + f` | `setlayout` | `.v = &layouts[10]` | Monocle (matches Mango SUPER+CTRL+F maximize) |
| `CTRL + SHIFT + 1` | `setlayout` | `.v = &layouts[0]` | Layout: dwindle |
| `CTRL + SHIFT + 2` | `setlayout` | `.v = &layouts[1]` | Layout: tile |
| `CTRL + SHIFT + 3` | `setlayout` | `.v = &layouts[2]` | Layout: columns (cfact-weighted) |
| `CTRL + SHIFT + 4` | `setlayout` | `.v = &layouts[3]` | Layout: centered master |
| `CTRL + SHIFT + 5` | `setlayout` | `.v = &layouts[4]` | Layout: floating |
| `CTRL + SHIFT + 6` | `setlayout` | `.v = &layouts[5]` | Layout: bstack |
| `CTRL + SHIFT + 7` | `setlayout` | `.v = &layouts[6]` | Layout: nrowgrid |
| `CTRL + SHIFT + 8` | `setlayout` | `.v = &layouts[7]` | Layout: deck |
| `CTRL + SHIFT + 9` | `setlayout` | `.v = &layouts[8]` | Layout: gaplessgrid |
| `CTRL + SHIFT + 0` | `setlayout` | `.v = &layouts[9]` | Layout: spiral |
| `CTRL + SHIFT + minus` | `setlayout` | `.v = &layouts[10]` | Layout: monocle |
| `CTRL + SHIFT + equal` | `setlayout` | `.v = &layouts[11]` | Layout: grid |

### TAGS
| Chord | Function | Arg | Description |
|---|---|---|---|
| `CTRL + SHIFT + Left` | `viewtoleft` | `0` | View previous tag |
| `CTRL + SHIFT + Right` | `viewtoright` | `0` | View next tag |
| `SUPER + period` | `viewtoright` | `0` | Next tag (matches Mango SUPER+Period) |
| `SUPER + SHIFT + period` | `viewtoleft` | `0` | Previous tag |
| `SUPER + SHIFT + Tab` | `viewtoleft` | `0` | Previous tag (matches Mango SUPER+SHIFT+Tab) |
| `SUPER + SHIFT + bracketleft` | `tagtoleft` | `0` | Move window one tag left (matches Mango) |
| `SUPER + SHIFT + bracketright` | `tagtoright` | `0` | Move window one tag right |
| `CTRL + ALT + Left` | `tagtoleft` | `0` | Send window to previous tag |
| `CTRL + ALT + Right` | `tagtoright` | `0` | Send window to next tag |

### MONITOR
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + ALT + comma` | `focusmon` | `.i = -1` | Focus previous monitor (moved for Mango SUPER+Comma) |
| `SUPER + ALT + period` | `focusmon` | `.i = +1` | Focus next monitor |
| `SUPER + ALT + SHIFT + comma` | `tagmon` | `.i = -1` | Send window to previous monitor |
| `SUPER + ALT + SHIFT + period` | `tagmon` | `.i = +1` | Send window to next monitor |

### SCRATCHPAD
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + grave` | `togglescratch` | `.v = scratchpadcmd` | !Toggle scratchpad (kitty) |
| `SUPER + ALT + v` | `togglescratch` | `.v = pulsemixercmd` | Toggle pulsemixer (moved for Mango SUPER+V clipboard) |
| `SUPER + ALT + SHIFT + s` | `makescratchtagwin` | `.i = 's'` | Promote focused window to scratchpad |
| `SUPER + ALT + SHIFT + grave` | `makescratchtagwin` | `.i = 0` | Clear scratch state on focused window |

### GAPS
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + ALT + 0` | `togglegaps` | `0` | !Toggle gaps on/off |
| `SUPER + ALT + SHIFT + 0` | `defaultgaps` | `0` | Reset gaps to defaults |
| `SUPER + ALT + u` | `incrgaps` | `.i = 1` | Increase all gaps |
| `SUPER + ALT + SHIFT + u` | `incrgaps` | `.i = -1` | Decrease all gaps |
| `SUPER + ALT + i` | `incrigaps` | `.i = 1` | Increase inner gaps |
| `SUPER + ALT + SHIFT + i` | `incrigaps` | `.i = -1` | Decrease inner gaps |
| `SUPER + ALT + o` | `incrogaps` | `.i = 1` | Increase outer gaps |
| `SUPER + ALT + SHIFT + o` | `incrogaps` | `.i = -1` | Decrease outer gaps |
| `SUPER + ALT + 6` | `incrihgaps` | `.i = 1` | Inner horizontal gap +1 |
| `SUPER + ALT + SHIFT + 6` | `incrihgaps` | `.i = -1` | Inner horizontal gap -1 |
| `SUPER + ALT + 7` | `incrivgaps` | `.i = 1` | Inner vertical gap +1 |
| `SUPER + ALT + SHIFT + 7` | `incrivgaps` | `.i = -1` | Inner vertical gap -1 |
| `SUPER + ALT + 8` | `incrohgaps` | `.i = 1` | Outer horizontal gap +1 |
| `SUPER + ALT + SHIFT + 8` | `incrohgaps` | `.i = -1` | Outer horizontal gap -1 |
| `SUPER + ALT + 9` | `incrovgaps` | `.i = 1` | Outer vertical gap +1 |
| `SUPER + ALT + SHIFT + 9` | `incrovgaps` | `.i = -1` | Outer vertical gap -1 |

### SYSTEM
| Chord | Function | Arg | Description |
|---|---|---|---|
| `SUPER + SHIFT + r` | `quit` | `1` | !Restart dwm (preserves tags/windows) |
| `SUPER + CTRL + q` | `quit` | `0` | Quit dwm (moved for Mango SUPER+SHIFT+Q force-kill) |

## Tags 1-12 (TAGKEYS macro ×12: keys 1..9, 0, minus, equal)
| Chord family | Function | Effect |
|---|---|---|
| `SUPER + N` | view | view tag N |
| `SUPER + CTRL + N` | toggleview | toggle tag N visibility |
| `SUPER + SHIFT + N` | tag | send window to tag N |
| `SUPER + CTRL + SHIFT + N` | toggletag | toggle window on tag N |

## Mouse (buttons[])
| Click | Mod | Button | Function | Note |
|---|---|---|---|---|
| ClkLtSymbol | 0 | Button1 | `setlayout` |  |
| ClkLtSymbol | 0 | Button3 | `setlayout` |  |
| ClkFollowSymbol | 0 | Button1 | `togglefollow` |  |
| ClkWinTitle | 0 | Button2 | `zoom` |  |
| ClkStatusText | 0 | Button2 | `spawn` |  |
| ClkClientWin | MODKEY | Button1 | `dragswapmouse` |  |
| ClkClientWin | MODKEY|ShiftMask | Button1 | `movemouse` |  |
| ClkClientWin | MODKEY | Button2 | `togglefloating` |  |
| ClkClientWin | MODKEY | Button3 | `resizemouse` |  |
| ClkClientWin | MODKEY|ShiftMask | Button3 | `resizemousefloating` |  |
| ClkTagBar | 0 | Button1 | `view` |  |
| ClkTagBar | 0 | Button3 | `toggleview` |  |
| ClkTagBar | MODKEY | Button1 | `tag` |  |
| ClkTagBar | MODKEY | Button3 | `toggletag` |  |

## sxhkdrc binds (hot-reload, SUPER+Escape)
| Chord | Command | Note |
|---|---|---|
| `super + space` | `rofi -show drun -modi drun -line-padding 4 -hide-scrollbar -show-icons` | !Launch Rofi Application Menu (primary launcher) |
| `super + b` | `brave` | Launch Browser (Brave — native on X11, full WebGPU, no penalty) |
| `super + shift + b` | `firefox -private-window` | Launch Private Browser (Firefox private window) |
| `super + z` | `zen-beta` | Zen Browser (mango-ultimate-hotkeys.md parity: SUPER+Z) |
| `super + shift + g` | `brave-webgpu` | Brave WebGPU build (mango-ultimate-hotkeys.md parity: SUPER+SHIFT+G; SUPER+G stays GIMP in dwm) |
| `super + slash` | `~/.config/suckless/scripts/help` | Show Keybinding Help Script |
| `super + f` | `firefox` | Launch Firefox (matches Mango SUPER+F; Thunar moved to SUPER+E) |
| `super + e` | `thunar` | Launch Thunar (matches Mango SUPER+E; Geany moved to SUPER+SHIFT+E) |
| `super + shift + e` | `geany` | Launch Geany (moved for Mango chords) |
| `super + g` | `gimp` | Launch GIMP (Image Editor) |
| `super + c` | `codium` | Editor (VSCodium, ex-Helium slot — helium isn't packaged on NixOS) |
| `super + shift + c` | `brave --incognito` | Brave incognito (ex-Helium-incognito slot) |
| `super + k` | `qutebrowser` | qutebrowser (Mango SUPER+K) |
| `super + shift + v` | `kitty --class nvim -e nvim` | Neovim in kitty (Mango SUPER+SHIFT+V) |
| `super + shift + y` | `kitty --class superfile -e superfile` | Superfile (Mango SUPER+SHIFT+Y) |
| `super + shift + z` | `zen-beta --private-window` | Private Zen window (Mango SUPER+SHIFT+Z) |
| `super + d` | `dolphin` | Dolphin (ex-Discord slot — Discord via rofi; matches Mango SUPER+D habit) |
| `super + o` | `qs -p ~/.config/suckless/quickshell ipc call commands toggle` | Command menu (ex-OBS slot — matches Mango SUPER+O control-center habit; obs via rofi) |
| `super + y` | `kitty --class yazi -e yazi` | Yazi file manager (Mango SUPER+Y) |
| `super + t` | `qs -p ~/.config/suckless/quickshell ipc call wallpapers toggle` | Wallpaper picker alias on SUPER+T (matches Mango SUPER+T theme-toggle habit) |
| `super + alt + n` | `dunstctl set-paused toggle` | Do-not-disturb via dunst (ported from Mango SUPER+SHIFT+N; his SHIFT+N stays network app) |
| `super + ctrl + m` | `playerctl play-pause` | Media play/pause (ported from Mango SUPER+SHIFT+P; his SHIFT+P stays wallpaper picker) |
| `super + alt + l` | `slock` | Lock screen via slock (ported from Mango SUPER+ALT+L) |
| `super + w` | `qs -p ~/.config/suckless/quickshell ipc call wallpapers toggle` | Wallpaper Picker (matches Mango SUPER+W; also on SUPER+T and SUPER+SHIFT+P) |
| `super + shift + l` | `~/.config/suckless/scripts/dwm-layout-menu.sh` | DWM Layout Menu |
| `super + a` | `~/.config/suckless/scripts/dwm-layout-menu.sh` | Layout Menu alias on SUPER+A (matches Mango SUPER+A fave-layouts habit) |
| `super + comma` | `qs -p ~/.config/suckless/quickshell ipc call commands toggle` | Settings = Command Menu (matches Mango SUPER+Comma settings habit) |
| `super + m` | `kitty -e btop` | Process list (matches Mango SUPER+M) |
| `super + n` | `dunstctl history-pop` | Notifications history (matches Mango SUPER+N panel habit) |
| `super + v` | `~/.config/suckless/scripts/clip-menu` | Clipboard history (matches Mango SUPER+V; pulsemixer moved to SUPER+ALT+V) |
| `super + shift + q` | `xkill` | Force-kill window (matches Mango SUPER+SHIFT+Q; quit moved to SUPER+CTRL+Q) |
| `super + shift + p` | `qs -p ~/.config/suckless/quickshell ipc call wallpapers toggle` | Wallpaper Picker (re-themes the desktop from the image) |
| `super + shift + m` | `qs -p ~/.config/suckless/quickshell ipc call commands toggle` | Command Menu (bar popup of shell actions) |
| `super + shift + n` | `~/.config/suckless/scripts/network` | Network app (super+n is dwm's window-follow toggle) |
| `super + alt + w` | `~/.config/suckless/dwm/dwmtabs attach` | Tab attach: focused window into a tab group on this monitor (moved for Mango SUPER+W wallpaper) |
| `super + shift + w` | `~/.config/suckless/dwm/dwmtabs detach` | Tab detach: focused window out of its tab group |
| `super + F12` | `~/.config/suckless/scripts/changevolume up` | Increase Volume (Custom Script) |
| `super + F11` | `~/.config/suckless/scripts/changevolume down` | Decrease Volume (Custom Script) |
| `super + F10` | `~/.config/suckless/scripts/changevolume mute` | Toggle Mute (Custom Script) |
| `XF86AudioRaiseVolume` | `~/.config/suckless/scripts/changevolume up` | Dedicated Key for Volume Up |
| `XF86AudioLowerVolume` | `~/.config/suckless/scripts/changevolume down` | Dedicated Key for Volume Down |
| `XF86AudioMute` | `~/.config/suckless/scripts/changevolume mute` | Dedicated Key for Mute |
| `XF86MonBrightnessUp` | `xbacklight +10` | Increase Screen Brightness |
| `XF86MonBrightnessDown` | `xbacklight -10` | Decrease Screen Brightness |
| `super + s` | `flameshot gui --clipboard --path ~/Screenshots/` | BACKUP (ignored comment, file-only): flameshot gui --path ~/Screenshots/ |
| `super + shift + s` | `flameshot full --clipboard --path ~/Screenshots/` | BACKUP (ignored comment, file-only): flameshot full --path ~/Screenshots/ |
| `Print` | `flameshot full --clipboard --path ~/Screenshots/` | BACKUP (ignored comment, old file-only): flameshot full --path ~/Screenshots/ and flameshot gui --path ~/Screenshots/ |
| `shift + Print` | `flameshot gui --clipboard --path ~/Screenshots/` |  |
| `alt + Print` | `flameshot full --clipboard --path ~/Screenshots/` |  |
| `super + Escape` | `pkill -USR1 -x sxhkd; notify-send 'sxhkd' 'Reloaded config'` | Reload sxhkd (Hotkey Daemon) |
| `super + ctrl + r` | `~/.config/suckless/scripts/bar restart` | Restart the quickshell bar (recovery; super+shift+r restarts dwm) |
| `super + x` | `~/.config/suckless/scripts/power` | Power Off/Reboot |
