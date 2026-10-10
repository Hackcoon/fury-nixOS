# Anonymity & Privacy on NixOS

An exhaustive, independently-usable reference for anonymizing and compartmentalizing activity on NixOS — threat-model-driven, Tor integration, hardened browser profiles, MAC randomization, traffic analysis resistance, and disposable VMs. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual · nixpkgs module sources (`services/security/tor.nix`, `programs/firefox.nix` [SCHEMA], `networking/networkmanager.nix`) · Tor Project docs (bridges, pluggable transports, onion services) · The Hitchhiker's Guide to Online Anonymity (thgtoa) — methodology only, translated to NixOS-native options · Whonix/Qubes compartmentalization patterns adapted for KVM. Schema verified against nixpkgs release-26.05; cross-check <https://search.nixos.org/options> before adopting.

**Companion guides:** `Hardening-NixOS.md` (the foundation — this guide assumes it's applied), `Virtualization-NixOS.md` (disposable VMs), `Networking-NixOS.md` (firewall/VPN layers).

---

## Table of Contents

1. [Threat Models — Picking Your Poison](#1-threat-models-picking-your-poison)
2. [Tor: daemon, browser, bridges, onion services](#2-tor-daemon-browser-bridges-onion-services)
3. [Browser Hardening & Fingerprinting](#3-browser-hardening-fingerprinting)
4. [MAC Randomization & Link-Layer Privacy](#4-mac-randomization-link-layer-privacy)
5. [DNS & Traffic Leaks](#5-dns-traffic-leaks)
6. [Compartmentalization with VMs](#6-compartmentalization-with-vms)
7. [Metadata & File Privacy](#7-metadata-file-privacy)
8. [Physical Anonymity Considerations](#8-physical-anonymity-considerations)
9. [Anti-Forensics Recap](#9-anti-forensics-recap)
10. [Troubleshooting](#10-troubleshooting)
11. [torsocks + DNSPort/TransPort/ControlPort](#11-torsocks-deep-dive--dnsport--transport--controlport)
12. [Bridges webtunnel/snowflake + onion auth + nyx](#12-bridges-webtunnel--snowflake-plugin-lines--nyx-controlport--onion-client-auth)
13. [MAC Per-Link](#13-mac-randomization-per-link-networkmanager-random-vs-stable)
14. [CPU Mitigations + GPU Fingerprinting](#14-cpu-vendor-mitigations-amd-vs-intel-microcode--gpu-fingerprinting)
15. [Reference Index](#15-reference-index)

---

## 1. Threat Models — Picking Your Poison

Every choice below trades convenience for a specific protection. Know which you need:

| Threat | Protections that matter | Sections |
|---|---|---|
| Websites profiling you (ads, trackers) | Browser hardening, fingerprint resistance | §3 |
| Your ISP seeing destinations | DoT/DoH (already in your config), Tor for sensitive | §2, §5 |
| Linking your identity to activity online | Tor circuits, compartmentalized VMs | §2, §6 |
| A service learning your real IP | Tor, or VPN chain for non-Tor traffic | §2 |
| Local forensics on your machine | Anti-forensics from `Hardening-NixOS.md` §20 | §9 |
| Physical/network proximity attacks | Hardening guide's attack-surface reduction | — |

**Golden rule:** Tor for anonymity, VPN for geo-privacy, DoT for ISP nosiness, compartmentalization for everything. A VPN provider knows your IP — it is *not* anonymity, only a trust shift.

## 2. Tor: daemon, browser, bridges, onion services

### 2.1 The Tor daemon as a SOCKS proxy

```nix
{ config, pkgs, ... }: {
  # The system Tor daemon — provides a SOCKS5 proxy on port 9050 and
  # supports hosting onion services. NOT needed just to run Tor Browser
  # (the browser bundles its own Tor); needed for:
  #   - proxying arbitrary apps through Tor
  #   - hosting .onion services
  #   - Torsocks-wrapped CLI tools
  services.tor = {
    enable = true;
    client.enable = true;

    # The SOCKS listener local apps can use (127.0.0.1:9050 by default).
    # client.enable additionally provides the fast SOCKS port on 9063
    # (SocksPort with Isolate handling for some GUIs):
    settings = {
      # Only accept local SOCKS connections — default, being explicit:
      SocksPort = [ "127.0.0.1:9050 IsolateDestAddr IsolateDestPort" ];
      # Isolate flags: separate Tor circuit per destination address AND
      # port — a site can't be correlated with another via same-circuit.

      # Exit policy: we only relay as a client (no exit node).
      # Freeform torrc key (string or list of strings):
      ExitPolicy = [ "reject *:*" ];
    };

    # Bandwidth caps if you're worried about traffic-shape analysis of
    # your own relay participation:
    # settings.BandwidthRate = "1 MByte";
  };

  # CLI tools that transparently route per-command through Tor:
  environment.systemPackages = with pkgs; [
    torsocks      # torsocks curl ... / torsocks ssh ...
    nyx           # live Tor circuit/bandwidth monitor (TUI)
  ];
}
```

### 2.2 Bridges & pluggable transports (censorship resistance)

When the network you're on blocks/penalizes Tor connections:

```nix
{ config, pkgs, ... }: {
  services.tor = {
    enable = true;
    client.enable = true;

    # Use bridges instead of direct directory authority connections:
    settings = {
      UseBridges = true;

      # OBFS4 makes Tor traffic look like random bytes rather than TLS
      # to a known relay. Freeform torrc keys:
      ClientTransportPlugin = "obfs4 exec ${pkgs.tor}/bin/obfs4proxy";

      # Get bridge lines from https://bridges.torproject.org (email/RAVEN
      # options too) and paste them here — each is one string:
      Bridge = [
        # "obfs4 IP:PORT FINGERPRINT cert=... iat-mode=0"
      ];
    };
  };
}
```

Snowflake (WebRTC proxy volunteer bridges) is available at runtime via Tor Browser settings without daemon config — for the daemon, obfs4 is the reliable declarative option.

### 2.3 Hosting an onion service

```nix
{ config, pkgs, ... }: {
  services.tor = {
    enable = true;
    relay.enable = true;

    # Onion services are declared per local port. THIS machine hosts
    # a service, reachable at the generated .onion — no exit to the
    # clearnet, no port forwarding, NAT-piercing by design:
    relay.onionServices = {
      # The key name — becomes <something>.onion (v3). Key material
      # persists in /var/lib/tor/onion/<name> so the address is stable.
      myservice = {
        version = 3;
        secretKey = null;  # let tor generate & persist it
        # Map the onion's virtual port 80 to a local service:
        map = [{ port = 80; target = { addr = "127.0.0.1"; port = 8080; }; }];
      };
    };
  };

  # Read your onion hostname after boot:
  #   sudo cat /var/lib/tor/onion/myservice/hostname
}
```

### 2.4 Tor Browser

```nix
{ config, pkgs, ... }: {
  # Tor Browser bundles its own Tor — do NOT proxy it through the
  # system daemon (double-hop gains nothing and breaks circuit control):
  environment.systemPackages = with pkgs; [
    tor-browser-bundle-bin
  ];
}
```

Tor Browser is *the* anti-fingerprinting browser: uniform rendering, letterboxing, per-circuit isolation. For threat level "anonymous", never use ordinary Firefox/Chromium — no amount of about:config matches its fingerprint uniformity across users.

## 3. Browser Hardening & Fingerprinting

For the threat level "private" (not anonymous) on normal browsers:

```nix
{ config, pkgs, ... }: {
  # Firefox with declarative config (policies.json equivalent):
  programs.firefox = {
    enable = true;

    # NOTE [SCHEMA]: policies shape; keys mirror mozilla policy templates.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = true;    # no mozilla sync (or enable consciously)
      PasswordManagerEnabled = false;   # use a real password manager
      DoNotTrack = true;
      # First-party isolation & resist fingerprinting (via about:config
      # locking — these map to user.js settings):
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        # Cryptomining/fingerprinting are Category flags, not separate keys:
        Category = "Strict";
      };
      # Extension allowlist — block sideloading (malware vector):
      ExtensionSettings = {
        "*".installation_mode = "blocked";
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi";
        };
      };
    };
  };

  # Beyond browsers: DNS-level blocking for the whole system is in
  # Networking-NixOS.md (unbound blocklists) — belt & suspenders.
}
```

**Fingerprint reality check:** fonts list, canvas, WebGL, timing — all leak. Real fingerprint defense comes from: (1) Tor Browser's uniformity, or (2) accepting partial defenses with uBlock Origin (blocks the *trackers*, not the fingerprint) + `privacy.resistFingerprinting` (breaks some sites). Choose consciously per activity, then compartmentalize by profile.

## 4. MAC Randomization & Link-Layer Privacy

```nix
{ config, pkgs, ... }: {
  networking.networkmanager = {
    enable = true;

    # Randomize the MAC when SCANNING (hides you from passive listeners
    # while walking around) — near-zero breakage:
    wifi.scanRandMacAddress = true;

    # Per-connection random/stable MACs:
    #   "preserve"  = keep hardware MAC (leaks device identity per network)
    #   "permanent" = hardware MAC
    #   "random"    = new random MAC every connection (best privacy;
    #                captive portals may forget you)
    #   "stable"    = per-network random MAC (same each revisit) — good
    #                balance for home/work while traveling
    ethernet.macAddress = "stable";
    wifi.macAddress = "random";
  };

  # Disable IPv6 privacy-killing defaults? The opposite: use temporary
  # IPv6 addresses that rotate (kernel default) and PREFER them:
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.use_tempaddr" = 2;   # 2 = prefer temporary
    "net.ipv6.conf.default.use_tempaddr" = 2;
  };

  # Hostname/machine-id — see Hardening-NixOS.md §17. On public networks
  # also avoid mDNS advertisement:
  services.avahi = {
    enable = false;   # unless you genuinely use printer/service discovery
  };
}
```

## 5. DNS & Traffic Leaks

Your config already pins Quad9 DoT (in your `configuration.nix`). The anonymity additions:

```nix
{ config, pkgs, ... }: {
  # 1. Apps that bypass systemd-resolved (hardcoded DoH, ESNI/ECH):
  #    unavoidable at OS level per-app; mitigate with compartmentalization (§6).

  # 2. WebRTC leaks (browsers reveal local/real IP via STUN):
  #    Firefox: disable WebRTC entirely for sensitive profiles, or use
  #    Tor Browser (which neutered STUN).

  # 3. NTP-based correlation: your clock skew + timezone leaks info.
  #    Tor Browser overrides timezone to UTC. For anonymous sessions do
  #    the same in the VM/kompartment: set TZ=UTC, and consider
  #    disabling NTP with a skewed idea of time:
  # services.timesyncd.enable = false;  # only for dedicated anon VMs

  # 4. Firewall-kill-switch for VPN/Tor cases — see Networking-NixOS.md
  #    §"fail-closed VPN" — the pattern that prevents leak-on-disconnect.
}
```

## 6. Compartmentalization with VMs

The Qubes-style pattern, on your existing KVM stack (Virtualization-NixOS.md):

```nix
{ config, pkgs, lib, ... }: {
  # A disposable, network-isolated VM for sensitive tasks:
  virtualisation.libvirtd.enable = true;

  # Create via CLI once (or virt-manager):
  #   virt-install --name anon --memory 4096 --vcpus 4 \
  #     --disk path=/var/lib/libvirt/images/anon.qcow2,size=40,format=qcow2 \
  #     --network none \          # ← the point: NO network device at all
  #     --graphics spice --boot uefi
  #
  # Variants by compartment purpose:
  #   --network network:default   # NAT out (normal traffic)
  #   redirtp via host torsocks   # route specific traffic through Tor
  #   --network none              # airgapped document work
  #
  # Snapshot discipline: virt-clone before each sensitive session,
  # destroy after. Persistent compromise dies with the clone.

  # Disposable Firefox browsing VM example — define the network as a
  # torsocks-wrapped bridge is complex; simpler: per-VM DoH + MAC random
  # + disposable disk. For TRUE tor-only VMs use Whonix-style two-VM
  # split (gateway VM owns tor, workstation VM routes through it):
  #
  #   Gateway VM: services.tor.enable + SocksPort on its libvirt net
  #   Workstation VM: default route = gateway VM, Tor Browser
  # This is the Whonix architecture — compartmentalized Tor so a
  # compromised workstation still can't learn your IP.
}
```

## 7. Metadata & File Privacy

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    exiftool          # inspect & strip file metadata:
                      #   exiftool -all= sensitive.pdf
    mat2              # metadata anonymisation toolkit (many formats):
                      #   mat2 sensitive.docx
    # For images shared online, strip GPS/EXIF *before* upload — this
    # is the #1 real-world deanonymization vector after social opsec.
  ];

  # Printer tracking dots: real but no software defense; print via
  # trusted printer or don't print sensitive material.
}
```

## 8. Physical Anonymity Considerations

- **Buy hardware anonymously** (cash, no loyalty cards, no warranty registration) — thgtoa's hardware chapter; NixOS can't help here.
- **Serial/DMI identifiers:** see Hardening-NixOS.md §17 for machine-id/hostname; full SMBIOS spoofing is not practical on consumer boards.
- **Wi-Fi proximity:** your Wi-Fi adapter's MAC near a location is a tracking signal — §4 randomization + Wi-Fi off when not in use (`nmcli radio wifi off`).
- **Bluetooth:** disable entirely if unused: `hardware.bluetooth.enable = false;` + `boot.blacklistedKernelModules = [ "btusb" "bluetooth" ];` (hardening guide §15 pattern).

## 9. Anti-Forensics Recap

From `Hardening-NixOS.md` — the anonymity-relevant subset: full-disk encryption (§7), no swap or encrypted swap (§20), core dumps off (§20), journald volatile/limited, `tmpfs` for `/tmp` — plus this guide's disposable VM pattern for anything you'd rather never touched persistent storage at all.

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| Tor won't bootstrap (stuck at 5–15%) | Direct connections blocked — §2.2 bridges + obfs4. Check `nyx` for which bootstrap stage. |
| Tor Browser says "another Tor instance running" | You launched Tor Browser while routing it via torsocks/system daemon. Never wrap Tor Browser itself. |
| App refuses SOCKS proxy | Use `torsocks <app>` wrapper, or route via compartmentalized VM (§6). Some apps hardcode DNS — VM helps. |
| Captive portals forget me after MAC randomization | Expected with `wifi.macAddress = "random"` — set that network's connection profile to stable/permanent in NM settings. |
| Circuit feels slow | Normal — Tor latency is 200ms-2s+. Check `nyx` circuits; avoid exits flagged for load. |
| My .onion changed after rebuild | `secretKey` null + `/var/lib/tor/onion` wiped (impersonate state loss). Back up `/var/lib/tor/onion/<name>` — stateful, not in the store. |
| DNS works but .onion doesn't resolve | Apps need SOCKS through Tor daemon, not DoT DNS. `.onion` resolution happens inside Tor's SOCKS handler, not via system DNS. |

## 11. torsocks Deep-Dive + DNSPort / TransPort / ControlPort

```nix
{ config, pkgs, ... }: {
  # Declarative torsocks.conf — NOT just the package (verified:
  # nixos/modules/services/security/tor.nix -> services.tor.torsocks.*):
  services.tor.torsocks = {
    enable = true;
    server = "127.0.0.1:9050";        # slow SOCKS (safe default)
    fasterServer = "127.0.0.1:9063";  # fast SOCKS (client.enable port)
    # allowInbound = false;           # keep false — no inbound listen()
  };
  environment.systemPackages = with pkgs; [
    torsocks      # torsocks curl ... / torsocks ssh ...
    # torsocks-faster wrapper is auto-added when torsocks.enable = true
  ];

  services.tor = {
    enable = true;
    client.enable = true;
    # Transparent + DNS ports as TYPED options (preferred over freeform
    # settings.TransPort — module wires 9040/9053 + AutomapHostsOnResolve):
    client.transparentProxy.enable = true;  # -> settings.TransPort 127.0.0.1:9040
    client.dns.enable = true;               # -> settings.DNSPort 127.0.0.1:9053
    settings = {
      # Explicit freeform equivalents (if you need custom addr/Isolate flags):
      # DNSPort = [{ addr = "127.0.0.1"; port = 9053; }];
      # TransPort = [{ addr = "127.0.0.1"; port = 9040; }];
      # ControlPort = [{ port = 9051; }];  # nyx needs this OR controlSocket
      AutomapHostsOnResolve = true;
    };
    # Unix control socket alternative (no TCP port exposed):
    controlSocket.enable = true;  # -> /run/tor/control (GroupWritable)
  };
  # Usage:
  #   torsocks curl https://check.torproject.org
  #   torsocks-faster curl https://example.com  # HTTP(S)-optimized path
  #   nyx  # needs ControlPort/socket + CookieAuthentication (see §12)
}
```

## 12. Bridges: webtunnel + snowflake plugin lines + nyx ControlPort + onion client auth

```nix
{ config, pkgs, ... }: {
  services.tor = {
    enable = true;
    client.enable = true;
    settings = {
      UseBridges = true;
      # OBFS4 (lyrebird is the maintained obfs4proxy successor in nixpkgs):
      # ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/lyrebird";
      # WEBTUNNEL (mimics HTTPS WebSocket — best against SNI fingerprinting):
      ClientTransportPlugin = [
        "obfs4 exec ${pkgs.obfs4}/bin/lyrebird"
        "webtunnel exec ${pkgs.webtunnel}/bin/client"
        # Snowflake client (WebRTC — needs snowflake package if offered as bridge):
        # "snowflake exec ${pkgs.snowflake}/bin/client"
      ];
      Bridge = [
        # "obfs4 IP:ORPort FINGERPRINT cert=... iat-mode=0"
        # "webtunnel IP:443 FINGERPRINT url=https://..."
        # "snowflake ... (broker URL from bridges.torproject.org)"
      ];
    };
    # Onion CLIENT auth (access private .onions needing a key):
    client.onionServices = {
      # "myprivatesite" = {
      #   clientAuthorizations = {
      #     "site1" = { key = "4:..."; };  # x25519 privkey from service operator
      #   };
      # };
    };
  };

  # Run a Snowflake PROXY to help others (safe, no exit traffic):
  # services.snowflake-proxy = { enable = true; capacity = 10; };

  # nyx live monitor — needs ControlPort + cookie auth:
  services.tor.settings = {
    ControlPort = [{ port = 9051; }];
    CookieAuthentication = true;
  };
  environment.systemPackages = with pkgs; [ nyx ];
  # users.users."fury".extraGroups = [ "tor" ];  # read cookie without sudo
  # nyx -> check bootstrap %, circuits, bandwidth. Troubleshooting §10.
}
```

## 13. MAC Randomization Per-Link (NetworkManager random vs stable)

```nix
{ config, pkgs, ... }: {
  networking.networkmanager = {
    enable = true;
    wifi.scanRandMacAddress = true;  # scanning only — zero breakage
    ethernet.macAddress = "stable";  # per-network stable random (home/work OK)
    wifi.macAddress = "random";      # new MAC every connect (max privacy)
  };
  # Per-CONNECTION override (the surgical tool — stable home, random travel):
  #   nmcli connection show                      # list profiles
  #   nmcli connection modify "Home-WiFi" wifi.cloned-mac-address stable
  #   nmcli connection modify "Cafe-WiFi" wifi.cloned-mac-address random
  #   nmcli connection modify "Wired" ethernet.cloned-mac-address stable
  # Values: preserve|permanent|random|stable — stable = same fake MAC per SSID,
  # random = fresh each connect (captive portals forget you — expected).
}
```

## 14. CPU Vendor Mitigations (AMD vs Intel microcode) + GPU Fingerprinting

```nix
{ config, pkgs, ... }: {
  # Microcode per VENDOR — pick yours (both harmless if set, only matching loads):
  hardware.cpu.amd.updateMicrocode = true;    # AMD: Zen microcode via linux-firmware
  # hardware.cpu.intel.updateMicrocode = true;  # Intel: microcodeIntel in initrd
  hardware.enableRedistributableFirmware = true;  # required for both blobs

  # Kernel cmdline mitigations note (CPU vendor matters):
  # Default mitigations=auto is CORRECT for anonymity hosts (speculative-exec
  # leaks break compartmentalization). Only relax on airgapped gaming boxes:
  # boot.kernelParams = [ "mitigations=auto" ];  # explicit default
  # Intel: ibt=on, retbleed/mds/spectre_v2 handled by microcode + kernel
  # AMD:   amd_pstate + spec_ctrl; Zenbleed fixed via microcode (updateMicrocode!)
  # NEVER set mitigations=off on a Tor/anon host — cross-VM leak vector.
}
```

**GPU vendor fingerprinting (WebGL) note:** your GPU string (`ANGLE: NVIDIA ...` / `AMD ...` / `Intel ...`) + renderer + driver version is a top-3 fingerprinting bit after User-Agent and screen size. Defenses: (1) Tor Browser letterboxing + WebGL click-to-play uniformizes it — never enable WebGL acceleration bypass, (2) ordinary Firefox: `privacy.resistFingerprinting=true` spoofs to generic string (breaks some WebGL sites), (3) per-vendor: NVIDIA proprietary blob reports unique `WEBGL_debug_renderer_info`, AMD RADV vs AMDVLK report different strings (switching drivers changes fingerprint — pick one and stick to it), Intel iGPU reports generic Intel string (largest anonymity set). Compartmentalize: anon VM = Tor Browser only, no extensions that expose GPU via WebGL.

## 15. Reference Index

- Tor Project docs: <https://community.torproject.org/>
- Bridges: <https://bridges.torproject.org/>
- Tor Browser manual: <https://tb-manual.torproject.org/>
- thgtoa (methodology companion): the `thgtoa.pdf` in your Downloads
- Whonix isolation architecture: <https://www.whonix.org/wiki/Documentation>
- nixpkgs tor module source: `nixos/modules/services/security/tor.nix`
- Mozilla policy templates (firefox policies keys): <https://mozilla.github.io/policy-templates/>
- Companions: `Hardening-NixOS.md`, `Virtualization-NixOS.md`, `Networking-NixOS.md`
