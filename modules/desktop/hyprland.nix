# ============================================================================
# hyprland.nix — Hyprland core: compositor + rice toolkit (NO tide-island deps).
#
# Self-contained: enables Hyprland, the launcher stack (Vicinae + rofi), and
# every utility binds/scripts/waybar need. fury-bar (quickshell pill-bar)
# starts from hyprland.lua and only needs `quickshell` from here. Toggle
# tide-island SEPARATELY via modules/unused/tide-island.nix — uncomment its
# import in configuration.nix to bring the island back.
# HEAVY: full DE stack — keep only if Hyprland is main (or the only DE).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── The compositor (+ XWayland for Steam/games) ──
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;   # X11 apps (Steam, some games) keep working
  };
  # ----------------------------------------------------------------------

  # ── Rice toolkit: one list, grouped by job ──
  # Single environment.systemPackages (NixOS rejects duplicate definitions in
  # the same module). Group labels stay as landmarks. Layout plugins: hy3
  # active, hyprscrolling parked (Mango-scroller parity if wanted).
  environment.systemPackages = with pkgs; [
    # ---- Hyprland first-party ecosystem ----
    hyprsunset       # night light (SUPER+N toggle via Hyprsunset.sh)
    hyprpaper        # simple wallpaper (alternative to awww)
    hypridle         # idle daemon → auto-lock via hyprlock
    hyprlock         # lock screen (LockScreen.sh uses it)
    hyprpicker       # on-screen color picker
    hyprpolkitagent  # password prompts for privileged apps

    # ---- Hyprland layout plugins (SUPER+L cycles all four) ----
    # hyprlandPlugins.hyprscrolling  # column scroller (Mango-scroller parity)
    hyprlandPlugins.hy3           # i3-style (tabs + splits)

    # ---- Launchers ----
    vicinae        # native launcher — SUPER+D; black/white theme at
                   # ~/.local/share/vicinae/themes/monochrome-fury.toml
    rofi           # secondary launcher — SUPER+SHIFT+D (drun/filebrowser/run/window)
    rofi-calc      # RofiCalc.sh  (modi: calc — qalculate backend)
    rofi-emoji     # Emoticon.sh  (modi: emoji)

    # ---- Quickshell: runtime for fury-bar (the main shell) ----
    quickshell     # also lets SwitchShell.sh flip to any quickshell config

    # ---- Wallpapers & bar ----
    awww           # swww fork — Wallpaper*.sh use it; tide drives it too
    waybar         # status bar (WaybarStyles.sh / WaybarLayout.sh cycle it)
    wlogout        # logout menu (Wlogout.sh)
    wallust        # ThemeChanger.sh — global theme from wallpaper

    # ---- Notifications ----
    swaynotificationcenter   # swaync + swaync-client (SUPER SHIFT+N panel)
    libnotify                # notify-send (used by all scripts)

    # ---- Screenshots ----
    grim
    slurp
    satty          # SUPER+SHIFT+S annotator
    swappy         # ScreenShot.sh --swappy backend

    # ---- Audio / media / misc (used by scripts + binds + fury-bar) ----
    pamixer                # Volume.sh CLI control
    playerctl              # MediaCtrl.sh MPRIS
    brightnessctl          # brightness (scripts + island)
    pavucontrol            # GUI mixer
    mpv                    # RofiBeats.sh streams
    jq                     # JSON parsing everywhere
    wlr-randr              # display settings
    lm_sensors             # temps (fury-bar StatsPill reads `sensors`)
    networkmanagerapplet   # nm-applet tray
    python3                # URL-encoding etc.
    xdg-utils              # xdg-open (SUPER+B browser bind)
    # rfkill: provided by util-linux (already in system packages)
    cava                   # waybar cava_mviz module + fury-bar
    bc                     # WallpaperSelect.sh / Dropterminal.sh math
    psmisc                 # killall (Refresh.sh, WaybarStyles.sh, WallpaperEffects.sh)
    mpvpaper               # video wallpapers (WallpaperSelect.sh video branch)
  ];
  # ----------------------------------------------------------------------

  # ── UPower for bars (mkDefault so laptop.nix owns thresholds) ──
  # fury-bar/island read battery over this; laptop.nix sets the real policy.
  services.upower.enable = lib.mkDefault true;
  # ----------------------------------------------------------------------
}
