# ============================================================================
# desktop-extras.nix — Optional desktop services (ported toggles).
#
# All OFF by default; flip per host in configuration.nix. These are the extra
# knobs from the ported flake — your KDE/SDDM/qylock modules stay untouched.
# OVERLAP WARNINGS (read before enabling):
#   flatpak/printing/appimage duplicate standalone modules (core/flatpak.nix,
#   services/printing.nix, core/appimage.nix) — enable ONE path each.
#   nh duplicates core/nix.nix programs.nh with DIFFERENT retention (7d/keep-5
#   here vs 30d/keep-10 there) — enabling both breaks evaluation (same option
#   set twice). zram/fstrim are the only ones currently on.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.desktop-extras;
in
{
  # ── Options: one toggle per extra ──
  options.desktop-extras = {
    flatpak.enable      = mkEnableOption "Flatpak + flathub remote";
    zram.enable          = mkEnableOption "zram swap (no swap partition needed)";
    fstrim.enable         = mkEnableOption "weekly SSD fstrim";
    nfs.enable            = mkEnableOption "NFS server";
    printing.enable        = mkEnableOption "CUPS printing";
    sane.enable            = mkEnableOption "scanner support (sane-airscan)";
    logitech.enable        = mkEnableOption "Logitech wireless + solaar";
    openrgb.enable         = mkEnableOption "OpenRGB (RGB control)";
    plymouth.enable        = mkEnableOption "boot splash animation";
    appimage.enable        = mkEnableOption "AppImage binfmt support";
    ly-greeter.enable      = mkEnableOption "ly TUI login greeter (replaces SDDM!)";
    nh.enable              = mkEnableOption "nh — nixos-rebuild helper";
  };
  # ----------------------------------------------------------------------

  config = mkMerge [
    # ── Flatpak + flathub remote ──
    # Duplicates core/flatpak.nix (standalone module, currently ON) —
    # enable only one. Remote-add runs as a oneshot service (idempotent).
    (mkIf cfg.flatpak.enable {
      services.flatpak.enable = true;
      systemd.services.flatpak-repo = {
        path = [ pkgs.flatpak ];
        script = ''
          flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        '';
      };
    })
    # ----------------------------------------------------------------------

    # ── zram swap (currently ON): compressed RAM instead of partition ──
    # priority 100 + 30% RAM + zstd. Hibernation caveat (ssd.nix): disk swap
    # outranks this or hibernate targets RAM (nonsense).
    (mkIf cfg.zram.enable {
      zramSwap = {
        enable = true;
        priority = 100;
        memoryPercent = 30;
        swapDevices = 1;
        algorithm = "zstd";
      };
    })
    # ----------------------------------------------------------------------

    # ── SSD trim (currently ON): weekly fstrim ──
    (mkIf cfg.fstrim.enable {
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    })
    # ----------------------------------------------------------------------

    # ── NFS server ──
    (mkIf cfg.nfs.enable {
      services.rpcbind.enable = true;
      services.nfs.server.enable = true;
    })
    # ----------------------------------------------------------------------

    # ── CUPS printing ──
    # Duplicates services/printing.nix (currently ON) — enable only one.
    (mkIf cfg.printing.enable {
      services.printing.enable = true;
      # drivers = [ pkgs.hplipWithPlugin ];
    })
    # ----------------------------------------------------------------------

    # ── Scanners via sane-airscan (driverless network/USB) ──
    # escl backend disabled (breaks some AirScan devices when both claim them).
    (mkIf cfg.sane.enable {
      hardware.sane = {
        enable = true;
        extraBackends = [ pkgs.sane-airscan ];
        disabledDefaultBackends = [ "escl" ];
      };
    })
    # ----------------------------------------------------------------------

    # ── Logitech wireless + solaar ──
    # solaar as plain package (programs.solaar is unfree-gated / may not exist
    # on your nixpkgs — package install always works).
    (mkIf cfg.logitech.enable {
      environment.systemPackages = [ pkgs.solaar ];
      hardware.logitech.wireless.enable = true;
    })
    # ----------------------------------------------------------------------

    # ── OpenRGB: motherboard LED control ──
    # Set motherboard to "amd" on the AMD PC.
    (mkIf cfg.openrgb.enable {
      services.hardware.openrgb = {
        enable = true;
        motherboard = "intel";   # or "amd"
      };
    })
    # ----------------------------------------------------------------------

    # ── Plymouth boot splash ──
    (mkIf cfg.plymouth.enable {
      boot.plymouth.enable = true;
    })
    # ----------------------------------------------------------------------

    # ── AppImage binfmt (PARKED OFF — dead code path) ──
    # Whole block commented: binfmt registration lives in core/appimage.nix
    # instead (currently ON). Re-enable here only if that module goes away.
    #(mkIf cfg.appimage.enable {
      #boot.binfmt.registrations.appimage = {
        #wrapInterpreterInShell = false;
        #interpreter = "${pkgs.appimage-run}/bin/appimage-run";
        #recognitionType = "magic";
        #offset = 0;
        #mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
        #magicOrExtension = ''\x7fELF....AI\x02'';
      #};
    #})
    # ----------------------------------------------------------------------

    # ── ly greeter: Matrix login (REPLACES SDDM — read first) ──
    # Takes the greeter seat like dank-greeter does: disable SDDM (kde.nix)
    # before enabling, or two greeters fight over the seat. Mono white-on-black.
    (mkIf cfg.ly-greeter.enable {
      services.displayManager.ly = {
        enable = true;
        settings = {
          animation = "matrix";
          bigclock = true;
          bg = "0x00000000";        # black
          fg = "0x00FFFFFF";        # white (mono)
          border_fg = "0x00FFFFFF";
          error_fg = "0x00FF0000";
          clock_color = "0x00FFFFFF";
        };
      };
    })
    # ----------------------------------------------------------------------

    # ── nh helper (PARKED — conflicts with core/nix.nix) ──
    # Do NOT enable while core/nix.nix programs.nh is active: different
    # retention (7d/keep-5 here vs 30d/keep-10 there) on the same options =
    # evaluation error. Pick one home for nh and leave the other off.
    (mkIf cfg.nh.enable {
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d --keep 5";
        };
        flake = "/etc/nixos";
      };
      environment.systemPackages = [ pkgs.nix-output-monitor pkgs.nvd ];
    })
    # ----------------------------------------------------------------------
  ];
}
