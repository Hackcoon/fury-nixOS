# =============================================================================
# tide-island — Nix package for the Tide Island Dynamic Island (Quickshell/QML/C++)
# Project: https://github.com/enhaoswen/Tide-island  (v1.0.38, GPL-3.0)
#
# This package has been BUILD- and RUN-VALIDATED (see tide-island-local.nix
# for the same derivation built from a local checkout — both compile and the
# launcher successfully starts quickshell with shell.qml loading all modules
# on a live Wayland session).
#
# Build layout produced by upstream CMake (verified against CMakeLists.txt):
#   $out/bin/tide-island                     ← launcher (configure_file'd)
#   $out/bin/tide-island-config-app           ← settings GUI (QtQuickControls2)
#   $out/share/tide-island/shell.qml, DynamicIslandWindow.qml, qml/**, bin/lyricsmpris
#   $out/lib/libIslandBackend.so
#   $out/lib/qt6/qml/IslandBackend/**        ← QML plugin + qmltypes
#   $out/lib/qt6/qml/TideIsland/**           ← config app QML module
#   $out/share/applications/tide-island{,-config}.desktop
#   $out/share/systemd/user/tide-island.service
#
# Nix-specific fixes applied (learned from the validation build):
#   1. launcher hardcodes /usr/bin/quickshell  → substituted to nix store
#   2. desktop files hardcode /usr/bin/...      → bare names (resolved by wrapper)
#   3. launcher is a bash script, so wrapQtAppsHook ignores it — we wrap it
#      manually with all Qt QML import paths (Qt5Compat.GraphicalEffects etc.)
#   4. qtquickcontrols2/qtquickdialogs2 are inside qtdeclarative in nixpkgs Qt6
#   5. CMake needs python3 (find_program for the wallpaper tests)
# =============================================================================
{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  python3,
  fetchFromGitHub,
  wrapQtAppsHook ? qt6.wrapQtAppsHook,

  # Qt — all from the same qt6 set (mixing versions breaks QML plugins).
  # In nixpkgs ≥ 6.7 these all live under qt6.*:
  qt6,
  qtbase ? qt6.qtbase,
  qtdeclarative ? qt6.qtdeclarative,
  qt5compat ? qt6.qt5compat,
  qtwayland ? qt6.qtwayland,
  qtconnectivity ? qt6.qtconnectivity,
  qtsvg ? qt6.qtsvg,

  # runtime
  quickshell,   # nixpkgs 0.3.0 = the exact version Tide pins upstream
  systemd,     # libudev (find_library(UDEV_LIB udev))

  # optional runtime helper (island brightness keys):
  brightnessctl ? null,
}:

let
  version = "1.0.38";

  # QML module path entries every Qt package contributes:
  qmlPath = p: "${p}/lib/qt-6/qml";
  qsQmlPaths = lib.concatStringsSep ":" (
    map qmlPath [
      qtbase
      qtdeclarative
      qt5compat
      qtwayland
      qtsvg
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tide-island";
  inherit version;

  src = fetchFromGitHub {
    owner = "enhaoswen";
    repo = "Tide-island";
    # tag "1.0.38" (they don't prefix with 'v'):
    rev = "9bcc4ec08cb5563ffdd8e4ceb00b983ee28e8e9d";
    hash = "sha256-z7uynD+uzrPw5SzB7X0Ati2kgB+jzOja9WPlKqfN9c8=";
  };

  # ── native build ──────────────────────────────────────────────────────────
  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    python3
    wrapQtAppsHook
    qtdeclarative          # qmlcachegen for qt_add_qml_module
    qt6.qtshadertools
  ];

  buildInputs = [
    qtbase
    qtdeclarative
    qt5compat              # Qt5Compat.GraphicalEffects imports
    qtwayland              # layer-shell
    qtconnectivity
    qtsvg
    systemd                # libudev
  ];
  # NOTE: qtquickcontrols2 + qtquickdialogs2 (needed by the config app) are
  # provided by qtdeclarative itself in nixpkgs Qt ≥ 6.7 — no separate attrs.

  # ── patches ──────────────────────────────────────────────────────────────
  postPatch = ''
    # 0) MONOCHROME THEME — patch the hardcoded Apple-grey palette in
    #    backend/StyleTokensBackend.cpp to pure black & white:
    substituteInPlace backend/StyleTokensBackend.cpp \
      --replace-fail '"#1c1c1e"' '"#000000"' \
      --replace-fail '"#232326"' '"#0a0a0a"' \
      --replace-fail '"#2c2c2e"' '"#111111"' \
      --replace-fail '"#26272b"' '"#0d0d0d"' \
      --replace-fail '"#222327"' '"#0b0b0b"' \
      --replace-fail '"#343437"' '"#161616"' \
      --replace-fail '"#3a3a3d"' '"#1a1a1a"' \
      --replace-fail '"#4a4b50"' '"#333333"' \
      --replace-fail '"#0a84ff"' '"#ffffff"' \
      --replace-fail '"#6ea8ff"' '"#aaaaaa"'

    # 1) Launcher execs /usr/bin/quickshell in three places — point at nix:
    substituteInPlace tide-island-launcher \
      --replace-fail '/usr/bin/quickshell' '${quickshell}/bin/quickshell'

    # 2) .desktop files reference /usr/bin — use bare names instead:
    substituteInPlace Tide-island-app/tide-island-config.desktop \
      --replace-fail 'Exec=/usr/bin/tide-island-config-app' 'Exec=tide-island-config-app' || true
    substituteInPlace tide-island.desktop \
      --replace-fail 'Exec=/usr/bin/tide-island' 'Exec=tide-island' || true
  '';

  # ── configure ────────────────────────────────────────────────────────────
  # CMAKE_INSTALL_LIBDIR=lib matters: the launcher is configure_file'd with
  # @CMAKE_INSTALL_LIBDIR@ and computes its IslandBackend QML path from it.
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # ── post-install: fixups + MANUAL launcher wrap ──────────────────────────
  # wrapQtAppsHook only wraps ELF binaries; tide-island is a bash script, so
  # we wrap it ourselves with:
  #   * QML_IMPORT_PATH/QML2_IMPORT_PATH — runtime QML modules (Qt5Compat!)
  #   * PATH — quickshell + brightnessctl (what Tide shells out to)
  # The launcher prepends its own plugin dir to any existing QML_IMPORT_PATH,
  # so env composition with its exports is correct.
  postInstall = ''
    rm -f $out/lib/qt6/qml/TideIsland/tide-island-config-app_qml_module_dir_map.qrc || true

    mv $out/bin/tide-island $out/bin/.tide-island-launcher-orig
    cat > $out/bin/tide-island <<WRAP
    #!/usr/bin/env bash
    export QML_IMPORT_PATH="\''${QML_IMPORT_PATH:+\$QML_IMPORT_PATH:}${qsQmlPaths}"
    export QML2_IMPORT_PATH="\''${QML2_IMPORT_PATH:+\$QML2_IMPORT_PATH:}${qsQmlPaths}"
    export PATH="\''${PATH:+\$PATH:}${lib.makeBinPath ([ quickshell ] ++ lib.optionals (brightnessctl != null) [ brightnessctl ])}"
    exec $out/bin/.tide-island-launcher-orig "\$@"
    WRAP
    chmod +x $out/bin/tide-island
  '';

  # config-app (ELF) gets normal Qt wrapping + the runtime helpers:
  qtWrapperArgs = [
    "--prefix"
    "QML_IMPORT_PATH"
    ":"
    qsQmlPaths
    "--prefix"
    "QML2_IMPORT_PATH"
    ":"
    qsQmlPaths
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath (
      [ quickshell ] ++ lib.optionals (brightnessctl != null) [ brightnessctl ]
    ))
  ];

  # ── meta ─────────────────────────────────────────────────────────────────
  meta = {
    description = "Smooth, lightweight Dynamic Island for Hyprland and niri (Quickshell/QML/C++)";
    homepage = "https://github.com/enhaoswen/Tide-island";
    changelog = "https://github.com/enhaoswen/Tide-island/releases/tag/1.0.38";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "tide-island";
  };
})
