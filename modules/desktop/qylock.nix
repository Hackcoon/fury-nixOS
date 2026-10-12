# ============================================================================
# qylock.nix — Qylock SDDM themes (from the qylock flake input).
#
# SCOPE LIMIT: the Quickshell lockscreen needs ext-session-lock-v1, which KWin
# does NOT support yet — so only the SDDM login-screen theme works under
# Plasma. qylock-lock becomes useful only under a wlroots compositor (Hyprland).
# OPTIONAL: SDDM theme only — drop for minimal (plain SDDM is fine).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Theme select: nier-automata (+ parked alternatives) ──
  # Any directory name under qylock's `themes/` folder. Full gallery:
  # https://github.com/Darkkal44/qylock#-gallery
  programs.qylock = {
    enable = true;
    theme = "nier-automata"; # also: "terraria", "clockwork", "pixel-coffee", ...

    # sddm.enable = true;         # default: installs theme + sets it active
    # quickshell.enable = false;  # see SCOPE LIMIT above — no KWin support yet

    # Optional per-theme tweaks (skips qylock's interactive prompts):
    # themeOptions = {
    #   terraria.backgroundMode = "time";   # time | random | static
    #   Genshin.backgroundMode = "time";
    #   clockwork.orbital = { themeMode = "dark"; enableWindup = true; };
    #   osu.gameMode = "menu";              # menu | game
    # };
  };
  # ----------------------------------------------------------------------
}
