# ============================================================================
# fury-audio-studio.nix — Fury Audio Studio (PipeWire voice DSP + GTK studio).
#
# SINGLE-FILE MODULE: import it in configuration.nix and set
#   services.fury-audio-studio.enable = true;
# then `sudo nixos-rebuild switch --flake /etc/nixos#nixos` — done.
# No Dusky checkout, no ~/user_scripts, no pacman/AUR needed afterwards.
#
# WHAT IT IS (plain English): a control window (noise removal, volume, echo,
# robot voices, 9-band EQ) driving a tiny background sound engine. When ON,
# apps record from "Fury Mic" (cleaned mic) and hear via "Fury Speakers"
# (cleaned output). When OFF, hardware routes directly again.
#
# ORIGIN: developed in Hackcoon/fury-audio-studio (own repo, no upstream
# runtime/build dependency). Genealogy: fork of Dusky Audio Studio
# (dusklinux/dusky, user_scripts/audio/dusky_audio_studio/) — Python GTK3
# frontend (~3.8k lines) + C PipeWire DSP daemon (audio-helper/main.c,
# ~3.5k lines, protocol v4). Dusky has NO QuickShell audio UI (upstream
# README: "decided to not use quickshell"); the screenshot people pass
# around IS this GTK3 window. Pinned to our own frozen tarball below.
#
# FURY BRANDING lives in the source repo itself (binary `fury-audio-studio`,
# desktop entry "Fury Audio Studio", config at ~/.config/fury/studio, cache
# at ~/.cache/fury-studio, PipeWire nodes `fury-audio*` with "Fury Mic" /
# "Fury Audio" nicknames). This module only builds + wraps + autostarts.
#
# DMS THEMING: automatic. The UI styles itself with GTK `@theme_*` variables
# resolved from the running GTK theme + DMS's generated
# ~/.config/gtk-3.0/gtk.css (dank-colors.css). No hardcoded palette in this
# module — switch DMS theme (e.g. amoledBlack/maroon) and Fury follows on next
# launch. Full DMS-accent-mapped monochrome is phase 2 (QuickShell QML
# rewrite reading theme.json directly); this phase keeps Dusky's layout 1:1.
#
# NIXOS GOTCHAS HANDLED HERE (the source repo is already Fury-clean and its
# Makefile neutral — HOST_CFLAGS/mold are opt-in upstream of this file):
#   1. Store is read-only: source falls back to `make -B -C ./audio-helper`
#      at runtime, which can't work in the store. We prebuild the engine with
#      stdenv and inject it via $FURY_AUDIO_DSP_BIN (checked FIRST in
#      find_helper_binary; make never runs under Nix).
#   2. `b"fury_audio_studio"` /proc self-check matches the MODULE filename
#      (live process is `python3 .../fury_audio_studio.py ...`), else --toggle
#      would refuse to see its own daemon (PID-recycling guard).
#
# UPDATE RECIPE: push to Hackcoon/fury-audio-studio, put the new commit hash
# in `furyRev` below, then get the new unpacked-tree hash via (NOT `nix store
# prefetch-file` — that hashes the .tar.gz file, fetchzip hashes the
# unpacked tree):
#   build once and copy the `got:` hash from the mismatch error.
# Rollback = revert the two lines.
# ============================================================================
{ config, pkgs, lib, ... }:

let
  cfg = config.services.fury-audio-studio;

  # ── Pinned source: our own repo (no upstream dependency) ──
  # fetchzip strips the GitHub top dir, so $src root IS the repo root
  # (fury_audio_studio.py, audio-helper/, README.md, …).
  furyRev = "2eae6ccb3c74704493815431d2119cb7a8468fc3";
  furySrc = pkgs.fetchzip {
    url = "https://github.com/Hackcoon/fury-audio-studio/archive/${furyRev}.tar.gz";
    hash = "sha256-Z6A7jd5Jdu1hJ6Dk7CkT9NggC9d5f9dC/YVp7I88P00=";
  };

  # ── 1) Native DSP engine (C): PipeWire virtual mic/sink + RNNoise ──
  # The repo Makefile builds `fury_audio_dsp` via pkg-config
  # libpipewire-0.3 + rnnoise. Pure stdenv build, no flags needed
  # (Makefile defaults are already neutral: no -march=native, no mold).
  furyDsp = pkgs.stdenv.mkDerivation {
    pname = "fury_audio_dsp";
    version = "0.2.0-${builtins.substring 0 7 furyRev}";
    src = furySrc;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.pipewire.dev pkgs.rnnoise ];
    buildPhase = ''
      runHook preBuild
      # $src is the read-only store copy — build in a writable copy instead.
      rm -rf ./build
      cp -r "$src/audio-helper" ./build
      chmod -R u+w ./build
      make -C ./build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 ./build/fury_audio_dsp $out/bin/fury_audio_dsp
      # Protocol-guard: Python speaks v4 (HEADER_STRUCT "<IIIIfffff").
      # Fail the build here — not at 2am in the user session.
      "$out/bin/fury_audio_dsp" --protocol-version | grep -qx '4'
      runHook postInstall
    '';
    meta = {
      description = "Fury Audio Studio native PipeWire DSP engine (RNNoise + EQ + vocoder)";
      license = lib.licenses.gpl3Plus;
      platforms = [ "x86_64-linux" ];
      mainProgram = "fury_audio_dsp";
    };
  };

  # ── 2) Studio frontend (Python GTK3) + wrapper ──
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.pycairo ]);

  furyStudio = pkgs.stdenv.mkDerivation {
    pname = "fury-audio-studio";
    version = "0.2.0-${builtins.substring 0 7 furyRev}";
    src = furySrc;

    nativeBuildInputs = [ pkgs.makeWrapper pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pythonEnv ];

    # Source is already Fury-clean (renames live in the repo). This gate is
    # a regression tripwire: any reintroduced Dusky string fails the build.
    postPatch = ''
      for f in ./fury_audio_studio.py ./audio-helper/main.c ./audio-helper/protocol.h ./audio-helper/Makefile; do
        if grep -ni "dusky\|dusk\|ghelper\|parstix" "$src/$f" | grep -v "GHAF"; then
          echo "upstream branding leaked into $f" >&2
          exit 1
        fi
      done
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fury-audio-studio $out/bin $out/share/applications
      install -Dm644 "$src/fury_audio_studio.py" $out/share/fury-audio-studio/fury_audio_studio.py

      # Wrapper: python + PipeWire/notify CLIs on PATH, engine prelocated.
      # wrapGAppsHook3 (postFixup) adds the GTK/GI env on top of this.
      makeWrapper ${pythonEnv}/bin/python3 $out/bin/fury-audio-studio \
        --add-flags "$out/share/fury-audio-studio/fury_audio_studio.py" \
        --prefix PATH : ${lib.makeBinPath [ pkgs.pipewire pkgs.wireplumber pkgs.libnotify ]} \
        --set FURY_AUDIO_DSP_BIN "${furyDsp}/bin/fury_audio_dsp"

      cat > $out/share/applications/fury-audio-studio.desktop <<EOF
      [Desktop Entry]
      Name=Fury Audio Studio
      Comment=Voice DSP and noise cancellation (PipeWire)
      Exec=fury-audio-studio --gui
      Icon=audio-input-microphone
      Terminal=false
      Type=Application
      Categories=AudioVideo;Audio;
      StartupWMClass=fury-audio-studio
      EOF
      runHook postInstall
    '';

    meta = {
      description = "Fury Audio Studio — PipeWire voice DSP control window (mic/speaker denoise, EQ, voice FX)";
      license = lib.licenses.gpl3Plus;
      platforms = [ "x86_64-linux" ];
      mainProgram = "fury-audio-studio";
    };
  };

in
{
  options.services.fury-audio-studio = {
    enable = lib.mkEnableOption "Fury Audio Studio (PipeWire voice DSP + GTK studio)";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the DSP after login (it self-skips when saved state is OFF). Turn off for fully manual `--toggle` use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ furyStudio ];

    assertions = [
      {
        assertion = config.services.pipewire.enable;
        message = "services.fury-audio-studio needs services.pipewire.enable = true (modules/hardware/audio.nix).";
      }
    ];

    # User unit: --autostart exits quietly when the saved toggle is OFF, so
    # WantedBy=default.target is safe (no DSP unless the user turned it on).
    systemd.user.services.fury-audio-studio = lib.mkIf cfg.autostart {
      description = "Fury Audio Studio DSP (PipeWire voice processing)";
      after = [ "pipewire.service" "wireplumber.service" ];
      wants = [ "pipewire.service" "wireplumber.service" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${furyStudio}/bin/fury-audio-studio --autostart";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}
