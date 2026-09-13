# ============================================================
# TOLARIA — custom package built from upstream's AppImage
# ============================================================
# Upstream (https://github.com/refactoringhq/tolaria) ships Linux
# builds only as an AppImage. This file re-packages it the nixpkgs way:
#
#   fetchurl      → downloads the pinned AppImage into the Nix store,
#                   verified byte-for-byte against `hash`
#   extractType2  → unpacks the AppImage so we can reach the .desktop
#                   launcher and icons inside it
#   wrapType2     → builds the actual package: a tiny FHS sandbox so
#                   the app finds libraries at the "normal" Linux
#                   paths it was compiled to expect
#
# The function arguments below are auto-injected by callPackage from
# configuration.nix (dependency injection, Nix-style) — never passed
# manually. Only the ones this package actually uses are listed.
{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  webkitgtk_4_1,
  libayatana-appindicator,
  librsvg,
}:

let
  # Package name — becomes /bin/tolaria and part of the store path.
  pname = "tolaria";

  # NOTE: upstream future-dates versions (this release was built
  # 2026-09-08, tag v2026-09-08). Expected — don't "fix" it.
  version = "2026.9.8";

  # The pinned source. URL and version change together on each release.
  # `hash` is the content-addressed SHA-256 — Nix refuses to build if
  # upstream's file at this URL ever changes bytes (supply-chain guard).
  src = fetchurl {
    url = "https://github.com/refactoringhq/tolaria/releases/download/v2026-09-08/Tolaria_2026.9.8_amd64.AppImage";
    hash = "sha256-T01UvTWHe8f0nGvsrU5txsmCv39GSzdNCG5uROKXkyM=";
  };

  # One-time extraction of the AppImage contents, used ONLY to fish out
  # the .desktop file and icon PNGs for the launcher menu.
  # (wrapType2 does its own separate extraction for actually running.)
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

in
appimageTools.wrapType2 {
  inherit pname version src;

  # Libraries injected into the app's FHS sandbox — what the AppImage
  # expects the HOST system to provide (Tauri's documented Linux deps),
  # translated to nixpkgs attribute names.
  extraPkgs = pkgs: [
    webkitgtk_4_1
    libayatana-appindicator
    librsvg
  ];

  # Build-time tools (vs runtime libraries above).
  nativeBuildInputs = [ makeWrapper ];

  # Adds what a "real" package has but an AppImage lacks — a menu
  # entry and themed icons. Upstream ships Tolaria.desktop (capital T)
  # with Exec=tolaria, and icons at 32/128/256 (plus a 256@2 variant).
  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/Tolaria.desktop $out/share/applications/tolaria.desktop
    for size in 32 128; do
      install -Dm444 -t $out/share/icons/hicolor/"$size"x"$size"/apps \
        ${appimageContents}/usr/share/icons/hicolor/"$size"x"$size"/apps/tolaria.png
    done
    # 256px icon ships only as the 256x256@2 hiDPI variant — install it
    # as the regular 256 slot.
    install -Dm444 -t $out/share/icons/hicolor/256x256/apps \
      ${appimageContents}/usr/share/icons/hicolor/256x256@2/apps/tolaria.png
    # NVIDIA proprietary EGL can't create dri2 screens for WebKitGTK's
    # DMABUF renderer ("egl: failed to create dri2 screen" -> falls back
    # to software rendering = black screen / laggy scrolling). Disabling
    # the DMABUF renderer fixes it on this GTX 1660 driver combo.
    wrapProgram $out/bin/tolaria --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
  '';

  # Package metadata — consumed by nix search, tooling, and audits.
  meta = {
    description = "Desktop app to manage markdown knowledge bases";
    homepage = "https://github.com/refactoringhq/tolaria";
    downloadPage = "https://github.com/refactoringhq/tolaria/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "tolaria";
    platforms = [ "x86_64-linux" ];
  };
}
