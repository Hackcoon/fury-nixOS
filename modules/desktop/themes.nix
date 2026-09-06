# Cursor theme + related environment variables.
#
# XCURSOR_THEME must match a variant provided by google-cursor
# (installed in packages/system-packages.nix under THEMES & CURSORS).
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
  };
}
