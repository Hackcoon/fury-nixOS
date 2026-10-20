# ============================================================================
# flatpak.nix — Flatpak sandboxed applications.
#
# OPTIONAL: covers the gap where nixpkgs is stale or missing (proprietary
# apps, fast-moving releases). Flathub remote + desktop integration handled
# by the module; add remotes/packages imperatively with `flatpak remote-add`
# / `flatpak install`. Drop for minimal — Nix-native first.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Flatpak daemon ──
  services.flatpak.enable = true;
  # ----------------------------------------------------------------------
}
