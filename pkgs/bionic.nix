# ============================================================
# BIONIC — custom package built from upstream's AppImage
# ============================================================
# LM Studio Bionic (https://lmstudio.ai/bionic) — LM Studio's
# agent for open models (documents, code, agentic work).
# Upstream ships Linux builds only as a Type 2 Electron
# AppImage, so this re-packages it the same way as tolaria.nix
# and the nixpkgs `lmstudio` package (same vendor, same layout).
#
# NOTE: the AppImage also bundles an `lms` CLI at
# resources/app/.webpack-bionic/lms — deliberately NOT
# installed here: pkgs.lmstudio (system-packages.nix) already
# provides $out/bin/lms and the two would collide in the
# system profile.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "bionic";

  # Upstream's URL uses "1.1.2-11" while the app itself reports
  # "1.1.2+11" (X-AppImage-Version in the .desktop). URL and
  # version change together on each release — see the download
  # redirect: https://lmstudio.ai/download/bionic/latest/linux/x64
  version = "1.1.2-11";

  src = fetchurl {
    url = "https://bionic-installers.lmstudio.ai/linux/x64/${version}/Bionic-${version}-x64.AppImage";
    hash = "sha256-g1NDcroAtP7sU+ea3dq0bZ1oyvQLUxbpl+ONFbDhwME=";
  };

  # One-time extraction of the AppImage contents, used ONLY to
  # fish out the .desktop file and hicolor icon PNGs for the
  # launcher menu. (wrapType2 does its own extraction to run.)
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Libraries injected into the app's FHS sandbox. ocl-icd matches
  # the nixpkgs lmstudio package (OpenCL loader for GPU runtimes —
  # this box has NVIDIA + CUDA). Electron's own libs are bundled.
  extraPkgs = pkgs: [ pkgs.ocl-icd ];

  # Upstream ships pre-rendered hicolor icons (16..512px) and a
  # desktop file with Exec=AppRun — point it at the wrapped binary.
  extraInstallCommands = ''
    mkdir -p $out/share/icons
    cp -r ${appimageContents}/usr/share/icons/hicolor $out/share/icons/

    install -m 444 -D ${appimageContents}/ai.elementlabs.bionic.desktop \
      -t $out/share/applications

    substituteInPlace $out/share/applications/ai.elementlabs.bionic.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=bionic %U'
  '';

  # Package metadata — consumed by nix search, tooling, and audits.
  meta = {
    description = "LM Studio Bionic — agent for open models (documents, code, agentic work)";
    homepage = "https://lmstudio.ai/bionic";
    downloadPage = "https://lmstudio.ai/bionic";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "bionic";
    platforms = [ "x86_64-linux" ];
  };
}
