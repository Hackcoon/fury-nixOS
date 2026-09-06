# Apps with KDE/Wayland fixes, via symlinkJoin wrappers.
#
# These three are broken under KDE Wayland:
#   sioyek   -> needs QT_QPA_PLATFORM=xcb
#   upscayl  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
#   vesktop  -> needs NIXOS_OZONE_WL unset + --ozone-platform=x11
#
# IMPORTANT: do NOT also add the raw pkgs.sioyek / pkgs.upscayl /
# pkgs.vesktop to system-packages.nix — the raw packages would
# duplicate these wrappers (this was a live bug in the old
# monolithic config).
{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Sioyek fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "sioyek";
      paths = [ pkgs.sioyek ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb
      '';
    })

    # Upscayl fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "upscayl";
      paths = [ pkgs.upscayl ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/upscayl --unset NIXOS_OZONE_WL --add-flags "--ozone-platform=x11"
      '';
    })

    # Vesktop fix (KDE Wayland fix)
    (pkgs.symlinkJoin {
      name = "vesktop";
      paths = [ pkgs.vesktop ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/vesktop \
          --unset NIXOS_OZONE_WL \
          --add-flags "--ozone-platform=x11"
      '';
    })
  ];
}
