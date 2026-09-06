# Home Manager configuration for user "fury".
#
# This is the NixOS-integrated variant (no standalone `home-manager`
# switch needed — changes apply via nixos-rebuild). The flake wires
# this file in via:
#
#     home-manager.users.fury = import ./home.nix;
#
# START SMALL: for now this manages only git's user config, which
# was previously hand-written in ~/.gitconfig (git's own includeIf
# logic now lives in programs.git.includes below). Everything else
# user-level is still managed by NixOS modules; migrate things in
# ONE AT A TIME, running `nix-test` after each:
#
#   TODO migrate from modules/programs/shell.nix:
#     - programs.zsh          (aliases, oh-my-zsh, plugins, prompts)
#     - programs.direnv       (user-level shells)
#     - zoxide / fzf init     (currently in interactiveShellInit)
#   TODO migrate from modules/packages/system-packages.nix:
#     - "user" apps: editors (vscodium, fresh-editor), AI tools
#       (lmstudio, cherry-studio, opencode*), brave/librewolf,
#       mailspring, obsidian/logseq/anytype, gimp/krita/inkscape...
#     - kitty config          (programs.kitty, + terminal font)
#   TODO new, user-only things that HM makes easy:
#     - programs.git          (done — see below)
#     - programs.ssh          (config entries, not keys!)
#     - xdg.mimeApps          (default browser, file associations)
#     - services.gpg-agent    (pinentry path)
#
# NOTE: HM takes over files it manages. If HM errors "conflicting
# existing file", it found a hand-made file (e.g. ~/.gitconfig).
# The fix is `home-manager` backup semantics — by default HM moves
# the old file to *~<hash> backup instead of failing; check those
# backups once, then delete.
{ config, pkgs, lib, ... }:

{
  home.username = "fury";
  home.homeDirectory = "/home/fury";
  # Matches system.stateVersion — do not change.
  home.stateVersion = "26.05";

  # Let HM manage itself inside your user profile when you install
  # the home-manager CLI later (it is already in systemPackages).
  programs.home-manager.enable = true;

  # ----------------------------------------------------------------
  # MIGRATED: git (first real HM-managed config)
  # ----------------------------------------------------------------
  programs.git = {
    enable = true;

    # Sensible defaults; adjust to taste. (These write into
    # ~/.config/git/config — your existing ~/.gitconfig is
    # preserved as a backup by HM on first activation.)
    settings = {
      user.name  = "furynix";
      user.email = "235014707+Hackcoon@users.noreply.github.com";

      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      diff.colorMoved = "default";
    };
  };

  # delta — nicer diffs; on HM 26.05 this is a top-level option,
  # not programs.git.delta. It wires itself into git automatically
  # (interactive diff/pager). Set a theme once you check `man delta`.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
