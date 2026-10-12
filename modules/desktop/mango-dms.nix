# ============================================================================
# mango-dms.nix — MangoWC (Wayland compositor) + DankMaterialShell 1.6.
#
# One module wiring the full MangoWC + DMS stack (danklinux.com/docs/
# dankmaterialshell/nixos): DMS user service bound to a dedicated
# mango-session.target so it only runs inside MangoWC sessions, never
# alongside KDE/Hyprland/xfce (multi-DE machine). The ~/.config/mango side
# (session target, keybinds, rules, dms fragments) is NOT Nix-managed —
# hot-reloadable by mango itself (see ~/.config/mango/config.conf).
# HEAVY: MangoWC builds from an upstream tag (below) — drop for minimal.
# ============================================================================
{ config, pkgs, lib, unstablePkgs, ... }:

{
  # ── 1) MANGOWC: the compositor (unstable, currently 0.17.5) ──
  # DMS 1.6's mango integration (bar workspaces/tags, layout awareness,
  # Settings → Compositor) talks to the MANGO_INSTANCE_SIGNATURE IPC socket,
  # which mango only gained in 0.14.0. Stable nixpkgs (26.05) ships 0.12.8 —
  # too old (dankbar shows NO workspaces).
  # 2026-10-08: nixos-unstable now ships 0.17.5 (= upstream latest V0.17.5),
  # so the old 0.17.3 overrideAttrs is dropped — plain unstable package.
  # HOW TO UPDATE MANGO IN FUTURE: check https://github.com/mangowm/mango/releases/latest,
  # then `sudo nix flake update nixpkgs-unstable`. If unstable lags upstream,
  # re-add overrideAttrs with new tag+hash (nix will tell you the hash on build).
  # Breaking changes checked 2026-09-15: config has no tablet_map_to_mon /
  # touch_map_to_mon (use devicerule if needed).
  programs.mangowc = {
    enable = true;
    package = unstablePkgs.mangowc;   # 0.17.5 — new IPC, DMS-compatible
    # package = pkgs.mangowc;        # stable 0.12.8 — no DMS bar support
  };
  # ----------------------------------------------------------------------

  # ── 2) DMS 1.6: the desktop shell, bound to the mango session ──
  # programs.dank-material-shell = upstream DMS 1.6 module (flake input `dms`,
  # pinned v1.6.0 — nixpkgs programs.dms-shell is 1.4.6 under another name).
  # Target mango-session.target (drop-in at ~/.config/systemd/user/) instead of
  # graphical-session: DMS starts when MangoWC starts, stops when it exits.
  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true;
      target = "mango-session.target";
    };
  };
  # ----------------------------------------------------------------------

  # ── 3) DANK GREETER: greetd login screen (kills SDDM when on) ──
  # Standalone since DMS 1.6. Requires greetd; only one display manager can own
  # the seat, so SDDM goes off in kde.nix while this is enabled. Greeter =
  # *login* screen only; in-session locking is DMS's own Lock module (fury-bar
  # via dms CLI), hyprlock/kscreenlocker cover Hyprland/KDE sessions.
  # Greeter config copies fury's DMS config (wallpaper/theme) into
  # /var/lib/dms-greeter at start instead of defaults. Hyprland renders it
  # (already installed — no extra compositor). 1080p60 cap: fury's monitor
  # glitches at 144Hz (half screen cut). customConfig REPLACES the greeter's
  # default Hyprland config (only misc.disable_hyprland_logo), so keep that
  # line — empty monitor name = all outputs. NOTE: lowercase "hyprland".
  programs.dms-greeter = {
    enable = true;
    configHome = "/home/fury";
    compositor.name = "hyprland";
    compositor.customConfig = ''
      misc {
          disable_hyprland_logo = true
      }

      monitor=,1920x1080@60,auto,1
    '';
  };
  # (greetd owns the seat now; SDDM off via kde.nix when dms-greeter.enable.)
  # ----------------------------------------------------------------------

  # ── 4) SESSION: pick Mango in the greeter list ──
  # programs.mangowc already registers the wayland session; nothing extra.
  # ----------------------------------------------------------------------

  # ── 5) EXTRAS: utils DMS/MangoWC expect on PATH ──
  environment.systemPackages = with pkgs; [
    wl-clipboard               # clipboard + cliphist store (DMS clipboard history)
    cliphist
    pamixer                    # DMS audio widget fallback CLI
    brightnessctl              # DMS brightness widget fallback CLI
    networkmanagerapplet        # fallback tray applet
    wofi                       # xdg-desktop-portal-wlr screencast chooser
    wmenu                      # xdg-desktop-portal-wlr screencast chooser (alt)
  ];
  # ----------------------------------------------------------------------

  # ── 6) PORTAL: mango session -> wlroots screencast ──
  # wlroots portal installed in portals.nix; route the mango session
  # (DesktopNames=mango;wlroots) to it. mkForce beats the nixpkgs mangowc
  # module's plain "gtk" default — wlr implements ScreenCast for wlroots
  # compositors, gtk stays the file-picker fallback. UPower tile needs
  # nothing here (default-on with power-profiles-daemon via mkDefault).
  xdg.portal.config.mango.default = lib.mkForce [ "wlr" "gtk" ];
  # ----------------------------------------------------------------------
}
