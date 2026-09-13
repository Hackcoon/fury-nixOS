# Firefox — system-wide installation via the NixOS module
# (wraps the unwrapped package with policies/wrapping support).
#
# Pywalfox (DMS Option 2): native host wired here so the Pywalfox
# extension finds it without `pywalfox install` (which fails on NixOS —
# store is read-only, see nixpkgs issue #281377). Needs
# ~/.cache/wal/colors.json (symlink to DMS's dank-pywalfox.json) + the
# AMO extension. See danklinux.com docs for DankMaterialShell
# application theming.
{ config, pkgs, lib, ... }:

let
  # nixpkgs' pywalfox-native ships NO manifest file — upstream generates
  # it at `pywalfox install` time by substituting the `<path>` placeholder
  # in its bundled assets/manifest.json. That can't run against the
  # read-only store, and feeding the raw package to nativeMessagingHosts
  # breaks the Firefox wrapper build (empty glob -> `ln` with no operand).
  # So this shim does declaratively what `pywalfox install` does
  # imperatively: same template, store path baked in. (No new file in
  # ./pkgs/ needed — pure glue next to its only consumer.)
  pywalfoxHost = pkgs.runCommand "pywalfox-native-host" { } ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    src=( ${pkgs.pywalfox-native}/lib/python*/site-packages/pywalfox/assets/manifest.json )
    substitute "$src" \
      $out/lib/mozilla/native-messaging-hosts/pywalfox.json \
      --replace-fail '<path>' '${pkgs.pywalfox-native}/bin/pywalfox'
  '';
in
{
  programs.firefox.enable = true;

  # Exposes the shim's manifest to the Firefox wrapper, landing at:
  # /run/current-system/sw/lib/mozilla/native-messaging-hosts/pywalfox.json
  programs.firefox.nativeMessagingHosts.packages = [ pywalfoxHost ];
}
