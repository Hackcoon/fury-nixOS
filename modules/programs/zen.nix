# Zen Browser (beta) — NOW Home Manager-managed (see home.nix
# `programs.zen-browser`: policies, fast-start settings, DMS zen.css).
# This system-level install is DISABLED to avoid two Zens (system +
# ~/.nix-profile). Keep the `zenBrowser` arg until flake.nix specialArgs
# is cleaned up, then drop it.
{ pkgs, lib, zenBrowser, ... }:
{
  # environment.systemPackages = [ zenBrowser ]; # DISABLED — HM-managed
}
