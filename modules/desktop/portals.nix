# ============================================================================
# portals.nix — XDG desktop portals: screenshare + file pickers per session.
#
# Each compositor brings its native portal (Hyprland, KDE), GTK is the general
# fallback everything shares. wlroots stays installed for possible future
# MangoWC use but defaults to nothing. KEEP with whichever DE stays — drop
# only alongside its compositor (minimal = one DE + its portal).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Portal backends + per-session routing ──
  # .default lists are tried in order: native first, gtk fallback. common =
  # unidentified sessions. MangoWC routing lives in mango-dms.nix
  # (xdg.portal.config.mango.default = [ "wlr" "gtk" ]).
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk      # GTK dialogs, file pickers, fallback
      pkgs.xdg-desktop-portal-hyprland # Hyprland screen sharing / Wayland
      pkgs.xdg-desktop-portal-wlr      # generic wlroots (future MangoWC)
      pkgs.kdePackages.xdg-desktop-portal-kde  # Plasma screen sharing
    ];
    config = {
      hyprland.default = [ "hyprland" "gtk" ];
      kde.default      = [ "kde" "gtk" ];
      xfce.default     = [ "xapp" "gtk" ];
      common.default   = [ "gtk" ];   # fallback for unidentified DEs
    };
  };
  # ----------------------------------------------------------------------
}
