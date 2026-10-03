# ============================================================================
# themes.nix — Cursor + GTK theme pins (env level) + KDE GTK fix.
#
# WHY PIN AT ENV LEVEL: Electron apps (vscodium, brave, mailspring...) render
# native menus/dialogs with GTK, and the xfce4/Chicago95 session's xsettings
# daemon sets the system gtk-theme to Chicago95 — which leaked into those apps
# even under Plasma. GTK_THEME forces the theme at the library level for ALL
# GTK apps, overriding gsettings/xsettings, so the Win95 theme can't leak in.
# Breeze-Dark is used because it's present in /run/current-system/sw/share/
# themes/ via breeze-gtk — Electron UIs stay consistent with Plasma everywhere.
# XCURSOR_THEME must match a variant from google-cursor (system-packages.nix,
# THEMES & CURSORS section). OPTIONAL: cosmetic — safe to drop for minimal.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Env pins: cursor, size, GTK, menu namespace ──
  # Cursor variants: GoogleDot-Blue/Black/White/Red; others tried or noted:
  # phinger (most over-engineered), Borealis, bibata (+translucent),
  # apple-cursor, afterglow-recolored (macOS-like), openzone (Windows-like).
  # GTK_THEME beats the user's gsettings value. In the XFCE session XFCE's own
  # widgets keep Chicago95 (its xsettings daemon themes its own toolkit) —
  # this pin only affects apps reading the env var (Electron always does).
  # XDG_MENU_PREFIX affects app discovery/associations, not colors.
  environment.variables = {
    XCURSOR_THEME = "GoogleDot-Black";
    XCURSOR_SIZE = "22"; # standard sizes: 22, 24, 32, 48, 64
    GTK_THEME = "Breeze-Dark"; # dark GTK for Electron/Chromium under Plasma
    XDG_MENU_PREFIX = "plasma-"; # KDE app-menu namespace (Dolphin et al.)
  };
  # ----------------------------------------------------------------------

  # ── KDE-side GTK pin (fix for inverted/grey Qt apps + drkonqi) ──
  # ROOT CAUSE (2026-09): kded6's kde-gtk-config generates
  # ~/.config/xsettingsd/xsettingsd.conf from kdeglobals [KDE] keys. kdeglobals
  # had NO gtkTheme key (DMS matugen targets adw-gtk3, not installed — it skips
  # and resets the gtk theme), so kded6 wrote Net/ThemeName "" — an EMPTY
  # xsettings theme. Empty beats settings.ini for every GTK app, killing the
  # dark flag: Dolphin, drkonqi and friends rendered light-grey ("inverted") in
  # mango/Hyprland sessions (QT_QPA_PLATFORMTHEME=gtk3 routes Qt via GTK).
  # FIX: declare the theme in kdeglobals' [KDE] group (kcm + kded6 both read it;
  # module maps Breeze-Dark for dark schemes) so xsettingsd.conf carries a real
  # theme. ~/.config/kdeglobals is user-owned — kdedefaults (XDG_CONFIG_DIRS,
  # never rewritten by apps) is the system-side override point. Explanations
  # live HERE: the string below lands verbatim in the generated file.
  environment.etc."xdg/kdedefaults/kdeglobals".text = ''
    [KDE]
    widgetStyle=Breeze
    gtkTheme=Breeze-Dark

    [Icons]
    Theme=Papirus-Dark
  '';
  # ----------------------------------------------------------------------
}
