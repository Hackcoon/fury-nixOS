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
# ORIGIN: fork of Dusky Audio Studio (dusklinux/dusky,
# user_scripts/audio/dusky_audio_studio/) — Python GTK3 frontend
# (dusky_audio_studio.py, ~3.8k lines) + C PipeWire DSP daemon
# (audio-helper/main.c, ~3.5k lines, protocol v4). Dusky has NO QuickShell
# audio UI (upstream README: "decided to not use quickshell"); the screenshot
# people pass around IS this GTK3 window. Pinned to a frozen tarball below —
# after the first build, Dusky's repo can vanish and Fury keeps working.
#
# FURY BRANDING: binary `fury-audio-studio`, desktop entry "Fury Audio
# Studio", config at ~/.config/fury/studio (NOT ~/.config/dusky/...),
# cache at ~/.cache/fury-studio. PipeWire node names stay `ghelper-audio*`
# on purpose (phase 1): the C engine and Python graph-watcher match those
# strings in ~15 places; renaming them is pure risk with zero user-visible
# gain (they only appear in pw-dump/pavucontrol technical views). User-visible
# labels ("Fury Mic", "Fury Speakers", notifications, titles) ARE renamed.
#
# DMS THEMING: automatic. The UI styles itself with GTK `@theme_*` variables
# resolved from the running GTK theme + DMS's generated
# ~/.config/gtk-3.0/gtk.css (dank-colors.css). No hardcoded palette in this
# module — switch DMS theme (e.g. amoledBlack/maroon) and Fury follows on next
# launch. Full DMS-accent-mapped monochrome is phase 2 (QuickShell QML
# rewrite reading theme.json directly); this phase keeps Dusky's layout 1:1.
#
# NIXOS GOTCHAS FIXED HERE (Arch assumptions upstream):
#   1. Store is read-only: upstream self-rebuilds via `make -B -C
#      ./audio-helper` at runtime. We prebuild the engine with stdenv and
#      inject it via $FURY_AUDIO_DSP_BIN (checked FIRST, make never runs).
#   2. `-march=native` + mold in upstream Makefile break purity/reproduc-
#      ibility → cleared via makeFlags (HOST_CFLAGS=, USE_MOLD=0).
#   3. `GDK_BACKEND=wayland` was forced unconditionally → now only when
#      $WAYLAND_DISPLAY exists (KDE-X11 / XWayland safe).
#   4. `sudo pacman -S ...` error text → NixOS wording.
#   5. `b"dusky_audio_studio"` /proc self-check + prgname + server import
#      renamed to match the `fury-audio-studio` binary, else --toggle would
#      refuse to see its own daemon (PID-recycling guard).
#
# UPDATE RECIPE: bump `duskyRev` below to a new main HEAD, then get the new
# unpacked-tree hash via (NOT `nix store prefetch-file` — that hashes the
# .tar.gz file, fetchzip hashes the unpacked tree):
#   nix run nixpkgs#nix-prefetch-url -- --unpack \
#     https://github.com/dusklinux/dusky/archive/<NEWREV>.tar.gz
# paste `hash`, rebuild. Rollback = revert the two lines. (Alternatively run
# the build once and copy the `got:` hash from the mismatch error.)
# ============================================================================
{ config, pkgs, lib, ... }:

let
  cfg = config.services.fury-audio-studio;

  # ── Pinned upstream (frozen 2026-10-10, main HEAD) ──
  # fetchzip (not fetchTarball: removed from pkgs in flakes) with stripRoot
  # (default) so $src root IS the repo root (user_scripts/, .config/, ...).
  duskyRev = "522cb09c4a1a578c3e1fd98b377bd8ad44371fdb";
  duskySrc = pkgs.fetchzip {
    url = "https://github.com/dusklinux/dusky/archive/${duskyRev}.tar.gz";
    hash = "sha256-f6LK6ho16OU5sdZWqgItHneOVqOeuezKSWwmDL/QHl8=";
  };
  # Referenced as $src/user_scripts/... in the derivations below.

  # ── 1) Native DSP engine (C): PipeWire virtual mic/sink + RNNoise ──
  # Upstream Makefile builds `dusky_audio_dsp` via pkg-config
  # libpipewire-0.3 + rnnoise. We build it purely and rename the output.
  furyDsp = pkgs.stdenv.mkDerivation {
    pname = "fury_audio_dsp";
    version = "0.1.0-dusky-${builtins.substring 0 7 duskyRev}";
    src = duskySrc;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.pipewire.dev pkgs.rnnoise ];
    # NOTE: custom buildPhase below (no makeFlags attribute): HOST_CFLAGS=
    # drops `-march=native -mtune=native` (impure, unreproducible).
    # USE_MOLD=0 drops the `command -v mold` auto-detection.
    buildPhase = ''
      runHook preBuild
      # $src is the read-only store copy — build in a writable copy instead.
      rm -rf ./build
      cp -r "$src/user_scripts/audio/dusky_audio_studio/audio-helper" ./build
      chmod -R u+w ./build
      make -C ./build HOST_CFLAGS= USE_MOLD=0
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 ./build/dusky_audio_dsp $out/bin/fury_audio_dsp
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
    version = "0.1.0-dusky-${builtins.substring 0 7 duskyRev}";
    src = duskySrc;

    nativeBuildInputs = [ pkgs.makeWrapper pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pythonEnv ];

    # ── Fury patches (all --replace-fail so a rebase screams loudly) ──
    postPatch = ''
      f="$src/user_scripts/audio/dusky_audio_studio/dusky_audio_studio.py"
      cp "$f" ./fury_audio_studio.py
      chmod u+w ./fury_audio_studio.py
      f=./fury_audio_studio.py

      # App ID / state paths (leave PipeWire node names alone, see header).
      substituteInPlace "$f" --replace-fail 'org.dusky.audio-studio' 'org.fury.audio-studio'
      substituteInPlace "$f" --replace-fail '".config" / "dusky" / "settings" / "dusky_studio"' '".config" / "fury" / "studio"'
      substituteInPlace "$f" --replace-fail '".cache" / "dusky_studio"' '".cache" / "fury-studio"'
      substituteInPlace "$f" --replace-fail 'dusky_audio.sock' 'fury_audio.sock'
      # Internal sentinel (never shown in UI, compared only within this file).
      substituteInPlace "$f" --replace-fail 'dusky-no-hardware-device' 'fury-no-hardware-device'
      # Internal identifiers (function/var names, thread label, dead
      # store-path fallback) — pure renames within this one file, no UI or
      # behavior change. substituteInPlace replaces ALL occurrences each.
      substituteInPlace "$f" --replace-fail 'DUSKY_CSS' 'FURY_CSS'
      substituteInPlace "$f" --replace-fail 'pid_is_dusky_audio' 'pid_is_fury_audio'
      substituteInPlace "$f" --replace-fail 'set_dusky_devices_as_default' 'set_fury_devices_as_default'
      substituteInPlace "$f" --replace-fail 'dusky-ui-control' 'fury-ui-control'
      substituteInPlace "$f" --replace-fail '"dusky_audio_dsp"' '"fury_audio_dsp"'

      # User-visible branding.
      substituteInPlace "$f" --replace-fail 'Dusky Audio Studio' 'Fury Audio Studio'
      substituteInPlace "$f" --replace-fail 'DuskyAudio' 'FuryAudio'
      substituteInPlace "$f" --replace-fail 'Dusky Mic' 'Fury Mic'
      substituteInPlace "$f" --replace-fail 'Dusky Audio (Sink)' 'Fury Audio (Sink)'
      substituteInPlace "$f" --replace-fail 'Dusky Audio DSP' 'Fury Audio DSP'
      # Catch-all last (specific ones above already handled): footer labels,
      # docstrings, e.g. "Fury Mic & Dusky Audio (PipeWire …)".
      substituteInPlace "$f" --replace-fail 'Dusky Audio' 'Fury Audio'

      # Self-recognition: /proc cmdline guard must match the MODULE filename
      # (the live process is `python3 .../fury_audio_studio.py ...`, so
      # underscores — NOT the `fury-audio-studio` wrapper name), plus prgname
      # and daemon import, or --toggle/--status go blind.
      substituteInPlace "$f" --replace-fail 'b"dusky_audio_studio"' 'b"fury_audio_studio"'
      substituteInPlace "$f" --replace-fail 'GLib.set_prgname("dusky_audio_studio.py")' 'GLib.set_prgname("fury-audio-studio")'
      substituteInPlace "$f" --replace-fail 'from dusky_audio_studio import' 'from fury_audio_studio import'
      substituteInPlace "$f" --replace-fail 'Usage: dusky_audio_studio.py [COMMAND]' 'Usage: fury-audio-studio [COMMAND]'

      # NixOS wording instead of Arch.
      substituteInPlace "$f" --replace-fail 'sudo pacman -S' 'nixpkgs system packages (pipewire wireplumber rnnoise)'

      # Wayland-only forcing breaks X11 sessions; gate on $WAYLAND_DISPLAY.
      substituteInPlace "$f" --replace-fail 'os.environ["GDK_BACKEND"] = "wayland"' 'os.environ.setdefault("GDK_BACKEND", "wayland") if os.environ.get("WAYLAND_DISPLAY") else os.environ.pop("GDK_BACKEND", None)'

      # Store is read-only: prefer the prebuilt engine, never run make.
      ${pythonEnv}/bin/python3 - "$f" <<'PYEOF'
      import sys
      p = sys.argv[1]
      s = open(p, encoding="utf-8").read()
      old = "def find_helper_binary() -> Path | None:\n    STATE_DIR.mkdir"
      new = (
          "def find_helper_binary() -> Path | None:\n"
          "    _env = os.environ.get(\"FURY_AUDIO_DSP_BIN\", \"\")\n"
          "    if _env:\n"
          "        _p = Path(_env)\n"
          "        try:\n"
          "            if _p.is_file() and os.access(_p, os.X_OK) and helper_protocol_matches(_p):\n"
          "                return _p\n"
          "        except Exception:\n"
          "            pass\n"
          "    STATE_DIR.mkdir"
      )
      assert old in s, "find_helper_binary anchor vanished — rebase needed"
      open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
      PYEOF

      # Sanity: no raw Dusky branding left in user-facing strings.
      if grep -n "Dusky Audio Studio\|dusky_audio_studio\|dusky_studio" "$f"; then
        echo "leftover Dusky branding — patch list is stale" >&2
        exit 1
      fi
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fury-audio-studio $out/bin $out/share/applications
      install -Dm644 ./fury_audio_studio.py $out/share/fury-audio-studio/fury_audio_studio.py

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
