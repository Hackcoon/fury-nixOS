# ============================================================
# PHOTOCRAFT — custom package repacked from upstream's tarball
# ============================================================
# Upstream: https://github.com/storytold/photocraft
# Upstream has NO flake and NO nixpkgs package, so we re-package
# their official Linux tarball the nixpkgs way:
#
#   fetchurl         → downloads the pinned tarball into the Nix store,
#                      verified byte-for-byte against `hash`
#   autoPatchelfHook → rewrites the binaries' ELF interpreter + RPATH
#                      so they run from the Nix store (they were linked
#                      against Ubuntu 22.04's glibc >= 2.35)
#   makeWrapper      → puts X11/Wayland/Vulkan/EGL libs that upstream
#                      loads at RUNTIME via dlopen (see
#                      packaging/linux/nfpm.yaml + apps/photocraft/src/
#                      linux_libs.rs) on LD_LIBRARY_PATH, so the app's
#                      startup library check passes instead of exit(1)
#
# Why the tarball and not a source build?
# - The workspace is 24 crates + a pinned git dep (craft-libs) and
#   needs Rust >= 1.95; a source build means vendoring the whole
#   Cargo.lock closure and a ~20-30 min compile on this box.
# - Upstream's release binaries already bundle the optional `heif`
#   feature + embedded CRAFT_FONTS_DIR Japanese fonts; a local
#   `cargo build` without those inputs ships a lesser app.
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
  libxkbcommon,
  wayland,
  vulkan-loader,
  libGL,
  fontconfig,
  freetype,
  dbus,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  # ----------------------------------------------------------
  # HOW TO UPDATE (version + url + hash move together):
  # ----------------------------------------------------------
  # 1. Check https://github.com/storytold/photocraft/releases/latest
  #    Note the tag, e.g. v0.7.1, and confirm the asset name pattern
  #    below is unchanged (photocraft-<ver>-linux-x86_64.tar.gz).
  # 2. Change `version` below to "0.7.1" (WITHOUT the leading v).
  # 3. Reset `hash` to the placeholder
  #      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  #    and run:
  #      sudo nixos-rebuild build --flake /etc/nixos#nixos
  #    Nix fails on purpose and prints:
  #      specified: sha256-AAAA...
  #      got:       sha256-REALHASH...
  #    Paste the "got:" value into `hash`, rebuild — now it succeeds.
  # 4. Test, then switch:
  #      sudo git -C /etc/nixos add pkgs/photocraft.nix
  #      nix-test          # trial activation (your alias)
  #      photocraft --version && photocraft-cli --version
  #      nix-switch        # permanent
  #
  # Alternatively the expected hash is published upstream in
  # SHA256SUMS.txt next to the release assets (hex format — convert
  # with: python3 -c "import base64;print('sha256-'+base64.b64encode(
  # bytes.fromhex('<hex>').decode())").
  # ----------------------------------------------------------

  pname = "photocraft";

  # >>> CHANGE THIS on update (release version, no leading v). <<<
  version = "0.9.0";

  # Pinned source. Upstream tags are v<VERSION> (e.g. v0.9.0) and the
  # Linux x86_64 tarball keeps this name across releases.
  src = fetchurl {
    # >>> CHANGE THIS on update (new tag in the URL). <<<
    url = "https://github.com/storytold/photocraft/releases/download/v${finalAttrs.version}/photocraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    # >>> PASTE THE REAL HASH HERE after the first failed build. <<<
    # v0.9.0 tarball, per upstream SHA256SUMS.txt:
    #   91300c1485ad710839604b085531c90e77ac7ebdb2a30259309ad74afcfdb90d
    hash = "sha256-kTAMFIWtcQg5YEsIVTHJDnesfr2yowJZMJrXSvz9uQ0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Libraries for autoPatchelf's RPATH rewriting. The dlopened ones
  # (X11/Wayland/xkbcommon/Vulkan/EGL) must ALSO be on the wrapper's
  # LD_LIBRARY_PATH below — RPATH alone doesn't satisfy dlopen at
  # the "normal" Linux paths the binaries expect.
  buildInputs = [
    stdenv.cc.cc.lib # libgcc_s / libstdc++ (the only direct links)
    libxkbcommon
    wayland
    vulkan-loader
    libGL # libEGL.so.1 (wgpu fallback when no Vulkan)
    fontconfig
    freetype
    dbus # file-chooser / document portals via rfd
    xorg.libX11 # includes libX11-xcb.so.1
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
  ];

  # The tarball contains ONE top-level dir:
  #   photocraft-<ver>-linux-x86_64/{bin,share}/...
  # (since 0.9.0; earlier releases nested it under usr/, i.e.
  # photocraft-<ver>-linux-x86_64/usr/{bin,share} — the lookup below
  # tolerates either layout).
  sourceRoot = "photocraft-${finalAttrs.version}-linux-x86_64";

  installPhase = ''
    runHook preInstall

    # Locate the staged FHS tree regardless of top-level dir naming.
    if [ -d "usr/bin" ]; then
      STAGE="usr"
    elif [ -d "${finalAttrs.sourceRoot}/usr/bin" ]; then
      STAGE="${finalAttrs.sourceRoot}/usr"
    else
      STAGE="$(find . -maxdepth 3 -type d -name bin -printf '%h' -quit)"
      echo "photocraft: using staged tree at $STAGE"
    fi
    test -x "$STAGE/bin/photocraft" || (echo "photocraft binary not found under $STAGE" >&2; exit 1)
    test -x "$STAGE/bin/photocraft-cli" || (echo "photocraft-cli binary not found under $STAGE" >&2; exit 1)

    mkdir -p $out/bin $out/share
    install -m 755 "$STAGE"/bin/photocraft $out/bin/photocraft
    install -m 755 "$STAGE"/bin/photocraft-cli $out/bin/photocraft-cli

    # Desktop entry, AppStream metainfo, MIME type, hicolor icons, docs.
    # Upstream .desktop uses Exec=photocraft + Icon=ai.storyteller.photocraft,
    # both correct once $out/bin is on PATH and icons live in $out/share.
    cp -r "$STAGE"/share/* $out/share/
    chmod -R u+w $out/share

    runHook postInstall
  '';

  # Wrap AFTER autoPatchelf (postFixup ordering): give the dlopened
  # libs canonical paths. --prefix keeps any user LD_LIBRARY_PATH.
  postFixup = ''
    for bin in photocraft photocraft-cli; do
      wrapProgram $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          libxkbcommon
          wayland
          vulkan-loader
          libGL
          fontconfig
          freetype
          dbus
          xorg.libX11
          xorg.libxcb
          xorg.libXcursor
          xorg.libXi
        ]}"
    done
  '';

  meta = {
    description = "Open-source, native image editor with layers, masks, type and real PSD files (Rust)";
    homepage = "https://github.com/storytold/photocraft";
    downloadPage = "https://github.com/storytold/photocraft/releases";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "photocraft";
    platforms = [ "x86_64-linux" ];
  };
})
