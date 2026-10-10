# ============================================================================
# firefox.nix — Firefox (NixOS module build) + Pywalfox native host.
#
# Pywalfox = DMS theme matching for Firefox. The native host is wired here so
# extension finds it without `pywalfox install` (fails on NixOS: store is
# read-only, nixpkgs issue #281377). Also needs ~/.cache/wal/colors.json
# (symlink to DMS's dank-pywalfox.json) + the AMO extension. OPTIONAL: 2nd
# browser — drop if Brave/Zen suffice.
# ============================================================================
{ config, pkgs, lib, ... }:

let
  # ── pywalfox shim: declarative `pywalfox install` ──
  # nixpkgs' pywalfox-native ships NO manifest — upstream generates it at
  # install time by substituting the `<path>` placeholder in its bundled
  # assets/manifest.json. That can't run against the read-only store, and
  # feeding the raw package to nativeMessagingHosts breaks the Firefox wrapper
  # build (empty glob -> `ln` with no operand). So this shim does declaratively
  # what `pywalfox install` does imperatively: same template, store path baked
  # in. Pure glue next to its only consumer — no new file in ./pkgs/ needed.
  pywalfoxHost = pkgs.runCommand "pywalfox-native-host" { } ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    src=( ${pkgs.pywalfox-native}/lib/python*/site-packages/pywalfox/assets/manifest.json )
    substitute "$src" \
      $out/lib/mozilla/native-messaging-hosts/pywalfox.json \
      --replace-fail '<path>' '${pkgs.pywalfox-native}/bin/pywalfox'
  '';
in
{
  # ── Firefox + shim manifest ──
  # System-wide module build (policies/wrapping support). The manifest lands at
  # /run/current-system/sw/lib/mozilla/native-messaging-hosts/pywalfox.json.
  programs.firefox.enable = true;
  programs.firefox.nativeMessagingHosts.packages = [ pywalfoxHost ];
  # ----------------------------------------------------------------------
}
