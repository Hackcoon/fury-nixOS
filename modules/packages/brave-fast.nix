# ============================================================================
# brave-fast.nix — Brave Fast, the daily driver: native Wayland, no overhead.
#
# Declarative replacement for the old imperative ~/.local/bin/brave-fast
# (+ brave-fast.desktop, hand-created 2026-09-12, never in nix). Provides
# `brave-fast` on PATH + launcher entry, so Vicinae/rofi/DMS spotlight keep
# finding it. Hyprland SUPER+B / SUPER+SHIFT+B and Mango SUPER+Y point here.
#
# WHY SEPARATE from plain `brave`: system brave is the smooth build too, but
# this pins native Wayland + no-Vulkan explicitly so a wrapper change can never
# silently flip back to XWayland/Vulkan. WebGPU/grainrad stays on
# `brave-webgpu` (modules/packages/brave-webgpu.nix). OPTIONAL: drop
# if plain brave suffices.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Wrapper script + desktop entry ──
  # NIXOS_OZONE_WL=1 + wayland ozone + Vulkan/WebGPU features off +
  # gnome-libsecret store. makeDesktopItem registers the launcher (icon +
  # WMClass pin it to brave windows).
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "brave-fast" ''
      export NIXOS_OZONE_WL=1
      exec ${brave}/bin/brave --ozone-platform=wayland --disable-features=Vulkan,WebGPU --password-store=gnome-libsecret "$@"
    '')
    (makeDesktopItem {
      name = "brave-fast";
      desktopName = "Brave Fast (Wayland, no WebGPU)";
      comment = "Daily Brave: native Wayland, no Vulkan/WebGPU overhead.";
      exec = "brave-fast %U";
      icon = "brave";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      startupWMClass = "brave-browser";
    })
  ];
  # ----------------------------------------------------------------------
}
