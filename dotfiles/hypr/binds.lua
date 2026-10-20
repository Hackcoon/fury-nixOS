-- ============================================================================
-- ~/.config/hypr/binds.lua — FULL PORT of JaKooLit/Hyprland-Dots keybinds
-- to Hyprland 0.55 Lua API + DMS-shell cleanup (2026-09-23, sections 1-9).
-- Sections 10-13 (resize/move/swap/focus, workspaces, mouse, shell/tide)
-- are UNTOUCHED per vault note. Mango config NOT touched.
-- Rule: Mango tick = Mango chord + Hyprland-native action; DMS shell
-- services (spotlight/clipboard/notifs/CC/wallpaper/power/lock/settings/
-- keybinds/mpris/powerprofile/processlist) run as `dms ipc call ...`
-- which works on Hyprland too. Screenshots all use `dms screenshot`.
-- Every active bind has a trailing explanation. Retired binds live in the
-- RETIRED block at end of file (commented, not deleted).
-- ============================================================================

local M    = "SUPER"
local MS   = "SUPER + SHIFT"
local MC   = "SUPER + CTRL"
local MA   = "SUPER + ALT"
local MCA  = "SUPER + CTRL + ALT"
local CA   = "CTRL + ALT"
local CAS  = "CTRL + ALT + SHIFT"
local MCS  = "SUPER + CTRL + SHIFT"

local scriptsDir = os.getenv("HOME") .. "/.config/hypr/scripts"
local function script(name) return scriptsDir .. "/" .. name end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function sh(cmd) return run("bash -c '" .. cmd .. "'") end

-- ═══════════════════════════ STANDARD ═══════════════════════════
-- (moved to dms/binds.lua — DMS cheatsheet reads that slot; required below in hyprland.lua)

-- ═══════════════════════ FEATURES / EXTRAS ═══════════════════════
-- (moved to dms/binds.lua — same note as STANDARD)

-- ═══════════════════════ USERSCRIPTS ═══════════════════════
-- (moved to dms/binds.lua — same note as STANDARD)

-- Keyboard layout switching (global switch retired to RETIRED; per-window moved to dms/binds.lua)

-- ═══════════════════════ SYSTEM ═══════════════════════
-- (moved to dms/binds.lua — same note as STANDARD)

-- ═══════════════════ MASTER / DWINDLE ═══════════════════
-- (moved to dms/binds.lua — same note as STANDARD)

-- ═════════════════ MEDIA / FUNCTION KEYS ═══════════════════
-- (moved to dms/binds.lua — same note as STANDARD; XF86 note below kept for reference)
-- NOTE: "XF86AudioPlayPause" is NOT a real XKB keysym — binds use separate
-- XF86AudioPlay + XF86AudioPause (now in dms/binds.lua).

-- ═════════════════ RESIZE / MOVE / SWAP / FOCUS — moved to dms/binds.lua (Mango semantics) ═════════════════

-- ═════════════════ WORKSPACES/TAGS — moved to dms/binds.lua (9 tags, statics for sheet) ═════════════════
-- (ws10 retired — Mango has 9 tags; see RETIRED)
-- (M + comma workspace-prev retired — SUPER+comma is DMS settings per vault §5; use SHIFT+Tab or wheel; see RETIRED)

-- ═════════════════ MOUSE — moved to dms/binds.lua (incl. SHIFT+click float) ═════════════════

-- ═════════════════ SHELL SWITCHING + BAR TOGGLE — RETIRED for DMS (section 12) ═════════════════
-- Single shell: DMS. Switcher + generic bar toggle retired below (see RETIRED).

-- ═════════════════ TIDE ISLAND — REMOVED 2026-09-24 (unused; git history restores) ═════════════════

-- ═════════════════ RETIRED (commented out per vault 1-9 decisions, 2026-09-23) ═════════════════
-- Kept here so nothing is lost. Uncomment to restore. Sections 10-13 untouched.
-- -- SUPER+D vicinae launcher — replaced by Dolphin on SUPER+D, launcher moved to SUPER+SPACE DMS spotlight
-- hl.bind(M .. " + D", run("vicinae toggle"))
-- -- SUPER+SHIFT+D rofi backup launcher — dropped, DMS spotlight covers it
-- hl.bind(MS .. " + D", sh("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"))
-- -- SUPER+H KeyHints sheet — replaced by DMS keybinds toggle hyprland
-- hl.bind(M .. " + H", run(script("KeyHints.sh")))
-- -- SUPER+ALT+R Refresh bars — replaced by SUPER+SHIFT+R hyprctl reload
-- hl.bind(MA .. " + R", run(script("Refresh.sh")))
-- -- SUPER+ALT+E rofi emoji — dropped (both rofi + Mango semicolon voted no)
-- hl.bind(MA .. " + E", run(script("RofiEmoji.sh")))
-- -- SUPER+S Brave web search — replaced by DMS region screenshot on SUPER+S
-- hl.bind(M .. " + S", run(script("RofiSearch.sh")))
-- -- SUPER+CTRL+S rofi window switcher — dropped, ALT+Tab covers it
-- hl.bind(MC .. " + S", run("rofi -show window"))
-- -- SUPER+ALT+L layout toggle old chord — moved to SUPER+L
-- hl.bind(MA .. " + L", run(script("ChangeLayout.sh")))
-- -- SUPER+ALT+V clipboard script — replaced by DMS clipboard on SUPER+V
-- hl.bind(MA .. " + V", run(script("ClipManager.sh")))
-- -- SUPER+CTRL+B waybar styles — RESTORED 2026-09-24 to dms/binds.lua (was undecided)
-- -- SUPER+ALT+B waybar layouts — RESTORED 2026-09-24 to dms/binds.lua (was undecided)
-- -- SUPER+N night light hyprsunset — replaced by DMS notifications on SUPER+N
-- hl.bind(M .. " + N", run(script("Hyprsunset.sh toggle")))
-- -- SUPER+SHIFT+M RofiBeats music — undecided, commented out
-- hl.bind(MS .. " + M", run("~/.config/hypr/UserScripts/RofiBeats.sh"))
-- -- SUPER+W wallpaper select script — replaced by DMS dankdash wallpaper on SUPER+W
-- hl.bind(M .. " + W", run("~/.config/hypr/UserScripts/WallpaperSelect.sh"))
-- -- SUPER+SHIFT+W wallpaper effects — undecided, commented out
-- hl.bind(MS .. " + W", run("~/.config/hypr/UserScripts/WallpaperEffects.sh"))
-- -- CTRL+ALT+W random wallpaper — undecided, commented out
-- hl.bind(CA .. " + W", run("~/.config/hypr/UserScripts/WallpaperRandom.sh"))
-- -- SUPER+SHIFT+K searchable keybinds — retired, SUPER+H DMS keybinds covers it
-- hl.bind(MS .. " + K", run(script("Keybinds.sh")))
-- -- SUPER+SHIFT+O zsh theme — replaced by portal restart on SUPER+SHIFT+O
-- hl.bind(MS .. " + O", run(script("ZshChangeTheme.sh")))
-- -- ALT_L+SHIFT_L global kbd switch — undecided, commented out (per-window kept)
-- hl.bind("ALT_L + SHIFT_L", run(script("KeyboardLayout.sh switch")), { ignore_mods = true })
-- -- SUPER+CTRL+F9 monitor left — undecided, commented out
-- hl.bind(MC .. " + F9", hl.dsp.workspace.move({ monitor = "left" }))
-- -- SUPER+CTRL+F10 monitor right — undecided, commented out
-- hl.bind(MC .. " + F10", hl.dsp.workspace.move({ monitor = "right" }))
-- -- SUPER+CTRL+F11 monitor up — undecided, commented out
-- hl.bind(MC .. " + F11", hl.dsp.workspace.move({ monitor = "up" }))
-- -- SUPER+CTRL+F12 monitor down — undecided, commented out
-- hl.bind(MC .. " + F12", hl.dsp.workspace.move({ monitor = "down" }))
-- -- CTRL+ALT+L hyprlock — replaced by DMS lock on SUPER+ALT+L
-- hl.bind(CA .. " + L", run(script("LockScreen.sh")))
-- -- CTRL+ALT+P fury-bar power popup — replaced by DMS powermenu same chord
-- hl.bind(CA .. " + P", run("quickshell ipc -p ~/.config/quickshell/fury-bar call popup open power"))
-- -- SUPER+SHIFT+N fury-bar notif panel — replaced by DMS do-not-disturb same chord
-- hl.bind(MS .. " + N", run("quickshell ipc -p ~/.config/quickshell/fury-bar call notif togglePanel"))
-- -- SUPER+SHIFT+E quick settings — replaced by DMS settings on SUPER+comma
-- hl.bind(MS .. " + E", run(script("Kool_Quick_Settings.sh")))
-- -- SUPER+P pseudo-tile — replaced by DMS powerprofile cycle same chord
-- hl.bind(M .. " + P", hl.dsp.window.pseudo())
-- -- SUPER+M splitratio 0.3 — replaced by DMS processlist same chord
-- hl.bind(M .. " + M", hl.dsp.layout("splitratio 0.3"))
-- -- SUPER+Tab group next — retired, workspace m+1 keeps chord (groups on CTRL+Tab)
-- hl.bind(M .. " + Tab", hl.dsp.group.next())
-- -- SUPER+SHIFT+Tab group prev — retired, workspace m-1 keeps chord
-- hl.bind(MS .. " + Tab", hl.dsp.group.prev())
-- -- SUPER+Print full screenshot script — no DMS equiv, retired
-- hl.bind(M .. " + Print", run(script("ScreenShot.sh --now")))
-- -- SUPER+SHIFT+Print area script — replaced by DMS region save on SHIFT+Print
-- hl.bind(MS .. " + Print", run(script("ScreenShot.sh --area")))
-- -- SUPER+CTRL+Print 5s delay — undecided, commented out (no DMS delay)
-- hl.bind(MC .. " + Print", run(script("ScreenShot.sh --in5")))
-- -- SUPER+CTRL+SHIFT+Print 10s delay — undecided, commented out
-- hl.bind(MCS .. " + Print", run(script("ScreenShot.sh --in10")))
-- -- ALT+Print active window script — replaced by DMS window save same chord
-- hl.bind("ALT + Print", run(script("ScreenShot.sh --active")))
-- -- SUPER+SHIFT+S swappy area script — replaced by DMS window-to-satty same chord
-- hl.bind(MS .. " + S", run(script("ScreenShot.sh --swappy")))
-- -- Print bare full script — replaced by DMS fullscreen save same chord
-- hl.bind("Print", run(script("ScreenShot.sh --now")))

-- -- SUPER+comma workspace prev — retired, SUPER+comma is DMS settings now (vault §5)
-- hl.bind(M .. " + comma", hl.dsp.focus({ workspace = "e-1" }))
-- -- workspace 10 trio — retired, Mango has 9 tags (vault §§10-11 Mango parity)
-- hl.bind(M .. " + code:19", hl.dsp.focus({ workspace = "10" }))
-- hl.bind(MS .. " + code:19", hl.dsp.window.move({ workspace = "10", follow = true }))
-- hl.bind(MC .. " + code:19", hl.dsp.window.move({ workspace = "10" }))
-- -- SUPER+CTRL+ALT+T shell switcher — retired, single shell DMS now (vault §12)
-- hl.bind(MCA .. " + T", run(script("SwitchShell.sh")))
-- -- SUPER+CTRL+ALT+B generic bar toggle — retired, DMS bar stays on (vault §12)
-- hl.bind(MCA .. " + B", run(script("ToggleBar.sh")))
-- -- SUPER+SHIFT+Return Dropterminal.sh — retired, native toggle_special scratch-term replaces it (script used broken hyprctl dispatch args; workspace rule auto-spawns kitty)
-- hl.bind(MS .. " + Return", run(script("Dropterminal.sh kitty")))
-- -- SUPER+ALT+SPACE float ALL — retired, dispatcher broken in this build, no Lua equiv (use CTRL+SPACE per window)
-- hl.bind(MA .. " + SPACE", run("hyprctl dispatch workspaceopt allfloat"))
-- -- SUPER+ALT+C rofi calc — retired, Qalculate takes the chord (vault §4 change)
-- hl.bind(MA .. " + C", run("~/.config/hypr/UserScripts/RofiCalc.sh"))
-- ═════════════════ NOTES ═══════════════════
--  • AnimationsMenu keeps SUPER+SHIFT+A; Tide overview retired to fix conflict.
--  • Group Tab binds retired; workspace Tab keeps chords (groups on CTRL+Tab).
--  • SUPER+SPACE float moved to SUPER+CTRL+SPACE; SPACE is DMS spotlight.
--  • Screenshots all DMS now; old ScreenShot.sh binds retired above.
--  • Mango config NOT touched. Sections 10-13 unchanged pending vault decision.
