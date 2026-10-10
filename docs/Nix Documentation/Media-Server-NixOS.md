# Media Server on NixOS

An exhaustive, independently-usable reference for building a media stack on NixOS — Jellyfin (with GPU transcoding incl. your 1660 SUPER's NVENC), Navidrome for music, the *arr automation suite, torrent clients, and library hygiene. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** nixpkgs module sources (`services/misc/jellyfin.nix`, `services/audio/navidrome.nix`, `services/misc/servarr/*.nix`) — option lists verified against release-26.05 (jellyfin: `transcoding.enableHardwareEncoding`, `transcoding.hardwareDecodingCodecs` (attrset), `hardwareAcceleration`, `openFirewall`, ...; navidrome: `enable, user, group, settings, environmentFile, ...`; sonarr/prowlarr: `enable, user, group, dataDir, openFirewall`) · Jellyfin transcoding & NVENC docs · Servarr wiki (radarr/sonarr/prowlarr paths) · Gstreamer VA-API notes.

**Companion guides:** `Self-Hosting-NixOS.md` (reverse proxy, remote access), `Backups-NixOS.md` (§7's DB dumps for *arr), `Networking-NixOS.md` (firewall, WG access).

---

## Table of Contents

1. [Architecture: The Media Stack at a Glance](#1-architecture-the-media-stack-at-a-glance)
2. [Jellyfin — Streaming Core](#2-jellyfin-streaming-core)
3. [GPU Transcoding Matrix — NVENC / VAAPI-AMF / QSV-VAAPI](#3-gpu-transcoding-matrix--nvenc--vaapi-amf--qsv-vaapi-per-gen-codecs)
4. [Navidrome — Music](#4-navidrome-music)
5. [The *arr Suite (Sonarr/Radarr/Prowlarr/Lidarr)](#5-the-arr-suite)
6. [Download Clients (qBittorrent/Transmission)](#6-download-clients)
7. [Library Layout & Fileserver Extras](#7-library-layout-fileserver-extras)
8. [Backups for the Stack](#8-backups-for-the-stack)
9. [Troubleshooting](#9-troubleshooting)
10. [Reference Index](#10-reference-index)

---

## 1. Architecture: The Media Stack at a Glance

```
Indexers (Prowlarr) ──┐
                      ├─→ Sonarr (TV) / Radarr (movies) / Lidarr (music)
Torrent/Usenet ───────┤        │  (requests downloads, renames, files)
(qBittorrent)          │        ↓
                       │   /media/library/{tv,movies,music}
                       │        ↑ reads
                       │   Jellyfin ──→ your TVs/phones (DLNA/apps)
                       │   Navidrome ─→ Subsonic apps
                       └─ (all admin UIs behind reverse proxy § Self-Hosting)
```

The NixOS angle: every box is a `services.*` option with a `user`/`group`/`openFirewall` triple, so the classic Linux pain (permissions between *arr and the downloader) is solved *declaratively* — one shared group, declared once.

## 2. Jellyfin — Streaming Core

```nix
{ config, pkgs, ... }: {
  services.jellyfin = {
    enable = true;

    # The group that owns library files — see §7 for the shared group:
    group = "media";

    # Open ports in the firewall (8096 http, 8920 https auto):
    openFirewall = true;

    # ---- Transcoding behavior (works WITHOUT GPU too) ------------------
    # NOTE: all transcoding knobs live under transcoding.* (not top-level).
    # forceEncodingConfig below stays top-level; the rest are nested.
    transcoding = {
      # Extract subtitles to text tracks on import (clients love it):
      enableSubtitleExtraction = true;

      # Delete transcoded segments aggressively (disk hygiene on small SSDs):
      deleteSegments = true;            # clean up after each session

      # Throttle when nothing is transcoding (idle CPU → quiet):
      throttleTranscoding = true;
    };

    # The one knob that fixes "fatal: default encoding quality":
    # (top-level by design — controls whether transcoding.* is enforced):
    forceEncodingConfig = false;      # let the GUI own quality settings
  };

  # The shared media group (all stack members join — §5, §6):
  users.groups.media = { };

  # First-run wizard happens at http://localhost:8096 — bind user,
  # add libraries pointing at /media/library/*, set up users.
}
```

## 3. GPU Transcoding Matrix — NVENC / VAAPI-AMF / QSV-VAAPI (per-gen codecs)

| Vendor | Method (Jellyfin GUI) | H.264 | HEVC 10-bit | AV1 | Tone-map | NixOS pkg |
|---|---|---|---|---|---|---|
| NVIDIA Maxwell→Pascal | NVENC | enc+dec | Pascal+ | — | CUDA | nvidia_x11 + cudaSupport |
| NVIDIA Turing (your 1660S) | NVENC | enc+dec | enc+dec | dec only (Ampere+) | CUDA | open=true |
| NVIDIA Ada (RTX40xx) | NVENC | enc+dec | enc+dec | enc+dec | CUDA | open=true |
| NVIDIA Blackwell (RTX50xx) | NVENC | enc+dec | enc+dec | enc+dec | CUDA | open=true REQUIRED |
| AMD Polaris→RDNA2 | VAAPI | enc+dec | dec(+enc RDNA) | — | OpenCL/ROCm | mesa + libva |
| AMD RDNA3+ | VAAPI | enc+dec | enc+dec | enc+dec | ROCm | mesa + rocm |
| Intel Broadwell→Comet | QSV/VAAPI | enc+dec | dec+enc* | — | VPP/QSV | intel-media-driver (iHD) |
| Intel Arc / Gen12+ | QSV | enc+dec | enc+dec | enc+dec | VPP | iHD + vpl-gpu-rt + GuC/HuC |

Jellyfin's module exposes exactly the knobs needed per vendor:

```nix
{ config, pkgs, ... }: {
  services.jellyfin = {
    enable = true;

    # ---- Hardware acceleration device (NVENC on the 1660 SUPER) --------
    hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      device = "/dev/dri/renderD128";
    };

    # ---- All encode/decode knobs live under transcoding.* --------------
    transcoding = {
      # The master switch: hardware encode/decode
      enableHardwareEncoding = true;

      # Decode-side codecs — attrset of bools (NOT a list):
      hardwareDecodingCodecs = {
        h264 = true;       # ~everything pre-2013+
        hevc = true;       # modern encodes (4K HDR rips)
        vp9 = true;        # web content
        # av1 only on RTX30+/RDNA3+ GPUs (decode support) —
        # the GTX 1660 SUPER (Turing NVENC) does NOT decode AV1.
      };

      # Quality: CRF values for the hardware encoder ------------------
      # CRF lower = better quality/bigger. Hardware encoders are ~6-8
      # "CRF points" worse than software x265 at the same bitrate, so
      # don't be afraid to run quality-biased:
      h264Crf = 23;      # CPU x264 default ≈ 23; NVENC at 23 is decent
      h265Crf = 28;      # HEVC NVENC quality-per-bit sweet spot

      # CPU-side knobs -------------------------------------------------
      # When software fallback DOES happen (odd codecs), cap it:
      threadCount = 4;                 # leave cores for *arr/transmission
      encodingPreset = "veryslow";     # only for software encode paths
      # ("veryslow" software beats NVENC quality — but 10x the CPU time)
      maxConcurrentStreams = 2;        # two remotes max — your 3600 + NVENC
    };
  };

  # ---- NVIDIA specifics (NVENC on the 1660 SUPER) ----------------------
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;                     # Turing+ open; Blackwell/50xx REQUIRED true; pre-Turing false
    # package = config.boot.kernelPackages.nvidiaPackages.stable;  # beta for 50xx day-0
  };
  hardware.graphics.enable32Bit = false;  # server: no 32-bit needed
  services.xserver.videoDrivers = [ "nvidia" ];
  # NVENC session limit: consumer cards cap ~3-5 concurrent (Ada+ unlimited-ish);
  # harassment-free drivers = nixpkgs nvidia_x11 (no manual .run installer DKMS hell).
  nixpkgs.config.cudaSupport = true;   # REQUIRED — jellyfin-ffmpeg links NVENC/CUDA tone-map
  hardware.nvidia-container-toolkit.enable = true;  # only if Jellyfin/Immich run containerized

  # NVENC needs the nvidia device + nvidia-smi usable by the service user;
  # the jellyfin package in nixpkgs already links NVENC SDK bits. Verify
  # from the dashboard: Playback → "Hardware acceleration: NVENC" and
  # play something — the dashboard should show "Transcode: h264 (NVENC)".

  # ---- AMD VAAPI/AMF (mesa + rocm for tone-mapping) -----------------------
  # hardware.graphics.extraPackages = with pkgs; [
  #   mesa libva-utils intel-compute-runtime  # vainfo + OpenCL tone-map
  #   rocmPackages.clr.icd  # RDNA HDR tone-mapping (heavy; skip on Polaris servers)
  # ];
  # services.jellyfin.hardwareAcceleration = { enable = true; type = "vaapi"; device = "/dev/dri/renderD128"; };
  # # GUI: VAAPI + check h264/hevc (+av1 on RDNA3+); AMF is Windows-only, VAAPI on Linux.

  # ---- Intel QSV/VAAPI (iHD driver + GuC/HuC + Arc AV1) --------------------
  # hardware.graphics.extraPackages = with pkgs; [
  #   intel-media-driver intel-compute-runtime vpl-gpu-rt libva-utils
  # ];
  # boot.kernelParams = [ "i915.enable_guc=2" ];  # pre-Arc; Arc/xe: "xe.enable_guc=2"
  # services.jellyfin.hardwareAcceleration = { enable = true; type = "qsv"; device = "/dev/dri/renderD128"; };
  # services.jellyfin.transcoding.enableIntelLowPowerEncoding = true;   # GuC low-power H.264/HEVC
  # # Arc AV1: needs vpl-gpu-rt + jellyfin-ffmpeg with vpl (25.11+ default on) + Resizable-BAR on.
}

## 3b. Per-vendor verify commands (run BEFORE opening the dashboard)

```bash
# NVIDIA NVENC: nvidia-smi (driver live?) + nvidia-smi encodersessioncounts (sessions)
#   ls -l /dev/nvidia* /dev/dri/renderD*; jellyfin-ffmpeg -hide_banner -h encoder=h264_nvenc | head
# AMD VAAPI: vainfo | grep -E 'VA-API|H264|HEVC|AV1'; ls -l /dev/dri/renderD*; radeontop
# Intel QSV/VAAPI: vainfo | grep -E 'iHD|H264|HEVC|AV1'; intel_gpu_top; intel_gpu_top -L (multi-GPU pick)
# Jellyfin log proof: journalctl -u jellyfin | grep -i -E 'nvenc|vaapi|qsv|tone'; dashboard Playback → Transcode reason
```
```

## 4. Navidrome — Music

```nix
{ config, pkgs, ... }: {
  services.navidrome = {
    enable = true;

    user = "navidrome";
    group = "media";                  # read your music dir (§7)
    openFirewall = true;             # :4533

    # Declarative settings — keys mirror Navidrome's config keys:
    settings = {
      # The music library root:
      MusicFolder = "/media/library/music";

      # Performance & behavior:
      ScanSchedule = "@every 1h";    # auto-scan for new files
      SessionTimeout = "24h";
      EnableInsightsCollector = false;  # no phone-home

      # Sound: ReplayGain = precomputed volume normalization:
      EnableTranscodingConfig = true;
      TranscodingCacheSize = "1GB";
      # Cover art priority is TOP-LEVEL (not under Cache.):
      CoverArtPriority = "*.jpg,*.png";
    };

    # Secrets (Last.fm/ListenBrainz API keys) via env (Secrets guide §5):
    # environmentFile = config.sops.secrets."navidrome-env".path;
  };
}
```

## 5. The *arr Suite

```nix
{ config, pkgs, ... }: {
  # ---- Indexer management (talks to tracker APIs; feeds the others) ----
  services.prowlarr = {
    enable = true;
    openFirewall = true;             # :9696 admin UI
  };

  # ---- TV ----------------------------------------------------------------
  services.sonarr = {
    enable = true;
    group = "media";                  # writes into /media/library/tv
    openFirewall = true;             # :8989
    # dataDir defaults to /var/lib/sonarr (state, DB — backup §8)
  };

  # ---- Movies --------------------------------------------------------------
  services.radarr = {
    enable = true;
    group = "media";
    openFirewall = true;             # :7878
  };

  # ---- Music (pairs with Navidrome as the PLAYER) --------------------------
  services.lidarr = {
    enable = true;
    group = "media";
    openFirewall = true;             # :8686
  };

  # All four UIs first-run: set the *arr user's GROUP to "media" inside
  # their Settings → Media Management too — the NixOS group only governs
  # the process; the app ALSO self-checks its config.
}
```

The wiring that makes them sing together (per-app web UI, one-time):
1. Prowlarr → Settings → Apps → add Sonarr/Radarr (API keys from each app) — indexers sync out automatically.
2. Sonarr/Radarr → Settings → Download Clients → add qBittorrent (§6) with its category.
3. Sonarr/Radarr → Series/Library import → root folder `/media/library/tv` (or movies).

## 6. Download Clients

```nix
{ config, pkgs, ... }: {
  services.qbittorrent = {
    enable = true;
    group = "media";                  # writes downloads where *arr reads
    openFirewall = true;             # the WEBUI port for UI access
    # For PEER traffic (actual torrents), open the listen port:
    # add it to networking.firewall.allowedTCPPorts/UDPPorts manually —
    # the module opens the webui only.

    # No port option yet — the webui defaults to 8080; the FIRST thing
    # you do in the UI: Tools → Options → set a strong password (default
    # is admin/adminadmin printed in the journal ONCE).
  };

  # WebUI hardening (the part people skip): bind to localhost only and
  # reach it via SSH tunnel or the reverse proxy (Self-Hosting guide):
  # in the UI: WebUI → "Bind to interface: 127.0.0.1" — then:
  #   ssh -L 8080:localhost:8080 yourbox  →  http://localhost:8080
}
```

Legal note: what you point Prowlarr at is your business; the stack itself is neutral plumbing.

## 7. Library Layout & Fileserver Extras

```bash
# One canonical layout, owned by the shared group, per stack §1:
sudo mkdir -p /media/library/{tv,movies,music}
# The NixOS-native ownership — set once, survives everything:
sudo chown -R :media /media
sudo chmod -R 2775 /media
# 2775 = rwxrwsr-x: the SET-GID bit (2) makes new files inherit
# 'media' group no matter which service creates them — the fix for
# "sonarr can't see what qbittorrent downloaded".
```

```nix
{ config, pkgs, ... }: {
  # Optional: serve the raw library over SMB for editing rooms:
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      "media" = {
        path = "/media/library";
        writable = "yes";
        "valid users" = "fury";
      };
    };
  };
  # Prefer Jellyfin clients for playback though — they resume/track.
}
```

## 7b. Immich ML (onnx/armnn + cuda/rocm) + Tdarr/Unmanic transcode workers

```nix
{ config, pkgs, ... }: {
  # Immich photos: ML (CLIP/facial) is CPU by default — GPU via onnxRuntime backends:
  services.immich = {
    enable = true;
    accelerationDevices = [ "/dev/dri/renderD128" ];  # VAAPI transcode (wiki pattern)
    # ML accel: nixpkgs immich-machine-learning is CPU; CUDA needs overlay:
    # nixpkgs.overlays = [(final: prev: { onnxruntime = prev.onnxruntime.override { cudaSupport = true; }; })];
    # services.immich.machine-learning.environment = { LD_LIBRARY_PATH = "${pkgs.python312Packages.onnxruntime}/lib/python3.12/site-packages/onnxruntime/capi"; };
    # ROCm AMD: onnxruntime.override { rocmSupport = true; } + /dev/kfd in accelerationDevices
    # users.users.immich.extraGroups = [ "video" "render" ];  # read /dev/dri + /dev/kfd
  };
  # hardware.nvidia-container-toolkit.enable = true;  # if Immich ML runs as OCI container with --gpus=all

  # Tdarr (distributed transcode farm — GPU workers):
  # services.tdarr = { enable = true; openFirewall = true; };  # :8265 server + :8266 workers
  # # Point Tdarr GPU plugin at: nvidia (h264_nvenc/hevc_nvenc/av1_nvenc per §3 matrix),
  # # amd (hevc_vaapi), intel (h264_qsv). Health-check same as §3b per node.
  # Unmanic (simpler single-node alternative):
  # services.unmanic = { enable = true; openFirewall = true; };  # :8888
  # # Worker encoder template: vaapi (AMD/Intel) or nvenc (NVIDIA) — match §3 matrix gen.
}
```

## 8. Backups for the Stack

The data split determines the strategy (Backups guide §1-2):

```nix
{ config, ... }: {
  # The MEDIA itself: huge, re-obtainable (by design of the stack) —
  # most people exclude it and treat *arr's DBs as the real backup.
  # The STATE (small, precious): watch histories, ratings, requests:

  services.restic.backups."media-state" = {
    passwordFile = config.sops.secrets."restic-password".path;
    paths = [
      "/var/lib/jellyfin"        # users, views, metadata cache marker
      "/var/lib/sonarr"          # the actual library index!
      "/var/lib/radarr"
      "/var/lib/prowlarr"        # indexer definitions
      "/var/lib/lidarr"
      "/var/lib/navidrome"       # play counts/playlists DB
    ];
    exclude = [ "*/transcodes" "*/cache" ];   # jellyfin transient bits
    timerConfig.OnCalendar = "daily";
    initialize = true;
    repository = "/mnt/backup-disk/restic-media";
    # DB-consistent dumps: jellyfin/*arr use SQLite — stop-clean or use
    # Backups guide §7's prepare hooks with sqlite3 .backup commands.
  };
}
```

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| Playback stutters, "direct play failed" | Transcoding is happening — check Dashboard → Active: is it NVENC or CPU? CPU at 100% = §3 misconfigured (GUI acceleration off / codec not in list). |
| "No hardware decoder found" in logs | Device perms: `ls -l /dev/dri/*` — jellyfin must read renderD128; if you changed `group`, reboot or restart the service so udev perms apply. |
| NVENC sessions fail after ~3-5 streams | Consumer NVIDIA cards cap concurrent NVENC sessions. `maxConcurrentStreams` (§3) + let extras fall back to software. |
| *arr can't import downloads | The §7 setgid fix (`chmod 2775`). Also verify in-app settings match: Settings → Media Management → "Use hardlinks" OFF if cross-filesystem. |
| Prowlarr → Sonarr "test fails" | API key typo'd or the app URLs wrong — Prowlarr needs Sonarr's URL *as reachable from Prowlarr* (localhost:8989 usually). |
| qbittorrent webui unreachable | First-run password in `journalctl -u qbittorrent | head -30` (printed once). If you bound to 127.0.0.1, you need the SSH tunnel (§6). |
| Navidrome sees no music | `MusicFolder` path + group read perms; then trigger scan in UI or wait for ScanSchedule. |
| Restored *arr from backup, "corrupt DB" | You backed up SQLite while running — use the dump/prepare pattern (Backups §7), not file copies of live DBs. |
| Firewall warnings despite openFirewall | You're hitting the PEER port vs the webUI port; open both deliberately (§6 note) or check `ss -tlnp` for actual binds. |

## 10. Reference Index

- Jellyfin docs: <https://jellyfin.org/docs/>
- Jellyfin NVENC notes: <https://jellyfin.org/docs/general/server/media/hardware-acceleration/nvidia>
- Servarr wiki (the canonical wiring): <https://wiki.servarr.com/>
- Navidrome config keys: <https://www.navidrome.org/docs/usage/configuration-options/>
- nixpkgs module sources: `services/misc/jellyfin.nix`, `services/audio/navidrome.nix`, `services/misc/servarr/`
- Companions: `Self-Hosting-NixOS.md` (proxy the UIs), `Backups-NixOS.md` (§7-8 here), `Networking-NixOS.md` (remote access)
