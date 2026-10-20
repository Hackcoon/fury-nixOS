# ============================================================================
# xfce-chicago95.nix — XFCE session (Chicago95 Win95 target), pick per-login.
#
# Registers "Xfce Session" in the greeter next to Plasma. Most trouble-free
# NVIDIA pairing (no Wayland quirks): the X11-fix wrappers in
# packages/apps-fixed.nix (sioyek, upscayl, vesktop) run natively here, no env
# hacks. The module auto-enables polkit-gnome agent, NM tray applet, pulseaudio
# plugin + pavucontrol, screensaver + PAM, udisks2/gvfs/tumbler, gtk + xapp
# portals. OPTIONAL (3rd DE): drop for minimal.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── XFCE session + bitmap fonts for Chicago95 ──
  # allowBitmaps = Chicago95's pixelated "Helvetica" (cronyx-cyrillic).
  # Declarative equivalent of upstream's "mv /etc/fonts/conf.d/70-no-bitmaps.
  # conf" step. Harmless for Plasma: only ALLOWS bitmaps, never changes a default.
  services.xserver.desktopManager.xfce.enable = true;
  fonts.fontconfig.allowBitmaps = true;
  # ----------------------------------------------------------------------
}
