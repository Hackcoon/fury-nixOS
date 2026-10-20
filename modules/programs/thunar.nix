# ============================================================================
# thunar.nix — Thunar file manager + the services it needs.
#
# Thunar alone can't mount, thumbnail, or remember prefs — the three services
# below are its missing organs (mounting/trash, thumbnails, xfconf for prefs
# outside a full XFCE session). OPTIONAL: safe to drop if KDE Dolphin suffices.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Thunar + plugins ──
  # These plugins moved from pkgs.xfce to top-level pkgs — don't go looking
  # for them under the old path.
  programs.thunar = {
    enable = true;
    plugins = [
      pkgs.thunar-archive-plugin
      pkgs.thunar-volman
      pkgs.thunar-media-tags-plugin
      pkgs.thunar-shares-plugin
    ];
  };
  # ----------------------------------------------------------------------

  # ── Support services: mounting, thumbnails, prefs ──
  services.gvfs.enable = true;      # mounting, trash, removable devices
  services.tumbler.enable = true;   # thumbnails
  programs.xfconf.enable = true;    # saves Thunar prefs outside a full XFCE session
  # ----------------------------------------------------------------------
}
