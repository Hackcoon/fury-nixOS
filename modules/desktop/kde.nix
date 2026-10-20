# ============================================================================
# kde.nix — KDE Plasma 6 + SDDM + XWayland base.
#
# Display-manager handoff: when the Dank greetd greeter is enabled
# (mango-dms.nix → programs.dms-greeter), greetd owns the seat and SDDM MUST
# be off — NixOS errors if two display managers claim the same seat. Plasma
# sessions stay selectable from the greeter's session list (greetd reads
# wayland-sessions/desktop entries). HEAVY: full DE — keep only if KDE is main.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── X11 base + keyboard ──
  # xserver.enable underpins XWayland apps and the XFCE session (not X11
  # sessions themselves — everything runs Wayland here).
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  # ----------------------------------------------------------------------

  # ── SDDM (Wayland greeter) — auto-yields to Dank greeter ──
  # Wayland greeter so Qt6 themes render correctly (required by qylock themes).
  # The `!dms-greeter` guard disables SDDM the moment greetd takes the seat.
  services.displayManager.sddm.enable = !config.programs.dms-greeter.enable;
  services.displayManager.sddm.wayland.enable = !config.programs.dms-greeter.enable;
  # ----------------------------------------------------------------------

  # ── Plasma 6 + XWayland + power profiles ──
  # power-profiles-daemon is KDE's balanced profile — laptop.nix force-disables
  # it when TLP takes over (governor fight), so no conflict on the laptop.
  services.desktopManager.plasma6.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.xwayland.enable = true; # legacy X11 apps under Wayland
  # ----------------------------------------------------------------------
}
