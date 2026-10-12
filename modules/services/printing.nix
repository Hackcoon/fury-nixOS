# ============================================================================
# printing.nix — CUPS printing.
#
# OPTIONAL: drop if no printer. Pair with desktop-extras.printing if that
# toggle ever comes back (both target CUPS — enable only one path).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── CUPS print server ──
  services.printing.enable = true;
  # ----------------------------------------------------------------------
}
