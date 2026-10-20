# ============================================================================
# fury-dwm.nix — DWM trial session (X11) alongside MangoWC/DMS.
#
# SAFE-BY-DESIGN: only ADDS a fury-dwm session entry + trial packages. Touches
# nothing in mango-dms.nix, kde.nix (greetd still owns the seat), DMS systemd
# target, or ~/.config/mango. Pick per-login in the greeter. Styling base:
# justaguylinux dwm-setup (source at ~/fury-dwm for reference); live configs
# at ~/.config/suckless (dirname stays — scripts reference it); suckless tools
# (dwm/st/slstatus/tabbed) user-built into ~/.local/bin (see ~/fury-dwm/QUICKSTART).
# OPTIONAL/experimental: drop for minimal.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Session entry: Xorg on :1, then dwm ──
  # exportConfiguration writes /etc/X11/xorg.conf — without it Xorg starts
  # driverless (modesetting + nouveau DRI) and dies on NVIDIA proprietary with
  # "Failed to create pixmap" / "failed to create screen resources". This
  # generates the nvidia Device section + ModulePath. Harmless to all other
  # sessions (Wayland ignores xorg.conf; XFCE gets a proper driver).
  # Greeter wrinkle: dank-greeter launches sessions with XDG_SESSION_TYPE=
  # wayland and starts NO X server, so raw `exec dwm` dies with "cannot open
  # display" — the startx wrapper boots Xorg on :1 first (classic greetd+X11
  # recipe), then xinitrc-furydwm runs autostart.sh + dwm with DISPLAY set.
  # Log: tail -n 50 ~/.fury-dwm-session.log
  services.xserver.exportConfiguration = true;
  services.xserver.windowManager.session = [{
    name = "fury-dwm";
    prettyName = "fury-dwm";
    start = ''
      exec >>"$HOME/.fury-dwm-session.log" 2>&1
      echo "=== fury-dwm start: $(date) ==="
      set -x
      exec ${pkgs.xinit}/bin/startx "$HOME/.config/suckless/scripts/xinitrc-furydwm" -- :1
    '';
  }];
  # ----------------------------------------------------------------------

  # ── Trial deps: ONLY what no other module installs ──
  # Already global via other modules (visible here too): rofi, pavucontrol,
  # playerctl, libnotify (hyprland.nix), thunar, flameshot, kitty, gimp
  # (system-packages.nix), brightnessctl, networkmanagerapplet (mango-dms.nix),
  # kitty via home.nix. Standalone-reuse list parked below for other machines.
  environment.systemPackages = with pkgs; [
    sxhkd
    dunst
    picom
    feh
    xbacklight
    geany
    lxsession # provides lxpolkit
    unclutter
    slock # suckless X11 locker for SUPER+ALT+L
    xinit # startx: boots Xorg for the greetd-launched session
    xclip # clip-history daemon + clip-menu (SUPER+V)
    xkill # force-kill window (SUPER+SHIFT+Q)
    # --- Standalone reuse: uncomment if the system lacks these
    # (on fury's machine they're global via the modules noted above) ---
    # rofi
    # thunar
    # pavucontrol
    # playerctl
    # libnotify
    # flameshot
    # kitty
    # gimp
    # brightnessctl
    # networkmanagerapplet
  ];
  # ----------------------------------------------------------------------
}
