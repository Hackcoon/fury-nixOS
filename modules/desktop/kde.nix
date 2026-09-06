# KDE Plasma 6 + SDDM (Wayland greeter) + power profiles.
{ config, pkgs, lib, ... }:

{
  # X11 windowing base — needed by XWayland apps and the XFCE session
  services.xserver.enable = true;

  # X11 keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # SDDM display manager — Wayland greeter so Qt6 themes render
  # correctly (required by the qylock themes)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Plasma 6 desktop
  services.desktopManager.plasma6.enable = true;

  # KDE's balanced power profile
  services.power-profiles-daemon.enable = true;

  # XWayland support for legacy apps under Wayland
  programs.xwayland.enable = true;
}
