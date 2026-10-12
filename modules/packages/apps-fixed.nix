# ============================================================================
# apps-fixed.nix — Apps with KDE/Wayland fixes, via symlinkJoin wrappers.
#
# THE THREE BREAKAGES (all under KDE Wayland):
#   sioyek   -> needs QT_QPA_PLATFORM=xcb
#   upscayl  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
#   vesktop  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
# (nvidia.nix deliberately leaves NIXOS_OZONE_WL unset globally for exactly
# these apps — these wrappers finish the job per-app.)
#
# IMPORTANT: do NOT also add raw pkgs.sioyek / pkgs.upscayl / pkgs.vesktop to
# system-packages.nix — the raw packages would duplicate these wrappers (live
# bug in the old monolithic config). OPTIONAL: drop if the trio goes unused.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Wrapped trio: X11-forced sioyek / upscayl / vesktop ──
  # symlinkJoin + makeWrapper: same package, fixed env/flags. Vesktop also gets
  # gnome-libsecret password-store (its default store breaks on this setup).
  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "sioyek";
      paths = [ pkgs.sioyek ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb
      '';
    })

    (pkgs.symlinkJoin {
      name = "upscayl";
      paths = [ pkgs.upscayl ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/upscayl --unset NIXOS_OZONE_WL --add-flags "--ozone-platform=x11"
      '';
    })

    (pkgs.symlinkJoin {
      name = "vesktop";
      paths = [ pkgs.vesktop ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/vesktop \
          --unset NIXOS_OZONE_WL \
          --add-flags "--ozone-platform=x11 --password-store=gnome-libsecret"
      '';
    })

    # ── PARKED: native-Wayland vesktop (stutters — X11 wrapper above wins) ──
    # Preserved whole for easy restoration if Electron/Wayland ever behaves.
    # (pkgs.symlinkJoin {
    #   name = "vesktop-wayland";
    #   paths = [ pkgs.vesktop ];
    #   buildInputs = [ pkgs.makeWrapper ];
    #   postBuild = ''
    #     rm -f $out/bin/vesktop $out/share/applications/vesktop.desktop
    #     makeWrapper ${pkgs.vesktop}/bin/vesktop $out/bin/vesktop-wayland \
    #       --set NIXOS_OZONE_WL 1 \
    #       --add-flags "--ozone-platform=wayland --enable-features=WebRTCPipeWireCapturer --password-store=gnome-libsecret"
    #     cat > $out/share/applications/vesktop-wayland.desktop <<EOF
    #     [Desktop Entry]
    #     Name=Vesktop (Wayland screenshare)
    #     Comment=Vesktop native Wayland — use for screensharing
    #     Exec=vesktop-wayland %U
    #     Icon=vesktop
    #     Terminal=false
    #     Type=Application
    #     Categories=Network;InstantMessaging;Chat;
    #     StartupWMClass=vesktop
    #     EOF
    #   '';
    # })
  ];
  # ----------------------------------------------------------------------
}
