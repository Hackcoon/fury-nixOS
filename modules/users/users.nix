# ============================================================================
# users.nix — User "fury": groups, per-user package, login shell.
#
# Groups are capability grants: wheel (sudo), networkmanager (no-prompt
# network control), libvirtd (virt-manager without access-denied), wireshark
# (capture without sudo — pairs with programs.wireshark in core/network.nix;
# this membership was missing before, fix #3). zsh itself lives in
# programs/shell.nix; this file only names it as the default shell.
# KEEP MINIMAL: required to log in — never drop.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── User fury: normal user + capability groups ──
  # extraGroups = what fury may do without extra prompts. packages = tiny
  # per-user set (kate here; system-wide apps live in system-packages.nix).
  users.users."fury" = {
    isNormalUser = true;
    description = "Fury";
    extraGroups = [
      "networkmanager"  # manage network connections without a password prompt
      "wheel"           # sudo access
      "libvirtd"        # access VMs in virt-manager without "access denied"
      "wireshark"       # packet capture without sudo — programs.wireshark is
                        # enabled in core/network.nix; this group membership
                        # was missing in the old config (fix #3)
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
  # ----------------------------------------------------------------------

  # ── Default login shell ──
  # zsh itself is configured in programs/shell.nix — this only points logins at it.
  users.defaultUserShell = pkgs.zsh;
  # ----------------------------------------------------------------------
}
