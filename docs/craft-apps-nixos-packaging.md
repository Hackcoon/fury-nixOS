# Running the Craft apps on NixOS (tarball repack recipe)

> Copy everything below the line into a GitHub issue on
> `storytold/photocraft` / `storytold/filmcraft`
> (suggested title: **NixOS packaging: running the official tarball via a small repack derivation**).
> It is written for the maintainers/mods reading the issue, not for this repo.

---

## NixOS packaging: running the official tarball via a small repack derivation

Hi! I run NixOS and wanted PhotoCraft / FilmCraft as native packages.
Since there's no flake or nixpkgs package upstream, I repacked the
**official Linux tarballs** with a small Nix derivation, and it works
great — posting the recipe here in case it helps others (or a future
nixpkgs submission).

### Why the tarball works so well for this

- The Linux binaries link **only glibc (≥ 2.35) and libgcc_s**; X11,
  Wayland, xkbcommon, Vulkan/EGL (and ALSA for FilmCraft) are loaded
  at runtime via `dlopen` (see `packaging/linux/nfpm.yaml`).
- The tarball is the same FHS tree (`usr/bin`, `usr/share`) that
  `package.sh` uses to build the .deb/.rpm/AppImage, so it contains
  both binaries **plus** the `.desktop` entry, AppStream metainfo,
  MIME file and icons.
- No source build needed (24-crate workspace, pinned git deps), and
  the release binaries already include the `heif` feature and the
  embedded CRAFT_FONTS fonts.

### The derivation (works for both apps)

Save as e.g. `pkgs/photocraft.nix` and wire up with
`pkgs.callPackage ./pkgs/photocraft.nix { }`. Swap the three marked
values for FilmCraft (given below).

```nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libxkbcommon,
  wayland,
  vulkan-loader,
  libGL,
  alsa-lib, # FilmCraft only (audio); drop for PhotoCraft
  fontconfig,
  freetype,
  dbus,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "photocraft";          # or "filmcraft"
  version = "0.7.0";             # FilmCraft: "0.6.0"

  src = fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${finalAttrs.version}/photocraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    # FilmCraft: same URL pattern with s/photocraft/filmcraft/
    hash = "sha256-ZB+DElL9MbQ+4aEuVy10QuVlLC5b9iPeCFdBw3DwyR0=";
    # FilmCraft 0.6.0: "sha256-s9cG1Zlpnq12tGop1Wlyh7n3WgvJ60D3cz23ZX2uggQ="
    # (hashes cross-checked against the SHA256SUMS.txt in each release)
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    stdenv.cc.cc.lib
    libxkbcommon
    wayland
    vulkan-loader
    libGL
    alsa-lib # FilmCraft only; drop for PhotoCraft
    fontconfig
    freetype
    dbus
    xorg.libX11
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr # FilmCraft lists it; harmless for PhotoCraft
  ];

  sourceRoot = "photocraft-${finalAttrs.version}-linux-x86_64";

  installPhase = ''
    runHook preInstall
    STAGE="${finalAttrs.sourceRoot}/usr"
    mkdir -p $out/bin $out/share
    install -m 755 "$STAGE"/bin/photocraft $out/bin/photocraft
    install -m 755 "$STAGE"/bin/photocraft-cli $out/bin/photocraft-cli
    cp -r "$STAGE"/share/* $out/share/
    runHook postInstall
  '';

  # The dlopen'ed libs need canonical paths at runtime:
  postFixup = ''
    for bin in photocraft photocraft-cli; do # filmcraft filmcraft-cli for FilmCraft
      wrapProgram $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          libxkbcommon
          wayland
          vulkan-loader
          libGL
          # + alsa-lib for FilmCraft
          fontconfig
          freetype
          dbus
          xorg.libX11
          xorg.libxcb
          xorg.libXcursor
          xorg.libXi
          # + xorg.libXrandr for FilmCraft
        ]}"
    done
  '';

  meta = {
    description = "Open-source, native image editor (Rust)";
    homepage = "https://github.com/storytold/photocraft";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "photocraft";
    platforms = [ "x86_64-linux" ];
  };
})
```

Notes:

- Upstream's `.desktop` files (`Exec=photocraft` /
  `Icon=ai.storyteller.photocraft`, same pattern for FilmCraft) work
  unmodified once `share/` lands in the package.
- `autoPatchelfHook` reports zero unsatisfied dependencies; both
  `--version` flags report the correct release + commit, and the GUI
  starts normally on NixOS 26.05 (Wayland).
- Updates are two lines (`version` + `hash`) since the URL is
  interpolated — I automated it with a script that prefetches the new
  tarball and cross-checks the hash against the release's
  `SHA256SUMS.txt` before bumping. Happy to share it if useful.

If the team ever wants an official nixpkgs package or a `flake.nix`
contributed, this recipe is ~90% of it — the only remaining work is
the nixpkgs review conventions (passthru update script, etc.).
Happy to help test anything Nix-related.
