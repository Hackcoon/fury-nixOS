# Audio & PipeWire on NixOS

An exhaustive, independently-usable reference for audio on NixOS — the PipeWire stack (your current config, fully explained), latency tuning, Bluetooth codecs, JACK interop, EasyEffects, per-application routing, and network audio. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Wiki (PipeWire page) · PipeWire docs (GitLab wiki: configuration, buffering/quantum mechanics) · WirePlumber docs · nixpkgs module sources (`services/desktops/pipewire/pipewire.nix`, `wireplumber.nix` — `services.pipewire` option structure verified against release-26.05) · BlueZ codec notes · the EasyEffects manual.

**Your baseline:** your `configuration.nix` runs the standard stack (rtkit, pipewire, wireplumber, pulse compat, JACK support) — this guide explains what each piece does and every extension you might want.

**Companion guides:** `Gaming-NixOS.md` §11 (game audio), `Virtualization-NixOS.md` (VM audio), `Customization-NixOS.md` (session env vars).

---

## Table of Contents

1. [The Stack: What Each Piece Is](#1-the-stack-what-each-piece-is)
2. [The Core Setup (fully annotated)](#2-the-core-setup-fully-annotated)
3. [Latency & Quantum Tuning](#3-latency-quantum-tuning)
4. [Bluetooth Codecs (LDAC/aptX/SBC)](#4-bluetooth-codecs)
5. [EasyEffects (system-wide EQ/DSP)](#5-easyeffects)
6. [JACK & Pro Audio Interop](#6-jack-pro-audio-interop)
7. [Per-Application Routing (WirePlumber)](#7-per-application-routing-wireplumber)
8. [Network Audio (Roc, PipeWire-to-PipeWire)](#8-network-audio)
9. [passthru Debugging: pw-top/pw-dump/wpctl](#9-debugging)
10. [Troubleshooting](#10-troubleshooting)
11. [Vendor DSP + Quantum Profiles + Per-User + Debugging](#11-vendor-dspaudio--quantum-profiles--per-user-services--debugging)
12. [Reference Index](#12-reference-index)

---

## 1. The Stack: What Each Piece Is

```
Applications
   ├── native Pulse clients ──→ pipewire-pulse (drop-in pulse server)
   ├── native JACK clients ───→ pipewire-jack  (drop-in jack server)
   └── native PipeWire/ALSA ──┐
                             ↓
                    pipewire (the graph engine: nodes, links, formats)
                             ↓
                    wireplumber (the policy layer: what connects where,
                                 device profiles, default routes, volumes)
                             ↓
                    ALSA kernel drivers (the hardware)
   rtkit: grants pipewire real-time scheduling (audio thread priority)
```

Key insight: **PipeWire is the engine, WirePlumber is the brain.** When something routes wrong, 90% of fixes live in WirePlumber policy/config. `pipewire-pulse`/`pipewire-jack` are compat *servers* — existing apps need zero changes.

## 2. The Core Setup (fully annotated)

```nix
{ config, pkgs, ... }: {
  # ---- Real-time priority for the audio graph ------------------------
  # rtkit lets the pipewire daemon raise its threads to SCHED_RR without
  # running the whole server as root:
  security.rtkit.enable = true;

  # ---- The engine + policy + compat trio --------------------------------
  services.pipewire = {
    enable = true;

    # ALSA integration — the kernel devices PipeWire actually drives:
    alsa = {
      enable = true;
      # 32-bit ALSA apps (old games, wine prefixes without newlibs):
      support32Bit = true;
      # Keep ALSA-ONLY apps from bypassing the graph (rarely needed;
      # default false is fine for everyone):
      # disableNotifications = false;
    };

    # PulseAudio replacement server — ALL pulse clients speak to this:
    pulse.enable = true;

    # JACK replacement — ${libpipewire}/jack paths install as the system
    # libjack, redirecting jackd clients into the graph:
    jack.enable = true;    # (lowish overhead; disable for zero-jack hosts)

    # WirePlumber (the policy daemon — REQUIRED, no exceptions):
    wireplumber.enable = true;
  };

  # CRITICAL: the OLD stack must be off, or they fight over devices:
  # (If your hardware-configuration came from an ISO era, check for
  #  hardware.pulseaudio.enable leftovers in your config!)
  # hardware.pulseaudio.enable = false;   # ← must NOT be true anywhere
  # services.jack.audio.enable = false;

  # ---- User session wiring ------------------------------------------------
  # PipeWire runs PER-USER (systemd user units) — the socket activation
  # starts it on first sound request. Give yourself the packages for
  # control tools:
  environment.systemPackages = with pkgs; [
    pwvucontrol      # modern graphical mixer/router (fallback: pavucontrol)
    helvum           # patchbay GUI (see the graph, drag connections)
    easyeffects      # §5
    # CLI control (comes via wireplumber):
    #   wpctl, pw-cli, pw-top, pw-dump, pw-play, pw-record
  ];
}
```

## 3. Latency & Quantum Tuning

The "quantum" = buffer size per node; it sets your latency floor everywhere (sample rate × quantum / rate = ms per buffer, ×2-3 nodes deep):

```nix
{ config, ... }: {
  services.pipewire = {
    enable = true;

    # ---- The global clock -----------------------------------------------
    extraConfig.pipewire = {
      "context.properties" = {
        # Sample rate for the whole graph:
        "default.clock.rate" = 48000;          # most DACs' native
        # Quantum = buffer frames per processing cycle:
        "default.clock.quantum" = 1024;        # 1024/48000 ≈ 21ms — SAFE
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 2048;

        # Log latency to verify §9:
        # "log.level" = 3;
      };
    };

    # ---- pipewire-pulse niceties ----------------------------------------
    extraConfig.pipewire-pulse = {
      "stream.properties" = {
        # Pulse clients get resampled gently if rates mismatch:
        "resample.quality" = 4;      # 0-14, 4 = inaudible + cheap
        # Per-stream quantum override — e.g., low-latency comms:
      };
    };
  };
  # LATENCY TABLE (rate 48000):
  #   quantum 1024 → ~21ms   safe default, games+desktop
  #   quantum  512 → ~11ms   competitive gaming / rhythm games
  #   quantum  256 → ~5ms    music production (§6), watch for xruns
  #   quantum  128 → ~2.7ms  pro-audio territory: USB interfaces only
  #   quantum 32-64 → <1.5ms internal HDA only; expect xruns (§10)
}
```

## 4. Bluetooth Codecs

```nix
{ config, pkgs, ... }: {
  # Enable BT at all (Hardening §15 — only if you use it!):
  hardware.bluetooth = {
    enable = true;
    # Modern power management + codec negotiation:
    powerOnBoot = false;
    settings = {
      General = {
        # LDAC/aptX selection is via bluez5.codecs (below), not Experimental:
        # Experimental = true;  # only for experimental BlueZ features
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  services.blueman.enable = true;   # GUI applet

  # WirePlumber codec selection (per-device at runtime):
  #   wpctl status                       # find the device id
  #   wpctl set-profile <id> a2dp-sink    # high-quality A2DP vs headset
  # The HSP/HFP tradeoff: headset profile = mic but telephone quality;
  # a2dp = pristine audio, NO mic. Both-ways needs hardware mSBC.

  # Preferred: declarative via WirePlumber extraConfig (system-wide,
  # /etc/wireplumber/wireplumber.conf.d/ under the hood):
  services.pipewire.wireplumber.extraConfig."51-bluez-codecs" = {
    "monitor.bluez.rules" = [
      {
        matches = [ { "device.name" = "~bluez_card.*"; } ];
        actions = {
          update-props = {
            # Codec priority — order matters, first available wins:
            "bluez5.codecs" = [ "ldac" "aptx_hd" "aptx" "aac" "sbc_xq" "sbc" ];
            "bluez5.enable-msbc" = true;   # better call quality if HW allows
            "bluez5.enable-sbc-xq" = true; # better SBC fallback quality
            "bluez5.auto-connect" = [ "hfp_hf" "hfp_ag" "a2dp_sink" ];
          };
        };
      }
    ];
  };
}
```

## 5. EasyEffects

System-wide DSP — EQ, compressor, limiter, reverbs — on every app:

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    easyeffects

    # Optional LV2/LADSPA plugins it can load (all free):
    lsp-plugins         # heavy-hitting parametric EQs, compressors
    zam-plugins         # great simple units (ZamGate, ZamComp)
    calf                # the classic suite
    mda_lv2             # vintage-flavored extras
  ];

  # Autostart + session: it runs as a user service when you enable it
  # inside the app. Presets live in ~/.config/easyeffects/;
  # declaretively seed your default chain:
  systemd.tmpfiles.rules = [
    "C /home/fury/.config/easyeffects/output/FuryChain.json - - - - ${
      ./assets/FuryChain.json
    }"
  ];
  # (export your tuned chain from the app, commit it, deploy everywhere)
}
```

## 6. JACK & Pro Audio Interop

```nix
{ config, pkgs, ... }: {
  services.pipewire = {
    enable = true;
    jack.enable = true;

    # Pro-audio profile = raw multi-channel, minimal safety latency:
    # Switch a device at runtime:
    #   wpctl set-profile <id> pro-audio
    # (per-device; affects channel order & buffer floors)

    extraConfig.pipewire."context.properties"."default.clock" = {
      # JACK clients' default is inherited from the graph clock (§3);
      # to force JACK quantum, set e.g.:
      # "node.force-quantum" is NOT a jack.properties key — use:
      # "default.clock.min-quantum" / "default.clock.quantum" in
      # context.properties (see §3). Example JACK override:
    };
    extraConfig.pipewire."jack.properties" = {
      # Illustrative only — JACK clients follow the graph clock by default.
      # Prefer tuning context.properties.default.clock in §3.
    };
  };

  # The classic pro-audio client set:
  environment.systemPackages = with pkgs; [
    carla              # plugin host, can bridge windows VSTs (yabridge!)
    yabridge           # Windows VST2/VST3 → Linux, via wine (gaming stack
    #                    shares wine with Gaming §3)
    yabridgectl
    qpwgraph           # graph patchbay (QT flavor of helvum)
    # reaper             # unfree — requires nixpkgs.config.allowUnfree = true
    # or ardour, bitwig (unfree)
    # alabama-utils? no: pure Lv2: dragonfly-reverb, etc.
    dragonfly-reverb
    x42-plugins
  ];

  # RT audio thread priority (for the DAW itself, complements rtkit):
  security.pam.loginLimits = [
    { domain = "@audio"; type = "soft"; item = "rtprio"; value = "95"; }
    { domain = "@audio"; type = "hard"; item = "rtprio"; value = "95"; }
  ];
  users.users."fury".extraGroups = [ "audio" ];
}
```

## 7. Per-Application Routing (WirePlumber)

The practical magic — pin apps to devices declaratively:

```nix
{ config, ... }: {
  # WirePlumber matches streams→devices by rules. Preferred: declarative
  # via services.pipewire.wireplumber.extraConfig, which lands in
  # /etc/wireplumber/wireplumber.conf.d/*.conf (system-wide).
  # File below is ILLUSTRATIVE / UNVERIFIED — rule schema drifts across
  # WirePlumber versions; verify matches/actions/update-props keys against
  # YOUR wireplumber docs before relying on it (§10).
  services.pipewire.wireplumber.extraConfig."50-routing" = {
    "monitor.bluez.rules" = [ ];   # (BT-specific rules live in bluez monitor)
  };
  # [The practical runtime workflow — 99% of routing is wpctl, not
  #  static rules:]
  #   wpctl status                    # enumerate sinks/sources & ids
  #   wpctl set-default <sink-id>      # the default output
  #   # per-app while playing:
  #   #   pwvucontrol (GUI) → drag app stream to another device
  #   # persistent per-app: WirePlumber remembers GUI moves in
  #   #   ~/.local/state/wireplumber/ — declarative override only when
  #   #   you want it IMMUTABLE.
}
```

Rule-based example that people actually want — game chat ducking, or "browser always to headphones":

```nix
# Match streams to a device declaratively — schema changes across
# WirePlumber versions, so prefer runtime pwvucontrol moves (they
# persist) unless you need it immutable. The mechanism, for reference:
{ config, ... }: {
  environment.etc."wireplumber/wireplumber.conf.d/51-browser-routing.conf".text = ''
    monitor.bluez.rules = [
      {
        # match on node properties (application name, media class):
        matches = [ { node.name = "~*firefox*"; } ]
        actions = { update-props = { target.object = "alsa_output.usb-Headphones"; }; }
      }
    ]
  '';
  # ↑ illustrative of the rule SHAPE — verify keys against YOUR
  # wireplumber's docs before relying on it (§10).
}
```

## 8. Network Audio

```nix
{ config, pkgs, ... }: {
  # --- PipeWire ↔ PipeWire (the clean way, same version both ends) -------
  # Receiver box (the "speaker"):
  services.pipewire.extraConfig.pipewire = {
    "context.modules" = [
      {
        name = "libpipewire-module-roc-source";
        args = {
          "local.ip" = "0.0.0.0";
          "roc.source" = {
            "resampler.profile" = "high";
            "target.latency" = "200ms";
          };
        };
      }
    ];
  };
  # Sender box (plays INTO the receiver):
  # pw-cli create-node ... or via a sink target — Roc is the robust
  # transport (dropout-tolerant, FEC). Ports 10001-10004 need opening.

  # --- The quick-and-dirty: RTP module ---------------------------------
  # services.pipewire.extraConfig.pipewire = {
  #   "context.modules" = [ { name = "libpipewire-module-rtp-source";
  #     args = { "source.ip" = "239.0.0.1"; }; } ];
  # };

  # --- The classic: MPD on another box streaming icecast → any client.
}
```

## 9. Debugging

```bash
# The toolkit — run these IN ORDER when "no sound / wrong sound":

wpctl status          # 1. Is the device even SEEN? default sink/source sane?
pw-dump | less        # 2. The full graph JSON — objects, formats, errors
pw-top                # 3. LIVE view: quantum, xruns (X column!), ERR per stream
pw-cli ls Node        # 4. lower-level node list

# Sound-sink loopback test (bypasses apps entirely — tests the graph):
pw-play /usr/share/sounds/alsa/Front_Center.wav  # any wav

# xruns (audio glitches):
pw-top                 # watch the X column climb = §3 latency fixes

# Journal of the user units (PipeWire runs per-user!):
journalctl --user -u pipewire -u wireplumber -b

# Reset wireplumber remembered state (bad pins):
systemctl --user stop wireplumber
rm -rf ~/.local/state/wireplumber
systemctl --user start wireplumber

# Format negotiation deep-dive:
PIPEWIRE_DEBUG=2 <your-app>   # per-process protocol log
```

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| No sound at all | `wpctl status` — no card? ALSA layer: check `aplay -l` (kernel-level). Card present but muted: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0` + `wpctl set-mute @DEFAULT_AUDIO_SINK@ 0`. |
| Crackling/xruns | `pw-top` X column — raise quantum (§3). USB DAC on USB2 hub shared with heavy device? Move ports. Check rtkit active: `systemctl status rtkit-daemon`. |
| Bluetooth stuck in telephone quality | A2DP not selected: `wpctl set-profile <id> a2dp-sink`. Mic needed simultaneously = hardware must do mSBC (§4), or accept the tradeoff. |
| Pulse apps silent but pipewire apps fine | pipewire-pulse socket dead: `systemctl --user status pipewire-pulse.socket`; usually a leftover PA config in ~/.config/pulse — remove it. |
| JACK app can't connect | jack.enable = true + the app sees `pw-jack <app>` wrapper if its libjack isn't the system one. Carla/Qpwgraph to see the graph. |
| VM has no audio | Virtualization §5.3 — spice audio channel + guest drivers; the Looking Glass guide carries the full wiring. |
| EasyEffects not affecting an app | EE inserts on streams it recognizes; check its "bypass" state + the app using pulse route (not raw ALSA — `PW_CDSTYLE`?). Raw ALSA bypasses the graph by design (§2 note). |
| Mic quiet everywhere | `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1.0` (mics start at low volume by WirePlumber default) + device gain in pwvucontrol. |
| Audio crackles ONLY under heavy CPU load | That's preemption/rtkit starvation: Gaming §4 gamemode on the heavy app, or §3 quantum up a notch. |
| Discord/Steam mic "robot voice" | Their echo cancellation fighting the graph's — disable their "echo cancellation" in-app; keep it in ONE place. |

## 11. Vendor DSP/Audio + Quantum Profiles + Per-User Services + Debugging

### 11.1 wireplumber.configPackages (the declarative path)

```nix
{ config, pkgs, ... }: {
  # extraConfig writes /etc/wireplumber/*.conf.d/*.conf (system-wide).
  # configPackages adds derivations shipping $out/share/wireplumber/*.conf.d/*.conf
  # — preferred when the rule set is shared across machines/flake modules:
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-bluez.conf" ''
      monitor.bluez.properties = {
        bluez5.enable-sbc-xq = true
        bluez5.enable-msbc = true
        bluez5.enable-hw-volume = true
      }
    '')
  ];
  # Verify: after rebuild -> ls /etc/wireplumber/wireplumber.conf.d/
  # Per-user override instead: ~/.config/wireplumber/bluetooth.conf.d/ (HM: xdg.configFile)
}
```

### 11.2 systemd user service debugging (PipeWire runs per-user!)

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
journalctl --user -u pipewire -u wireplumber -u pipewire-pulse -b
systemctl --user restart wireplumber   # nixos-rebuild is NOT enough for WP rules
systemctl --user cat pipewire          # see the generated unit + env
pw-dump | head -c 2000                 # graph alive?
```

### 11.3 allowUnfree codecs + bluetooth powerOnBoot vs blueman

```nix
{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;  # for reaper/bitwig + AAC/aptX blobs if used
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;  # false = radio off at boot (privacy/battery); toggle via applet
    # powerOnBoot = true; # true = headphones auto-connect at login (desktop convenience)
  };
  services.blueman.enable = true;  # GUI applet — needs powerOnBoot=false + manual on,
  # OR powerOnBoot=true + auto-connect. Pick one UX: kiosk/desktop = true, laptop = false.
}
```

### 11.4 Per-vendor DSP/audio (Intel SOF / AMD ACP / NVIDIA HDMI)

```nix
{ config, pkgs, ... }: {
  # Intel: Sound Open Firmware — REQUIRED on Tiger Lake+ laptops, else dummy output:
  hardware.firmware = with pkgs; [ sof-firmware alsa-firmware ];
  # Verify: dmesg | grep -i sof; aplay -l shows real card not "Dummy Output"
  # AMD: ACP (Audio CoProcessor) is in-kernel (snd_acp*) + linux-firmware — nothing
  # to add beyond hardware.enableRedistributableFirmware = true;
  # NVIDIA HDMI audio rides the nvidia driver (snd_hda_intel for HDA controller):
  #   hardware.nvidia.modesetting.enable = true;  # else HDMI sink vanishes on Wayland
  #   + wpctl set-profile <hdmi-id> pro-audio if multichannel AVR
  # Powermizer has NO audio effect — it only clocks the GPU (gaming guide §6).
  hardware.enableRedistributableFirmware = true;
}
```

### 11.5 Quantum/latency tuning: gaming vs pro-audio presets

```nix
{ config, ... }: {
  # Gaming/desktop (safe, 21ms): quantum 1024 — default, no xruns on HDA/USB
  # Competitive/rhythm (11ms): quantum 512 — needs rtkit + gamemode
  # Pro-audio (5ms): quantum 256 + pulse.min.req 256/48000 (see wiki PipeWire §Low-latency)
  # USB-interface-only (<3ms): quantum 128 — internal HDA will xrun, use pro-audio profile
  services.pipewire.extraConfig.pipewire."92-quantum-gaming" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 512;
      "default.clock.min-quantum" = 32;
      "default.clock.max-quantum" = 2048;
    };
  };
  # Pro-audio overlay (uncomment for DAW box):
  # services.pipewire.extraConfig.pipewire."93-quantum-pro" = {
  #   "context.properties" = {
  #     "default.clock.quantum" = 256; "default.clock.min-quantum" = 64;
  #   };
  # };
}
```

### 11.6 EasyEffects / Calf per-user services

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ easyeffects calf lsp-plugins ];
  # EasyEffects runs as systemd --user service when enabled in-app; autostart:
  #   HM: services.easyeffects.enable = true; (preferred per-user)
  #   Without HM: desktop autostart .desktop or:
  # systemd.user.services.easyeffects = {
  #   Unit.Description = "EasyEffects DSP";
  #   Install.WantedBy = [ "graphical-session.target" ];
  #   Service.ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
  # };
  # Calf/LSP are LV2 plugins EE loads — no daemon, just packages + preset JSON (§5).
}
```

## 12. Reference Index

- PipeWire docs: <https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/home>
- Quantum/latency mechanics: <https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Performance-tuning>
- WirePlumber docs: <https://pipewire.pages.freedesktop.org/wireplumber/>
- NixOS Wiki PipeWire: <https://wiki.nixos.org/wiki/PipeWire>
- BlueZ config: `man bluetoothd` (BlueZ main.conf keys)
- EasyEffects: <https://github.com/wwmm/easyeffects>
- yabridge: <https://github.com/robbert-vd/yabridge>
- nixpkgs modules: `services/desktops/pipewire/{pipewire,wireplumber}.nix`
- Companions: `Gaming-NixOS.md` §11, `Customization-NixOS.md` (session env), `Virtualization-NixOS.md` (guest audio path)
