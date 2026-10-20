# Free keybinds — Hyprland (fury) — generated 2026-10-10 from `dms/binds.lua` (159 binds)

> Regenerate: `rg -o 'hl\.bind\("([^"]+)"' dms/binds.lua | sort | uniq -c`.
> Source of truth: `dms/binds.lua` (active, DMS cheatsheet reads it) + `binds.lua` (retired archive).
> Hypr chord style is `SUPER + SHIFT + X` (spaces, uppercase). Mango equivalents in `~/.config/mango/config.conf`.

## SUPER (crowded — match Mango before adding)

Taken: `B C D E F G H I J K L M N O P Q R T V W X Y Z, S, U, 1-9, SPACE, Return, Tab, comma, period, semicolon, up/down/left/right, mouse:272/273, mouse_down/up (wheel hop)`

FREE: `A, 0, slash (/), apostrophe ('), minus (-), equal (=), bracketleft ([), bracketright (]), backslash (\), grave (` + `), Delete`

## SUPER+SHIFT (best layer for new binds)

Taken: `A B C F G H I J M N O P Q R S T U V X Y Z, Return, Tab, 1-9, period, bracketleft, bracketright, down/left/right/up, mouse:272`

FREE: `D, E, K, L, W, 0, comma (,), semicolon (;), slash (/), apostrophe ('), minus (-), equal (=), backslash (\), grave (`), SPACE`

> Vicinae now on `SUPER + ALT + SPACE` (153rd bind, 2026-09-25). DMS stays on `SUPER+SPACE`. Mango parity note: same chord is TAKEN in mango (`toggle_all_floating`) — Hypr-only for now.

## SUPER+CTRL

Taken: `A B D F H J K L O R, SPACE, Return, Tab, 1-9, bracketleft, bracketright, down/left/right/up`

FREE: `C, E, G, I, M, N, P, Q, S, T, U, V, W, X, Y, Z, 0, comma (,), period (.), semicolon (;), slash (/), apostrophe ('), minus (-), equal (=), backslash (\), grave (`)`

## SUPER+ALT (wide open)

Taken: `A C L O P S, SPACE (vicinae), comma, period, down/left/right/up, mouse_down/up (zoom)`

FREE: `B D E F G H I J K M N Q R T U V W X Y Z, Return, Tab, 0-9, semicolon (;), slash (/), apostrophe ('), minus (-), equal (=), brackets, backslash (\), grave (`)`

> Note: `SUPER+ALT+B` / `SUPER+CTRL+B` Waybar binds are commented out (Waybar breaks DMS binds). Treat as reserved, not free.

## Triple layers (nearly untouched)

- `SUPER+CTRL+SHIFT`: `A` (Fury Audio Studio), `R, S, Tab` taken — everything else free.
- `SUPER+ALT+SHIFT`: only `comma, period` taken — everything else free.
- `SUPER+CTRL+ALT`: only `B` taken (DMS bar toggle) — rest free.

## Other

- `F1-F12`: none bound — all free.
- `Print`: `Print / SHIFT+Print / ALT+Print` taken (DMS screenshot). `SUPER+Print`, `SUPER+CTRL+Print` etc retired — free.
- `ALT+Tab` taken (window cycle). Bare `ALT+letter` otherwise free but risky (apps use ALT). `ALT+SPACE` free (vicinae alt option).
- `CTRL+ALT+Delete` (exit), `CTRL+ALT+P` (powermenu) taken.
- `XF86` media/volume/brightness keys taken (Volume.sh / MediaCtrl.sh). `XF86MonBrightness*` free in Hypr (mango-only).
- `SUPER+wheel` (hop used workspaces), `SUPER+LMB/RMB` (drag/resize), `SUPER+SHIFT+LMB` (float) taken.

## Recommendations

1. `SUPER+SHIFT+<letter>` first (`D E K L W` free) — mirrors mango free-keybinds.
2. Keep mango/hypr parity: check both sheets before adding (e.g. `SUPER+ALT+SPACE` diverges).
3. `SUPER+slash` / `SUPER+apostrophe` for launcher-style popups.
