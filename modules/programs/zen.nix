# ============================================================================
# zen.nix — Zen Browser (beta): PARKED at system level, HM-managed instead.
#
# The real config lives in home.nix `programs.zen-browser` (policies,
# fast-start settings, DMS zen.css). This system install stays DISABLED to
# avoid two Zens (system + ~/.nix-profile fighting over defaults). Keep the
# `zenBrowser` flake arg until specialArgs is cleaned up, then delete this file.
# ============================================================================
{ pkgs, lib, zenBrowser, ... }:
{
  # ── System Zen: OFF (Home Manager owns it) ──
  # environment.systemPackages = [ zenBrowser ]; # DISABLED — HM-managed
  # ----------------------------------------------------------------------
}
