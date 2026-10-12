# ============================================================================
# nix.nix — Nix-the-package-manager: settings, caches, GC, helpers.
#
# Build parallelism for a 12-thread / 31GB box, Flakes + store optimization,
# CUDA/comfyui binary caches (so CUDA packages download instead of compiling),
# `nh` as the ONLY garbage collector (weekly, 30d + 10-gen floor), nix-ld
# for unpatched binaries. For minimal/fastest builds set cudaSupport=false.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Build parallelism (8 threads x 2 jobs) ──
  # Was cores=2 max-jobs=1 to avoid overheat, but that made any source build
  # ~6x slower (hours on this 12-thread machine). 8/2 is safe for 31GB RAM;
  # drop to 6/1 if hot. Revert to 2 and 1 if thermals demand it.
  nix.settings.cores = 8;      # threads per build (was 2; 0 = all 12)
  nix.settings.max-jobs = 2;   # concurrent builds (was 1; auto = 12)
  # ----------------------------------------------------------------------

  nix.settings = {
    # ── Flakes + store optimization ──
    # Modern Nix commands and automatic store dedup to save disk.
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # ----------------------------------------------------------------------

    # ── Binary caches: pre-built CUDA packages ──
    # Without these, anything with cudaSupport=true compiles from source
    # locally (cache.nixos.org doesn't build CUDA). The official cache is
    # merged in automatically alongside this list — verified in live
    # /etc/nix/nix.conf. comfyui.cachix.org + nix-community.cachix.org come
    # from the comfyui-nix FLAKE: pre-built ComfyUI + PyTorch CUDA wheels
    # (~2GB download instead of a multi-hour source build). The daemon must
    # trust these keys or the flake falls back to compiling torch/CUDA locally.
    substituters = [
      "https://cache.nixos-cuda.org"
      "https://comfyui.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    # ----------------------------------------------------------------------

    # ── trusted-users: fury runs Nix without sudo ──
    # `nix profile install`, `nh os switch`, and later Home Manager operate
    # without sudo. Single-user desktop with wheel/sudo: convenience, not a
    # security boundary change.
    trusted-users = [ "root" "fury" ];
    # ----------------------------------------------------------------------
  };

  # ── CUDA support globally ON (flip for minimal) ──
  # Enables CUDA in every nixpkgs package that supports it (blender, ffmpeg,
  # ML libs...). Combined with the caches above, those are fetched pre-built
  # instead of compiled. Set false for fastest/minimal builds.
  nixpkgs.config.cudaSupport = true;
  # ----------------------------------------------------------------------

  # ── EOL Electron/pnpm that some apps still need ──
  # Better long-term fix: find which app pulls each one in and update that app.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    "electron-39.8.10"
    "pnpm-10.29.2"
  ];
  # ----------------------------------------------------------------------

  # ── Garbage collection: `nh clean` ONLY (nix.gc stays off) ──
  # Do NOT enable both: each creates its own weekly GC timer and they race on
  # the store lock (nixpkgs warns for exactly this combination). `nh clean` is
  # a superset of nix-collect-garbage (retention by count AND age, gcroot
  # cleanup) and its timer is Persistent=true, so missed weekly runs catch up
  # after boot — nix.gc's timer doesn't, runs are lost when the machine is off.
  # nix.gc = {
  #   automatic = true;
  #   dates = "weekly";
  #   options = "--delete-older-than 30d";
  # };
  programs.nh = {
    enable = true;
    flake = "/etc/nixos"; # `nh os switch` uses /etc/nixos#nixos automatically
    clean = {
      enable = true;
      dates = "weekly";   # timer is Persistent (catches up after downtime)

      # Without extraArgs, nh defaults to --keep 1 --keep-since 0h (current
      # generation only!), which would silently kill rollback safety. This
      # restores the old policy plus a floor:
      #   --keep-since 30d : keep everything from the last 30 days
      #                       (same as the old nix.gc options)
      #   --keep 10        : always keep at least 10 generations,
      #                       even if older (rollback floor)
      #   --keep-one       : keep one gcroot per direnv project so
      #                       active dev shells (nix-direnv in
      #                       programs/shell.nix) survive GC
      extraArgs = "--keep-since 30d --keep 10 --keep-one";
    };
  };
  # ----------------------------------------------------------------------

  # ── nix-ld: run unpatched dynamic binaries ──
  # Needed for non-FHS-compliant binaries (npm/node tarballs, AppImages
  # outside binfmt, proprietary tools). Harmless when unused.
  programs.nix-ld.enable = true;
  # ----------------------------------------------------------------------
}
