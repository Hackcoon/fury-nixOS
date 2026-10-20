# ============================================================
# FILMCRAFT — custom package repacked from upstream's tarball
# ============================================================
# Upstream: https://github.com/storytold/filmcraft
# Upstream has NO flake and NO nixpkgs package, so we re-package
# their official Linux tarball the nixpkgs way (same recipe as
# pkgs/photocraft.nix):
#
#   fetchurl         → downloads the pinned tarball into the Nix store,
#                      verified byte-for-byte against `hash`
#   autoPatchelfHook → rewrites the binaries' ELF interpreter + RPATH
#                      so they run from the Nix store (they were linked
#                      against Ubuntu 22.04's glibc >= 2.35)
#   makeWrapper      → puts X11/Wayland/Vulkan/EGL/ALSA libs that upstream
#                      loads at RUNTIME via dlopen (see
#                      packaging/linux/nfpm.yaml) on LD_LIBRARY_PATH
#
# Why the tarball and not a source build?
# - Same reasons as PhotoCraft (see pkgs/photocraft.nix header):
#   huge Rust workspace, release-only features, embedded fonts.
# - The tarball is what upstream's own .deb/.rpm/AppImage are made
#   from (packaging/linux/package.sh stages one FHS tree for all
#   formats), so this package holds the SAME binaries.
#
# The function arguments below are auto-injected by callPackage from
# configuration.nix — never passed manually.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  # --- runtime (dlopened) libs, mirrors packaging/linux/nfpm.yaml ---
  # (differs from PhotoCraft: + ALSA audio + Xrandr, see nfpm.yaml)
  libxkbcommon,
  wayland,
  vulkan-loader,
  libGL,
  alsa-lib,
  fontconfig,
  freetype,
  dbus,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  # ----------------------------------------------------------
  # HOW TO UPDATE: run ./pkgs/filmcraft-update.sh (auto-bumps
  # `version` + `hash` below after cross-checking upstream's
  # SHA256SUMS.txt). Manual recipe mirrors pkgs/photocraft.nix.
  # ----------------------------------------------------------

  pname = "filmcraft";

  # >>> Managed by filmcraft-update.sh (release version, no leading v). <<<
  version = "0.8.0";

  # Pinned source. Upstream tags are v<VERSION> (e.g. v0.8.0) and the
  # Linux x86_64 tarball keeps this name across releases.
  src = fetchurl {
    url = "https://github.com/storytold/filmcraft/releases/download/v${finalAttrs.version}/filmcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    # >>> Managed by filmcraft-update.sh. <<<
    # v0.8.0 tarball, per upstream SHA256SUMS.txt:
    #   b166877905ae8a1b5505066d6dde60d7ce05831cfb309bacd5d7970f4bb017e1
    hash = "sha256-sWaHeQWuihtVBQZtbd5g184Fgxz7MJus1deXD0uwF+E=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Libraries for autoPatchelf's RPATH rewriting. The dlopened ones
  # (X11/Wayland/xkbcommon/Vulkan/EGL/ALSA) must ALSO be on the
  # wrapper's LD_LIBRARY_PATH below — RPATH alone doesn't satisfy
  # dlopen at the "normal" Linux paths the binaries expect.
  buildInputs = [
    stdenv.cc.cc.lib # libgcc_s / libstdc++ (the only direct links)
    libxkbcommon
    wayland
    vulkan-loader
    libGL # libEGL.so.1 (wgpu fallback when no Vulkan)
    alsa-lib # audio playback/monitoring (libasound2 in nfpm.yaml)
    fontconfig
    freetype
    dbus # file-chooser / document portals via rfd
    xorg.libX11 # includes libX11-xcb.so.1
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];

  # The tarball contains ONE top-level dir:
  #   filmcraft-<ver>-linux-x86_64/{bin,share}/...
  # (since 0.8.0; earlier releases nested it under usr/ — the lookup
  # below tolerates either layout).
  sourceRoot = "filmcraft-${finalAttrs.version}-linux-x86_64";

  installPhase = ''
    runHook preInstall

    # Locate the staged FHS tree regardless of top-level dir naming.
    if [ -d "usr/bin" ]; then
      STAGE="usr"
    elif [ -d "${finalAttrs.sourceRoot}/usr/bin" ]; then
      STAGE="${finalAttrs.sourceRoot}/usr"
    else
      STAGE="$(find . -maxdepth 3 -type d -name bin -printf '%h' -quit)"
      echo "filmcraft: using staged tree at $STAGE"
    fi
    test -x "$STAGE/bin/filmcraft" || (echo "filmcraft binary not found under $STAGE" >&2; exit 1)
    test -x "$STAGE/bin/filmcraft-cli" || (echo "filmcraft-cli binary not found under $STAGE" >&2; exit 1)

    mkdir -p $out/bin $out/share
    install -m 755 "$STAGE"/bin/filmcraft $out/bin/filmcraft
    install -m 755 "$STAGE"/bin/filmcraft-cli $out/bin/filmcraft-cli

    # Desktop entry, AppStream metainfo, MIME type, hicolor icons, docs.
    # Upstream .desktop uses Exec=filmcraft + Icon=ai.storyteller.filmcraft,
    # both correct once $out/bin is on PATH and icons live in $out/share.
    cp -r "$STAGE"/share/* $out/share/
    chmod -R u+w $out/share

    runHook postInstall
  '';

  # Wrap AFTER autoPatchelf (postFixup ordering): give the dlopened
  # libs canonical paths. --prefix keeps any user LD_LIBRARY_PATH.
  postFixup = ''
    for bin in filmcraft filmcraft-cli; do
      wrapProgram $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          libxkbcommon
          wayland
          vulkan-loader
          libGL
          alsa-lib
          fontconfig
          freetype
          dbus
          xorg.libX11
          xorg.libxcb
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
        ]}"
    done
  '';

  meta = {
    description = "Open-source, native video editor: timeline editing, color grading, effects and audio mixing (Rust)";
    homepage = "https://github.com/storytold/filmcraft";
    downloadPage = "https://github.com/storytold/filmcraft/releases";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "filmcraft";
    platforms = [ "x86_64-linux" ];
  };
})
