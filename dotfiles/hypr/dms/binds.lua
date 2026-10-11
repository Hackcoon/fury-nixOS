-- ============================================================================
-- ~/.config/hypr/dms/binds.lua — DMS-managed keybind slot (Hyprland provider)
-- Generated 2026-09-23 from vault hyprland-keys-final §§1-9 (Mango chords,
-- Hyprland-native actions, DMS shell IPCs). Required from hyprland.lua via
-- require("dms.binds") — cheatsheet (`dms ipc call keybinds toggle hyprland`,
-- SUPER+H) reads THIS file. DMS Settings edits land here too.
-- Self-contained: no helpers from binds.lua (chords/paths expanded).
-- binds-user.lua stays free for future personal overrides.
-- ============================================================================

-- ═══════════════════════════ STANDARD ═══════════════════════════
hl.bind("SUPER + D", hl.dsp.exec_cmd("dolphin")) -- file manager Dolphin (Mango chord)
hl.bind("SUPER + B", hl.dsp.exec_cmd("brave-fast")) -- Brave Fast daily driver (native Wayland, no WebGPU)
hl.bind("SUPER + C", hl.dsp.exec_cmd("codium")) -- editor VSCodium (Mango chord)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf")) -- terminal kitty (wallust overlay, Hyprland-only)
hl.bind("SUPER + SHIFT + Return", hl.dsp.workspace.toggle_special("scratch-term")) -- dropdown scratchpad native (kitty auto-spawns via workspace rule)
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar")) -- file manager Thunar
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("dms ipc call spotlight toggle")) -- DMS launcher / spotlight

-- ═══════════════════════════ APPS (Mango row) ═══════════════════════════
hl.bind("SUPER + F", hl.dsp.exec_cmd("firefox")) -- browser Firefox (Mango chord)
hl.bind("SUPER + Z", hl.dsp.exec_cmd("zen-beta")) -- Zen Browser (Mango chord)
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd("zen-beta --private-window")) -- private Zen window (Mango chord)
hl.bind("SUPER + K", hl.dsp.exec_cmd("qutebrowser")) -- keyboard-driven browser (Mango chord)
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class nvim -e nvim")) -- Neovim in Kitty (Mango chord)
hl.bind("SUPER + Y", hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class yazi -e yazi")) -- Yazi file manager (Mango chord)
hl.bind("SUPER + SHIFT + Y", hl.dsp.exec_cmd("kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class superfile -e superfile")) -- Superfile manager (Mango chord)
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("brave-fast --incognito")) -- private Brave Fast window
hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/mango/zsh-aliases.sh")) -- zsh aliases list (Mango chord+script, read-only use)

-- ═══════════════════════ FEATURES / EXTRAS ═══════════════════════
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ThemeChanger.sh")) -- global theme switcher wallust
hl.bind("SUPER + H", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland")) -- DMS keybind cheatsheet
hl.bind("SUPER + semicolon", hl.dsp.exec_cmd('dms ipc call spotlight toggleQuery ":e "')) -- DMS emoji picker (needs emojiLauncher plugin)
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("dms ipc call color-picker toggle")) -- DMS color picker (Mango chord)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("bash -c 'hyprctl reload && notify-send \"Hyprland\" \"Config reloaded\"'")) -- reload Hyprland config (Mango chord)
hl.bind("SUPER + R", hl.dsp.exec_cmd("bash -c 'D=$(command -v dms); notify-send \"DMS\" \"Restarting shell\"; pkill -f \"dms ru[n]\"; sleep 1; setsid $D run >>/tmp/dms-hyprland.log 2>&1 < /dev/null'")) -- restart DMS shell (Mango chord; bar blinks, windows stay)
hl.bind("SUPER + O", hl.dsp.exec_cmd("dms ipc call control-center toggle")) -- DMS control center (Mango chord)
hl.bind("SUPER + ALT + O", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ChangeBlur.sh")) -- toggle blur (kept Hyprland)
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/GameMode.sh")) -- game mode toggle
hl.bind("SUPER + L", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ChangeLayout.sh")) -- cycle Hyprland layouts (Mango chord)
hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle")) -- DMS clipboard history (Mango chord)
hl.bind("SUPER + CTRL + R", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/RofiThemeSelector.sh")) -- rofi theme selector (undecided)
hl.bind("SUPER + CTRL + SHIFT + R", hl.dsp.exec_cmd("bash -c 'pkill rofi || true && /home/fury/.config/hypr/scripts/RofiThemeSelector-modified.sh'")) -- rofi theme selector alt (undecided)
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen()) -- fullscreen toggle
hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" })) -- maximize keep bar/border
hl.bind("SUPER + CTRL + SPACE", hl.dsp.window.float()) -- float current window (Mango chord)
hl.bind("SUPER + ALT + P", hl.dsp.window.pin()) -- PiP stick toggle: follow workspaces or stay put (Mango toggleglobal parity)
-- VICINAE secondary launcher — to disable: comment the next line, `hyprctl reload`
hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("vicinae toggle")) -- Vicinae secondary launcher (DMS stays on SUPER+SPACE; float-ALL retired)
-- (SUPER+ALT+SPACE float-ALL retired — hyprctl dispatch workspaceopt is broken
-- in this build and Lua API has no float-all; use CTRL+SPACE per window; see RETIRED)
hl.bind("SUPER + ALT + mouse_down", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ZoomIn.sh")) -- zoom in (kept Hyprland)
hl.bind("SUPER + ALT + mouse_up", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ZoomOut.sh")) -- zoom out (kept Hyprland)

-- ═══════════════════════ DMS NOTIFICATIONS ═══════════════════════
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notifications toggle")) -- DMS notifications panel (Mango chord)

-- ═══════════════════════ WAYBAR (commented 2026-09-24: Waybar running breaks DMS binds; restore to use) ═══════════════════════
-- hl.bind("SUPER + CTRL + B", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/WaybarStyles.sh")) -- waybar styles menu
-- hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/WaybarLayouts.sh")) -- waybar layout menu

-- ═══════════════════════ USERSCRIPTS ═══════════════════════
hl.bind("SUPER + W", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper")) -- DMS wallpaper switcher (Mango chord)
hl.bind("SUPER + CTRL + O", hl.dsp.window.set_prop({ prop = "opacity", value = "1 1 toggle" })) -- active window opaque toggle
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AnimationsMenu.sh")) -- animations menu
hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AnimationsPreset.sh")) -- animation STYLE presets (ported Hyprland-Dots)
hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("bash -c 'systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr && notify-send \"Portals\" \"ScreenCast restarted — retry sharing\"'")) -- restart portals screenshare fix (Mango chord)
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("qalculate-qt")) -- calculator Qalculate (floating rule in hyprland.lua)
hl.bind("SUPER + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle")) -- DMS settings (Mango chord)
hl.bind("SHIFT_L + ALT_L", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"), { ignore_mods = true }) -- per-window layout switch

-- ═══════════════════════ SYSTEM ═══════════════════════
hl.bind("CTRL + ALT + Delete", hl.dsp.exit()) -- exit Hyprland
hl.bind("SUPER + Q", hl.dsp.window.close()) -- close window
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/KillActiveProcess.sh")) -- force kill SIGKILL script
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("bash -c 'pidof hyprlock >/dev/null || exec /run/current-system/sw/bin/hyprlock'")) -- hyprlock, singleton-guarded (no stacking)
hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd("dms ipc call powermenu toggle")) -- DMS power menu
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle")) -- DMS power menu quick (Mango chord)
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notifications toggleDoNotDisturb")) -- DMS do-not-disturb toggle (Mango chord)

-- ═══════════════════ MASTER / DWINDLE ═══════════════════
hl.bind("SUPER + CTRL + D", hl.dsp.layout("removemaster")) -- fewer masters
hl.bind("SUPER + I", hl.dsp.layout("addmaster")) -- more masters
hl.bind("SUPER + CTRL + Return", hl.dsp.layout("swapwithmaster")) -- swap with master
hl.bind("SUPER + SHIFT + I", hl.dsp.layout("togglesplit")) -- toggle dwindle split

-- ═══════════════════ SCROLLING (WS1 filmstrip) — trial 2026-10-10 ═══════════════════
-- Mouse drag in scrolling always splits up/down (upstream #14274), so use these
-- instead of dragging. No-ops on dwindle/master workspaces. REVERT: delete the
-- 3 lines below + `hyprctl reload` (backup: binds.lua.pre-scrolling-binds-20261010).
hl.bind("SUPER + CTRL + P", hl.dsp.layout("promote")) -- pop window into its own column
hl.bind("SUPER + CTRL + comma", hl.dsp.layout("swapcol l")) -- swap column left
hl.bind("SUPER + CTRL + period", hl.dsp.layout("swapcol r")) -- swap column right
hl.bind("SUPER + P", hl.dsp.exec_cmd("dms ipc call powerprofile cycle")) -- DMS power profile cycle (Mango chord)
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle")) -- DMS process list (Mango chord)

-- ═════════════════ GROUP ═══════════════════
hl.bind("SUPER + G", hl.dsp.group.toggle()) -- toggle group (kept Hyprland)
hl.bind("SUPER + CTRL + Tab", hl.dsp.group.next()) -- next group member (Mango chord)
hl.bind("SUPER + CTRL + SHIFT + Tab", hl.dsp.group.prev()) -- prev group member (Mango chord)
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ into_group = "left" })) -- move into group left
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ into_group = "right" })) -- move into group right
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ out_of_group = true })) -- leave group
hl.bind("ALT + Tab", function() -- cycle windows next + raise
  hl.dispatch(hl.dsp.window.cycle_next())
  hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- ═════════════════ MEDIA / FUNCTION KEYS ═══════════════════
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("dms ipc call mpris playPause")) -- DMS media play/pause (Mango chord)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --inc"), { repeating = true, locked = true }) -- volume up
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --dec"), { repeating = true, locked = true }) -- volume down
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --inc-precise"), { repeating = true, locked = true }) -- precise volume up
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --dec-precise"), { repeating = true, locked = true }) -- precise volume down
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --toggle-mic"), { locked = true }) -- mic mute toggle
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/Volume.sh --toggle"), { locked = true }) -- output mute toggle
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), { locked = true }) -- suspend
hl.bind("XF86RFKill", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/AirplaneMode.sh"), { locked = true }) -- airplane mode toggle
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true }) -- media play/pause key
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true }) -- media play/pause key alt keysym
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --nxt"), { locked = true }) -- next track
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --prv"), { locked = true }) -- prev track
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/MediaCtrl.sh --stop"), { locked = true }) -- stop track

-- ═════════════════ FURY AUDIO STUDIO (NixOS module services.fury-audio-studio) ═════════════════
hl.bind("SUPER + CTRL + A", hl.dsp.exec_cmd("fury-audio-studio --gui-only")) -- open Fury Audio Studio window (settings only, no forced DSP start)
hl.bind("SUPER + CTRL + SHIFT + A", hl.dsp.exec_cmd("fury-audio-studio --toggle")) -- toggle Fury voice DSP on/off (notifies, restores hardware on off)

-- ═════════════════ SCREENSHOTS (DMS pipeline) ═════════════════
hl.bind("SUPER + S", hl.dsp.exec_cmd("bash -c 'dms screenshot --stdout --no-file --no-clipboard --no-notify | satty --filename -'")) -- region select to satty (Mango chord)
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("bash -c 'pidof hyprlock >/dev/null || /run/current-system/sw/bin/hyprlock & sleep 2; systemctl suspend'")) -- lock-then-suspend via hyprlock (singleton-guarded)
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("bash -c 'dms screenshot window --stdout --no-file --no-clipboard --no-notify | satty --filename -'")) -- focused window to satty (Mango chord)
hl.bind("SUPER + CTRL + SHIFT + S", hl.dsp.exec_cmd("bash -c 'dms screenshot full --stdout --no-file --no-clipboard --no-notify | satty --filename -'")) -- fullscreen to satty (Mango 3rd bind)
hl.bind("SUPER + X", hl.dsp.exec_cmd("bash -c 'region=$(slurp) || exit 0; grim -g \"$region\" - | tesseract stdin stdout -l eng 2>/dev/null | wl-copy; notify-send \"OCR\" \"$(wl-paste | head -c 200)\"'")) -- region select to text OCR extract (Mango chord)
hl.bind("SUPER + T", hl.dsp.exec_cmd("bash -c 'wl-paste --no-newline | /home/fury/.local/bin/dusky-kokoro speak --stdin --mode interrupt'")) -- speak clipboard aloud Kokoro Heart/Bella GPU (Mango chord)
hl.bind("SUPER + M", hl.dsp.exec_cmd("hyprwhspr-rs record toggle")) -- STT record toggle Parakeet (Mango chord)
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("dms screenshot")) -- quick region save (Mango chord)
hl.bind("ALT + Print", hl.dsp.exec_cmd("dms screenshot window")) -- quick window save
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot full")) -- quick fullscreen save

-- ═════════════════ FOCUS / MOVE / SWAP / RESIZE (Mango semantics) ═════════════════
-- Mango: CTRL+arrows swaps tiled (exchange_client), ALT+arrows moves floating
-- (smartmovewin). Mirrored here: CTRL=swap, ALT=move.
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" })) -- focus left
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" })) -- focus right
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" })) -- focus up
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" })) -- focus down
hl.bind("SUPER + CTRL + left", hl.dsp.window.swap({ direction = "left" })) -- swap tiled left (Mango exchange)
hl.bind("SUPER + CTRL + right", hl.dsp.window.swap({ direction = "right" })) -- swap tiled right (Mango exchange)
hl.bind("SUPER + CTRL + up", hl.dsp.window.swap({ direction = "up" })) -- swap tiled up (Mango exchange)
hl.bind("SUPER + CTRL + down", hl.dsp.window.swap({ direction = "down" })) -- swap tiled down (Mango exchange)
hl.bind("SUPER + ALT + left", hl.dsp.window.move({ direction = "left" })) -- move floating left (Mango smartmovewin)
hl.bind("SUPER + ALT + right", hl.dsp.window.move({ direction = "right" })) -- move floating right (Mango smartmovewin)
hl.bind("SUPER + ALT + up", hl.dsp.window.move({ direction = "up" })) -- move floating up (Mango smartmovewin)
hl.bind("SUPER + ALT + down", hl.dsp.window.move({ direction = "down" })) -- move floating down (Mango smartmovewin)
hl.bind("SUPER + SHIFT + left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true }) -- resize left 50px
hl.bind("SUPER + SHIFT + right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true }) -- resize right 50px
hl.bind("SUPER + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true }) -- resize up 50px
hl.bind("SUPER + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true }) -- resize down 50px
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- LMB drag: tiled swaps on drop, floating moves (Mango curmove)
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- RMB drag resize
hl.bind("SUPER + SHIFT + mouse:272", hl.dsp.window.float(), { mouse = true }) -- SHIFT+click floats in place, then drag to move (Mango togglefloating)

-- ═════════════════ TAGS (Mango: 9 tags, Tab/wheel hop USED only) ═════════════════
local function hop_used(dir) -- Mango viewtoleft/right_have_client parity: skip empty+special, wrap 9<->1
  local cur = hl.get_active_workspace()
  if not cur then return end
  local ids = {}
  for _, ws in ipairs(hl.get_workspaces()) do
    if ws.id >= 1 and ws.id <= 9 and not ws.special and not ws.is_empty then
      table.insert(ids, ws.id)
    end
  end
  if #ids == 0 then return end
  table.sort(ids)
  local target = ids[1]
  if dir > 0 then
    for _, id in ipairs(ids) do if id > cur.id then target = id; break end end
  else
    target = ids[#ids]
    for i = #ids, 1, -1 do if ids[i] < cur.id then target = ids[i]; break end end
  end
  if target ~= cur.id then hl.dispatch(hl.dsp.focus({ workspace = tostring(target) })) end
end
hl.bind("SUPER + Tab", function() hop_used(1) end) -- next USED workspace (Mango have_client)
hl.bind("SUPER + SHIFT + Tab", function() hop_used(-1) end) -- prev USED workspace (Mango have_client)
hl.bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "special" })) -- send window to special (silent, like Mango CTRL+U)
hl.bind("SUPER + U", hl.dsp.workspace.toggle_special()) -- special workspace overlay
hl.bind("SUPER + J", hl.dsp.workspace.toggle_special("scratchpad")) -- scratch view: own NAMED space, distinct from U (Mango chord)
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ workspace = "special:scratchpad" })) -- send to scratch space (Mango chord)
hl.bind("SUPER + CTRL + J", hl.dsp.workspace.toggle_special("scratchpad")) -- re-open scratch space (Mango restore chord)
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" })) -- view tag 1
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1", follow = true })) -- send follow tag 1
hl.bind("SUPER + CTRL + 1", hl.dsp.window.move({ workspace = "1", follow = false })) -- send silent tag 1
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" })) -- view tag 2
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2", follow = true })) -- send follow tag 2
hl.bind("SUPER + CTRL + 2", hl.dsp.window.move({ workspace = "2", follow = false })) -- send silent tag 2
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" })) -- view tag 3
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3", follow = true })) -- send follow tag 3
hl.bind("SUPER + CTRL + 3", hl.dsp.window.move({ workspace = "3", follow = false })) -- send silent tag 3
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" })) -- view tag 4
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = "4", follow = true })) -- send follow tag 4
hl.bind("SUPER + CTRL + 4", hl.dsp.window.move({ workspace = "4", follow = false })) -- send silent tag 4
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" })) -- view tag 5
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5", follow = true })) -- send follow tag 5
hl.bind("SUPER + CTRL + 5", hl.dsp.window.move({ workspace = "5", follow = false })) -- send silent tag 5
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = "6" })) -- view tag 6
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = "6", follow = true })) -- send follow tag 6
hl.bind("SUPER + CTRL + 6", hl.dsp.window.move({ workspace = "6", follow = false })) -- send silent tag 6
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = "7" })) -- view tag 7
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = "7", follow = true })) -- send follow tag 7
hl.bind("SUPER + CTRL + 7", hl.dsp.window.move({ workspace = "7", follow = false })) -- send silent tag 7
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = "8" })) -- view tag 8
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = "8", follow = true })) -- send follow tag 8
hl.bind("SUPER + CTRL + 8", hl.dsp.window.move({ workspace = "8", follow = false })) -- send silent tag 8
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = "9" })) -- view tag 9
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = "9", follow = true })) -- send follow tag 9
hl.bind("SUPER + CTRL + 9", hl.dsp.window.move({ workspace = "9", follow = false })) -- send silent tag 9
hl.bind("SUPER + SHIFT + bracketleft", hl.dsp.window.move({ workspace = "previous" })) -- move window previous (closest to Mango tag-left)
hl.bind("SUPER + SHIFT + bracketright", hl.dsp.window.move({ workspace = "m+1" })) -- move window next (closest to Mango tag-right)
hl.bind("SUPER + CTRL + bracketleft", hl.dsp.window.move({ workspace = "previous", follow = false })) -- move window previous dup mod
hl.bind("SUPER + CTRL + bracketright", hl.dsp.window.move({ workspace = "m+1", follow = false })) -- move window next dup mod
hl.bind("SUPER + mouse_down", function() hop_used(1) end) -- wheel down: next USED workspace
hl.bind("SUPER + mouse_up", function() hop_used(-1) end) -- wheel up: prev USED workspace
hl.bind("SUPER + period", hl.dsp.focus({ workspace = "e+1" })) -- cycle forward (Mango next)
hl.bind("SUPER + SHIFT + period", hl.dsp.focus({ workspace = "e-1" })) -- cycle back (Mango prev)
-- ═════════════════ BAR (DMS island-safe toggle) ═════════════════
hl.bind("SUPER + CTRL + ALT + B", hl.dsp.exec_cmd("/home/fury/.config/hypr/scripts/ToggleDmsBar.sh")) -- hide/show DMS bar (Mango chord+script)

-- ═════════════════ MONITORS (dwm parity; inert on single monitor) ═════════════════
-- NOTE: focus form untested (no 2nd monitor); send form reuses proven workspace.move API.
hl.bind("SUPER + ALT + comma", hl.dsp.focus({ monitor = "left" })) -- focus prev monitor (Mango chord)
hl.bind("SUPER + ALT + period", hl.dsp.focus({ monitor = "right" })) -- focus next monitor (Mango chord)
hl.bind("SUPER + ALT + SHIFT + comma", hl.dsp.workspace.move({ monitor = "left" })) -- send workspace to prev monitor (Mango tagmon)
hl.bind("SUPER + ALT + SHIFT + period", hl.dsp.workspace.move({ monitor = "right" })) -- send workspace to next monitor (Mango tagmon)
-- Monitors: single-monitor setup, Mango binds inert here too — skipped.
-- Shell switching + Tide stay retired (vault choice).
