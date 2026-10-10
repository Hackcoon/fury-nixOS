# ============================================================================
# brave-webgpu.nix — Brave WebGPU build (grainrad-type sites).
#
# OPTIONAL, off the default path. Toggle via the import in configuration.nix.
# Provides `brave-webgpu` (+ launcher entry, SUPER+SHIFT+G in mango). Default
# `brave` stays the smooth native build from system-packages.nix.
#
# WHY SEPARATE: Vulkan needs X11 ozone (incompatible with ozone/wayland, so
# this runs via XWayland) plus vulkan-loader on LD_LIBRARY_PATH (make-brave
# never adds it to the wrapper's rpath — nvidia.nix provides the loader, this
# wires it into the binary). None of that may touch the daily driver.
# HEAVY: custom browser build — comment out the import to drop it.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Vulkan-enabled Brave, renamed so both can coexist ──
  # override: Vulkan on + X11 ozone + unsafe WebGPU flag. postFixup injects
  # the opengl-driver lib path (loader) and renames binary + desktop entry so
  # `brave` (daily) and `brave-webgpu` (grainrad) install side by side.
  environment.systemPackages = with pkgs; [
    (let
      braveVk = brave.override {
        enableVulkan = true;
        vulkanSupport = true;
        commandLineArgs = "--ozone-platform=x11 --enable-unsafe-webgpu --password-store=gnome-libsecret";
      };
    in
      braveVk.overrideAttrs (prev: {
        postFixup = (prev.postFixup or "") + ''
          if [ -f "$out/bin/brave" ]; then
            sed -i 's|^exec -a "$0"|export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexec -a "$0"|' "$out/bin/brave"
            mv "$out/bin/brave" "$out/bin/brave-webgpu"
          fi
          if [ -f "$out/share/applications/brave-browser.desktop" ]; then
            sed -e 's|/bin/brave|/bin/brave-webgpu|g' -e 's|^Name=Brave Web Browser|Name=Brave WebGPU|' "$out/share/applications/brave-browser.desktop" > "$out/share/applications/brave-webgpu.desktop"
            rm "$out/share/applications/brave-browser.desktop"
          fi
        '';
      }))
  ];
  # ----------------------------------------------------------------------
}
