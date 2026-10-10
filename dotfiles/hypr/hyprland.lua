-- ============================================================================
-- ~/.config/hypr/hyprland.lua — FULL LUA port of JaKooLit/Hyprland-Dots look
-- Hyprland 0.55+ · personalizations: Vicinae on SUPER+D, tide-island optional
-- ============================================================================
local M = "SUPER"

-- ================= ENVIRONMENT =================
hl.env("NIXOS_OZONE_WL", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ================= PLUGINS =================
-- hy3 (i3-style tabs/splits) from system packages. nixpkgs-pinned to match
-- this Hyprland build; re-verify after any Hyprland version bump.
hl.plugin.load("/run/current-system/sw/lib/libhy3.so")

-- ================= MONITORS =================
-- DP-2 (AOC 24G1WG4): force 144Hz so VRR (misc.vrr=2) flicker stays minimal
hl.monitor({ output = "DP-2", mode = "1920x1080@144", position = "auto", scale = 1 })
-- hyprland.lua Mango parity: 9 persistent tags (carousel-like, always exist)
-- with emoji default names (vault set; DMS bar shows index:name = 1:globe)
local wsNames = { "🌐", "💻", "💬", "📁", "📝", "⚙️", "🎮", "🎵", "📦" }
for i = 1, 9 do
  hl.workspace_rule({ workspace = tostring(i), persistent = true, default_name = wsNames[i] })
end
-- WS1 🌐 starts scrolling; SUPER+L re-pins the ACTIVE workspace so WS1 stays changeable
hl.workspace_rule({ workspace = "1", layout = "scrolling" })
-- native dropdown scratchpad (Mango toggle_named_scratchpad parity, no script):
-- first toggle opens the special workspace empty -> rule spawns kitty there
hl.workspace_rule({ workspace = "special:scratch-term", on_created_empty = "kitty --config /home/fury/.config/kitty/hyprland-wallust.conf --class scratch-term" })
-- hyprctl monitors all  → add explicit rules once you know names:
-- hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "auto", scale = 1, vrr = 1 })

-- ================= BORDER RESTORE POINT (pre-wallust wiring, 2026-09-24) ===
-- Hardcoded look, KEPT DOCUMENTED but not active: active gradient
-- 7aa2f7↔bb9af7 @45°, inactive 414868. Say "borders back" to restore.
-- CURRENT (preferred): wallust-driven glow — active color12↔color13,
-- inactive color8, following SUPER+T. Grey on the current monochrome theme.
-- ================= WALLUST PALETTE → BORDERS (SUPER+T) =================
-- Reads JaKooLit wallust-hyprland.conf ($colorN = rgb(XXXXXX) lines).
-- SUPER+T regenerates that file then reloads, so borders follow the theme.
local wallustPal = {}
do
  local f = io.open(os.getenv("HOME") .. "/.config/hypr/wallust/wallust-hyprland.conf", "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("^%$(color%d+)%s*=%s*rgb%((%x%x%x%x%x%x)%)")
      if k and v then wallustPal[k] = v end
    end
    f:close()
  end
end
local function wpal(key, fallback)
  local v = wallustPal[key]
  return "rgb(" .. (v or fallback) .. ")"
end

-- ================= CORE SETTINGS (JaKooLit SystemSettings port) =================
hl.config({
  general = {
    resize_on_border = true,
    layout = "dwindle",
    gaps_in = 4, gaps_out = 10,
    border_size = 2,
    col = {
      active_border   = { colors = { wpal("color12", "7aa2f7"), wpal("color13", "bb9af7") }, angle = 45 },
      inactive_border = wpal("color8", "414868"),
    },
  },

  dwindle = {
    preserve_split = true,             -- permanent splits (JaKooLit had pseudotile,
    special_scale_factor = 0.8,         --  which 0.55 moved to window pseudo rules)
  },

  master = {
    new_status = "master",
    new_on_top = 1,
    mfact = 0.5,
  },

  input = {
    kb_layout = "us",
    repeat_rate = 50,
    repeat_delay = 300,
    sensitivity = -0.5,
    numlock_by_default = true,
    follow_mouse = 1,
    float_switch_override_focus = false,
    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,
      tap_to_click = true,
      drag_lock = false,
    },
  },

  gestures = {
    -- NOTE: 0.55.4 has no master 'workspace_swipe' toggle; the sub-options
    -- below enable swipe behavior on their own (verified in ConfigValues.cpp)
    workspace_swipe_distance = 500,
    workspace_swipe_invert = true,
    workspace_swipe_min_speed_to_force = 30,
    workspace_swipe_cancel_ratio = 0.5,
    workspace_swipe_create_new = true,
    workspace_swipe_forever = true,
  },

  binds = {
    workspace_back_and_forth = true,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    vrr = 2,                            -- fullscreen-only adaptive sync (NVIDIA friendly)
    mouse_move_enables_dpms = true,
    enable_swallow = false,
    swallow_regex = "^(kitty)$",
    focus_on_activate = false,
    initial_workspace_tracking = 0,
    middle_click_paste = false,
    enable_anr_dialog = true,
    anr_missed_pings = 15,
    allow_session_lock_restore = true,
    on_focus_under_fullscreen = 1,
    force_default_wallpaper = 0,
    font_family = "JetBrainsMono Nerd Font",
  },

  cursor = {
    enable_hyprcursor = true,
    warp_on_change_workspace = 2,
    no_warps = true,
    sync_gsettings_theme = true,
    no_hardware_cursors = 2,
  },

  xwayland = {
    force_zero_scaling = true,
  },

  decoration = {
    rounding = 10,
    blur = {
      enabled = true, size = 4, passes = 3,
      contrast = 0.8916, brightness = 1.0, vibrancy = 0.1696,
      new_optimizations = true, xray = false, popups = true, popups_ignorealpha = 0.2,
    },
    shadow = { enabled = true, range = 15, render_power = 3, offset = {0, 3} },
  },
})

-- ================= ANIMATIONS — JaKooLit "ML4W - high" port =================
-- bezier name → hl.curve(NAME, { type="bezier", points={{x0,y0},{x1,y1}} })
hl.curve("wind",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn",  { type = "bezier", points = { {0.1, 1.1},  {0.1, 1.1} } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3}, {0.0, 1.0} } })
hl.curve("liner",  { type = "bezier", points = { {1.0, 1.0},  {1.0, 1.0} } })
hl.curve("default",{ type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } }) -- built-in fade curve

-- animation = leaf, speed(deciseconds), bezier, style
hl.animation({ leaf = "windows",     enabled = true, speed = 6, bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6, bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind",  style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "once" })
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "wind" })
hl.animation({ leaf = "layers",      enabled = true, speed = 5, bezier = "wind",  style = "fade" })

-- user animation preset (SUPER+ALT+A switcher writes UserConfigs/user_animations.lua)
dofile(os.getenv("HOME") .. "/.config/hypr/UserConfigs/user_animations.lua")

-- ================= KEYBINDS (binds.lua §§10-13 + DMS slot §§1-9) =================
dofile(os.getenv("HOME") .. "/.config/hypr/binds.lua")
-- DMS-managed binds (cheatsheet source for SUPER+H). dms/binds-user.lua stays
-- free for personal overrides (require it too if you ever create it).
require("dms.binds")

-- ================= WINDOW RULES (JaKooLit tags, Lua syntax) =================
-- tag the usual suspects:
local function tag(pattern, name)
  hl.window_rule({ match = { class = pattern }, tag = "+" .. name })
end
tag("^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Cc]hromium|Brave-browser(-beta|-dev|-unstable)?)$", "browser")
tag("^(Alacritty|kitty|kitty-dropterm)$", "terminal")
tag("^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$", "im")
tag("^(com.obsproject.Studio)$", "screenshare")
tag("^(VSCode|code|code-url-handler|codium|codium-url-handler)$", "projects")
tag("^(nwg-displays|nwg-look)$", "KooL-Settings")

-- behavior rules (the ones that matter day-to-day):
hl.window_rule({ match = { class = "^(kitty-dropterm)$" }, float = true })
hl.window_rule({ match = { class = "^(scratch-term)$" }, float = true, size = { "monitor_w*0.65", "monitor_h*0.65" }, move = { "monitor_w*0.175", "monitor_h*0.1" } })
hl.window_rule({ match = { class = "^(io\\.github\\.Qalculate.*|[Qq]alculate.*)$" }, float = true })
hl.window_rule({ match = { class = "^(nwg-look|nm-connection-editor|blueman-manager|pavucontrol)$" }, float = true })
-- Brave/FF PiP (YouTube or any site): float + pin (Hyprland's always-on-top),
-- bottom-right 25%, no focus steal on video change (gaming-safe).
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture|PiP)(.*)$" }, float = true, pin = true, size = { "monitor_w*0.25", "monitor_h*0.25" }, move = { "monitor_w-(monitor_w*0.25)-20", "monitor_h-(monitor_h*0.25)-20" }, focus_on_activate = false, no_initial_focus = true, suppress_event = "activate" })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true })
hl.window_rule({ match = { initial_class = "^(pavucontrol)$" }, float = true })

-- ═══════════ AUTOSTART (tide-island OPTIONAL — see NixOS module) ═══════════
-- Tide Island starts ONLY if installed. When you disable its NixOS module,
-- this line silently fails and fury-bar takes over as your main shell.
hl.on("hyprland.start", function()
  -- essentials (JaKooLit Startup_Apps port):
  hl.exec_cmd("hyprpolkitagent")
  hl.exec_cmd("hypridle")

  -- wallpaper
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("~/.config/hypr/scripts/WallpaperRandom.sh")

  -- suspend watcher: locks on ANY suspend (DMS 1.6.2 drops PrepareForSleep).
  -- Singleton-guarded; fires the same single-locker chain as hypridle.
  hl.exec_cmd("bash -c 'pgrep -f \"suspend-watch-loc[k]\" >/dev/null || setsid ~/.config/hypr/scripts/suspend-watch-lock.sh >/tmp/suspend-watch.log 2>&1 < /dev/null'")

  -- secrets: start keyring early (before Brave/DMS need it). Unlock still
  -- comes from login password via greetd PAM; if it prompts, unlock once
  -- then RESTART Brave (sessions recover — data isn't lost, just locked).
  hl.exec_cmd("/run/wrappers/bin/gnome-keyring-daemon --start --components=secrets")

  -- VICINAE — server mode (survives independently, spawns on toggle)
  -- to disable: comment the next line + remove the SUPER+ALT+SPACE bind in dms/binds.lua, `hyprctl reload`, `pkill vicinae-server`
  hl.exec_cmd("~/.local/bin/vicinae-autostart")  -- guarded (also used by KDE session)

  -- notifications: DMS (your MAIN shell) registers org.freedesktop.Notifications
  -- itself. Do NOT autostart swaync alongside — two daemons = D-Bus
  -- deadlock (whoever starts second crashes). fury-bar is retired (files
  -- kept at ~/.config/quickshell/fury-bar, untouched) so it can't fight DMS.

  -- clipboard history
  hl.exec_cmd("wl-paste --type text --watch cliphist store")

  -- YOUR SHELL: DMS is now the MAIN (single shell, fury-bar retired).
  -- dms.service can't run here (bound to mango-session.target + pgrep mango
  -- gate), so DMS runs as a plain process via `dms run` (no --session).
  -- First: reap any stray shells from before a rebuild or session switch
  -- (fury-bar / tide stacking). Exactly ONE shell. fury-bar files untouched.
  -- NOTE: pkill -f patterns below are bracket-quoted (fury-ba[r]) so the
  -- reaper never matches its own spawn chain (pkill spares only itself,
  -- not parents whose cmdlines contain the victim string).
  hl.exec_cmd("bash -c 'pkill -f \"quickshell -p.*fury-ba[r]\" 2>/dev/null; pgrep -f \"quickshell .*-tide-islan[d]\" >/dev/null && pkill -f \"quickshell .*-tide-islan[d]\" && pkill -f \"lyricsmpri[s]\"; true'")
  hl.exec_cmd("bash -c 'D=$(command -v dms 2>/dev/null || echo /run/current-system/sw/bin/dms); pkill -f \"dms ru[n]\" 2>/dev/null; sleep 1; setsid $D run >>/tmp/dms-hyprland.log 2>&1 < /dev/null'")

  -- session glue (NixOS + systemd)
  hl.exec_cmd("dbus-update-activation-environment --systemd --all WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- STALE SESSION REAPER: logging out of mango (SDDM) leaves its
  -- mango-session.target running → its Wants can fight this session.
  -- Stop the target only (dms.service self-stops via its pgrep-mango gate;
  -- our DMS here is a plain `dms run` process, not the unit, so untouched).
  hl.exec_cmd("bash -c 'systemctl --user stop mango-session.target 2>/dev/null; true'")
end)

-- ================= LAYER RULES =================
hl.layer_rule({ match = { namespace = ".*tide.*" }, blur = true, ignore_alpha = 0.3 })  -- tide panels
hl.layer_rule({ match = { namespace = "fury-.*" },  blur = true, ignore_alpha = 0.3 })  -- fury-bar pills
hl.layer_rule({ match = { namespace = "vicinae" },  blur = true, ignore_alpha = 0 })    -- per vicinae docs
hl.layer_rule({ match = { namespace = "vicinae" },  no_anim = true })
hl.layer_rule({ match = { namespace = "rofi" },     blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "swaync" },   blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "waybar" },   blur = true, ignore_alpha = 0.2 })
require("dms.outputs")
