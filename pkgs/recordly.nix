# ============================================================
# RECORDLY — custom package built from upstream's AppImage
# ============================================================
# Upstream: https://github.com/webadderallorg/Recordly
# Upstream ships Linux ONLY as an AppImage, so we re-package it
# the nixpkgs way (same recipe as pkgs/tolaria.nix):
#
#   fetchurl      → downloads the pinned AppImage into the Nix store,
#                   verified byte-for-byte against `hash`
#   extractType2  → unpacks the AppImage so we can reach icons inside it
#   wrapType2     → builds the real package: a tiny FHS sandbox so
#                   the app finds libraries at "normal" Linux paths
#
# The function arguments below are auto-injected by callPackage from
# configuration.nix — never passed manually.
{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:

let
  # ----------------------------------------------------------
  # HOW TO UPDATE (only 3 lines move together):
  # ----------------------------------------------------------
  # 1. Check https://github.com/webadderallorg/Recordly/releases/latest
  #    Note the tag, e.g. v1.5.0, and the asset name, e.g.
  #    Recordly-linux-x64.AppImage (name has been stable).
  # 2. Change `version` below to "1.5.0" (tag WITHOUT the leading v).
  # 3. Change the `url` to the new download link.
  # 4. Reset `hash` to the placeholder
  #      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  #    and run:
  #      sudo nixos-rebuild build --flake /etc/nixos#nixos
  #    Nix fails on purpose and prints:
  #      specified: sha256-AAAA...
  #      got:       sha256-REALHASH...
  #    Paste the "got:" value into `hash`, rebuild — now it succeeds.
  # 5. Test, then switch:
  #      sudo git -C /etc/nixos add pkgs/recordly.nix
  #      nix-test     # trial activation (your alias)
  #      recordly &   # check record + edit + export
  #      nix-switch   # permanent
  #
  # URL + version + hash are a TRIO — they always change together,
  # or the build fails on purpose (that failure IS the integrity check).
  # ----------------------------------------------------------

  # Package name — becomes $out/bin/recordly and part of the store path.
  pname = "recordly";

  # >>> CHANGE THIS on update (tag without leading v). <<<
  version = "1.4.0";

  # The pinned source. URL and version change together on each release.
  src = fetchurl {
    # >>> CHANGE THIS on update (new tag in the URL). <<<
    url = "https://github.com/webadderallorg/Recordly/releases/download/v1.4.0/Recordly-linux-x64.AppImage";
    # >>> PASTE THE REAL HASH HERE after the first failed build. <<<
    hash = "sha256-N7FsQW7plw4BF6mDmr4LfgJPPwLbdn8aYSJSi4RwSkE=";
  };

  # One-time extraction of the AppImage contents, used ONLY to fish out
  # icon PNGs for the launcher menu.
  # (wrapType2 does its own separate extraction for actually running.)
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

  # We generate our own .desktop instead of copying upstream's, because
  # Electron-builder AppImages rename their .desktop between releases.
  # This one is stable and matches the AUR package (firtoz/recordly-aur):
  #   Exec=recordly, Icon=dev.recordly.app, category AudioVideo.
  desktopItem = makeDesktopItem {
    name = "recordly";
    exec = "recordly %U";
    icon = "dev.recordly.app";
    desktopName = "Recordly";
    comment = "Screen recorder and editor with auto-zoom and cursor effects";
    categories = [ "AudioVideo" "Video" ];
    startupWMClass = "Recordly";
  };

in
appimageTools.wrapType2 {
  inherit pname version src;

  # Recordly is Electron 43 — it bundles almost everything itself.
  # Unlike Tolaria (Tauri) it does NOT need webkitgtk/appindicator.
  # Vulkan is yours and working, no extra GPU libs needed here;
  # if a future release errors with "libSomething.so: cannot open",
  # add the nixpkgs package providing it to extraPkgs below.
  # Example:
  #   extraPkgs = pkgs: with pkgs; [ libsecret ];
  # (extraPkgs receives nixpkgs as its argument, so `with pkgs;`
  # lets you name packages without a `pkgs.` prefix.)

  # NOTE: appimageTools.wrapType2 does NOT run the copyDesktopItems hook,
  # so `desktopItems = [...]` would silently do nothing here (unlike in a
  # normal mkDerivation, e.g. Concat's). The .desktop is installed manually
  # in extraInstallCommands below instead — don't "simplify" it back.

  # Icons live inside the AppImage (confirmed via the AUR PKGBUILD):
  #   usr/share/icons/hicolor/<size>x<size>/apps/recordly.png
  # for sizes 16 24 32 48 64 128 256 512 1024.
  # We install them as dev.recordly.app.png to match Icon= above.
  # The `if` guards mean a future upstream icon reshuffle degrades to
  # a fallback icon instead of failing the whole build — check the
  # menu icon after each update and adjust sizes if needed.
  extraInstallCommands = ''
    # Menu entry. ${desktopItem} is the makeDesktopItem above (renders to
    # share/applications/recordly.desktop); copy it into this package.
    install -m 444 -D ${desktopItem}/share/applications/recordly.desktop \
      $out/share/applications/recordly.desktop
    for size in 16 24 32 48 64 128 256 512 1024; do
      iconSrc="${appimageContents}/usr/share/icons/hicolor/$size"x"$size"/apps/recordly.png
      if [ -f "$iconSrc" ]; then
        install -Dm444 "$iconSrc" $out/share/icons/hicolor/"$size"x"$size"/apps/dev.recordly.app.png
      fi
    done
    # TROUBLESHOOTING (leave commented unless needed):
    # Electron sandbox error on NixOS ("Failed to move to new namespace"):
    #   uncomment the next line to launch with --no-sandbox.
    # wrapProgram $out/bin/recordly --add-flags --no-sandbox
  '';

  meta = {
    description = "Open-source screen recorder and editor with auto-zoom, cursor effects, and polished video export";
    homepage = "https://github.com/webadderallorg/Recordly";
    downloadPage = "https://github.com/webadderallorg/Recordly/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "recordly";
    platforms = [ "x86_64-linux" ];
  };
}
