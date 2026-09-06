# Cursor + GTK theme environment variables.
#
# XCURSOR_THEME must match a variant provided by google-cursor
# (installed in packages/system-packages.nix under THEMES & CURSORS).
#
# GTK_THEME: forces the GTK theme at the library level for ALL GTK
# apps, overriding gsettings/xsettings. WHY: Electron apps (vscodium,
# brave, mailspring...) render native menus/dialogs with GTK, and
# the xfce4/Chicago95 session's xsettings daemon sets the system
# gtk-theme to Chicago95 — which then leaked into those apps even
# under Plasma. Pinning to Breeze-Dark (present in /run/current-
# system/sw/share/themes/ via the breeze-gtk package) keeps
# Electron UIs consistent with the Plasma look in every session.
# GTK_THEME takes precedence over the user's gsettings value, so
# the Win95 theme can no longer leak into GTK apps.
{ config, pkgs, lib, ... }:

{
  environment.variables = {
    # Variant options: GoogleDot-Blue, GoogleDot-Black, GoogleDot-White, GoogleDot-Red
    # Other themes: phinger-cursors (most over-engineered),
    #   Borealis-cursors, bibata-cursors-translucent, bibata-cursors
    #   macOS-like: apple-cursor, afterglow-cursors-recolored
    #   Windows-like: openzone-cursors
    XCURSOR_THEME = "GoogleDot-Black";

    # Standard cursor sizes: 22, 24, 32, 48, 64
    XCURSOR_SIZE = "22";

    # Dark GTK theme for Electron/Chromium apps under Plasma.
    # NOTE: in the XFCE session, XFCE's own widgets keep the Win95
    # Chicago95 look — its xsettings daemon sets the theme at the
    # session level for XFCE's own toolkit, and GTK_THEME here only
    # affects apps that read the environment variable (Electron
    # always does).
    GTK_THEME = "Breeze-Dark";
  };
}
