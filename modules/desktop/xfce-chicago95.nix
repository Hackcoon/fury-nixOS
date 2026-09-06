# XFCE session (Chicago95 theme target).
#
# Registers "Xfce Session" in SDDM next to Plasma — pick per-login.
# The most trouble-free pairing with the NVIDIA driver (no Wayland
# quirks): the X11-fix wrappers in packages/apps-fixed.nix (sioyek,
# upscayl, vesktop) run natively here, no env hacks needed. The
# module auto-enables polkit-gnome agent, NM tray applet, pulseaudio
# plugin + pavucontrol, screensaver + PAM, udisks2/gvfs/tumbler,
# gtk + xapp portals.
{ config, pkgs, lib, ... }:

{
  services.xserver.desktopManager.xfce.enable = true;

  # Allow bitmap fonts — needed for Chicago95's pixelated "Helvetica"
  # (cronyx-cyrillic). Declarative equivalent of upstream's
  # "mv /etc/fonts/conf.d/70-no-bitmaps.conf" step. Harmless for
  # Plasma: it only ALLOWS bitmap fonts, never changes a default.
  fonts.fontconfig.allowBitmaps = true;
}
