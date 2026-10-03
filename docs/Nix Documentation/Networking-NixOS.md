# Networking on NixOS

An exhaustive, independently-usable reference for networking on NixOS — the firewall (iptables/nftables), WireGuard, Mullvad, Tailscale, VPN fail-closed patterns, static IPs, diagnostics, and the network stack layers. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual (networking chapters) · nixpkgs module sources (`services/networking/wg-quick.nix`, `wireguard.nix`, `tailscale.nix`, `mullvad-vpn.nix`, `firewall` modules) · WireGuard upstream docs · Tailscale knowledge base · Mullvad Linux guide. Schema verified against nixpkgs release-26.05; cross-check <https://search.nixos.org/options> before adopting.

**Your baseline:** your `configuration.nix` already runs systemd-resolved with Quad9 DoT — this guide builds around that.

---

## Table of Contents

1. [The Stack: Who Owns What](#1-the-stack-who-owns-what)
2. [NetworkManager vs systemd-networkd](#2-networkmanager-vs-systemd-networkd)
3. [The Firewall (firewall / nftables)](#3-the-firewall)
4. [Port Forwarding & NAT](#4-port-forwarding-nat)
5. [WireGuard (wg-quick & native)](#5-wireguard)
6. [Mullvad VPN (with kill switch)](#6-mullvad-vpn)
7. [Tailscale (mesh VPN)](#7-tailscale)
8. [Fail-Closed VPN Pattern](#8-fail-closed-vpn-pattern)
9. [SSH Hardening Additions](#9-ssh-hardening-additions)
10. [Static IPs, Bridges & VLANs](#10-static-ips-bridges-vlans)
11. [Diagnostics Toolkit](#11-diagnostics-toolkit)
12. [Troubleshooting](#12-troubleshooting)
22. [Reference Index](#22-reference-index)
14. [Per-Interface Firewall](#14-per-interface-firewall)
15. [nftables vs libvirt / Waydroid Chains](#15-nftables-vs-libvirt-waydroid-chains)
16. [WiFi Per-Vendor Firmware](#16-wifi-per-vendor-firmware)
17. [Tailscale MagicDNS vs systemd-resolved Domains](#17-tailscale-magicdns-vs-systemd-resolved-domains)
18. [Mullvad Split-Tunnel](#18-mullvad-split-tunnel)
19. [Bridges vs NetworkManager Conflict](#19-bridges-vs-networkmanager-conflict)
20. [Wake-on-LAN](#20-wake-on-lan)
21. [2.5GbE Realtek: r8125 vs r8169 Driver Choice](#21-25gbe-realtek-r8125-vs-r8169-driver-choice)

---

## 1. The Stack: Who Owns What

```
Applications (browsers, games, curl)
   ↓
Name resolution: systemd-resolved (+ your DoT to Quad9)     ← stays
   ↓
Networking API: NetworkManager (your desktop)               ← §2
   ↓
Linux firewall: networking.firewall (→ iptables) or nftables ← §3
   ↓
Tunnels: WireGuard / Mullvad / Tailscale                    ← §5–8
   ↓
Kernel: netfilter, routing tables, conntrack
```

NixOS rule: **configure the layer that owns the job.** DNS → resolved (done, in your config). Link management → NetworkManager (desktop). Filtering → the firewall module. Don't fight layers with scripts.

## 2. NetworkManager vs systemd-networkd

```nix
{ config, pkgs, ... }: {
  # Desktop (YOUR case) — NetworkManager: tray applet, Wi-Fi scanning,
  # per-network profiles, captive portal handling:
  networking.networkmanager = {
    enable = true;

    # DNS handed to systemd-resolved (already in your config — kept here
    # as the reference pattern):
    dns = "systemd-resolved";

    # Connection profiles persist in /etc/NetworkManager (stateful).
    # Declarative profiles also possible:
    # ensureProfiles.profiles = { ... };   # see nmcli docs for key names
  };

  # wifi powersave — battery vs latency tradeoff (desktops: off):
  networking.networkmanager.wifi.powersave = false;

  # The alternative for servers/headless — systemd-networkd:
  # networking.useNetworkd = true;
  # systemd.network = {
  #   enable = true;
  #   networks."10-lan" = {
  #     matchConfig.Name = "enp5s0";
  #     DHCP = "yes";
  #   };
  # };
  # (Use one or the other. NetworkManager is the right choice for you.)
}
```

## 3. The Firewall

### 3.1 The standard NixOS firewall (iptables backend)

```nix
{ config, pkgs, ... }: {
  networking.firewall = {
    enable = true;

    # Default-deny inbound. Outbound stays open (typical desktop):
    allowedTCPPorts = [ 22 ];      # ssh (or close it & use tailscale §7)
    allowedUDPPorts = [ 51820 ];   # wireguard listen port (§5)

    # Ranges:
    allowedTCPPortRanges = [
      { from = 27036; to = 27037; }   # steam remote play example
    ];

    # Per-interface rules — anything on the LAN is trusted:
    trustedInterfaces = [ "virbr0" ];  # libvirt NAT (VMs → host services)

    # Per-source rules (e.g., allow SSH only from LAN):
    # interfaces."enp5s0" doesn't exist — source filtering:
    extraCommands = ''
      # nft-style would be better (§3.2); iptables syntax here:
      iptables -A nixos-fw -p tcp --dport 22 \
        -s 192.168.1.0/24 -j ACCEPT
      # (the base chain already REJECTs everything not accepted)
    '';

    # Log dropped packets (brief bursts in journal — useful debugging):
    # logRefusedPackets = true;   # rate-limited by default
  };
}
```

### 3.2 nftables backend (the modern way)

```nix
{ config, pkgs, ... }: {
  networking.nftables = {
    enable = true;

    # Flush ALL rules nftables manages on reload — clean slate.
    # WARNING: this also flushes libvirt's dynamic chains (virbr0 NAT);
    # with VMs prefer false, or keep the virbr0 forward accepts below:
    flushRuleset = true;
  };

  # The firewall module auto-detects nftables as backend:
  networking.firewall = {
    enable = true;
    # ... same allowedTCPPorts etc. as above, now rendered via nft ...
  };

  # Full manual control (nixos-fw becomes yours entirely):
  networking.nftables.ruleset = ''
    table inet filter {
      chain input {
        type filter hook input priority 0;
        # established/related: allow
        ct state established,related accept
        # loopback: allow
        iif "lo" accept
        # icmp/ping: allow (rate-limited)
        icmp type echo-request limit rate 10/second accept
        # ssh from LAN only:
        iifname "enp5s0" tcp dport 22 accept
        # everything else: drop
        drop
      }
      chain forward {
        type filter hook forward priority 0;
        # established/related first, then virbr0 or VM NAT breaks:
        ct state established,related accept
        iifname "virbr0" accept
        oifname "virbr0" accept
        drop
      }
    }
  '';
}
```

> Waydroid/Libvirt note: when `networking.nftables.enable = true`, services like waydroid auto-switch to nft variants (`waydroid-nftables` package) — mostly transparent, occasionally a module lag (check options).

## 4. Port Forwarding & NAT

```nix
{ config, pkgs, ... }: {
  # When THIS machine is the router (or exposes a VM's port):

  # 1. Kernel IP forwarding:
  # NOTE: Hardening-NixOS.md sets ip_forward=0. Profile-dependent —
  # router/VM-host needs 1 here, hardened desktop keeps 0:
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # 2. NAT (masquerade) — with the firewall module:
  networking.nat = {
    enable = true;
    internalInterfaces = [ "virbr0" ];   # who gets NAT'd
    externalInterface = "enp5s0";        # out which interface
  };

  # 3. Individual port-forwards (host:5901 → VM:5901):
  networking.firewall.extraCommands = ''
    iptables -t nat -A PREROUTING -i enp5s0 -p tcp --dport 5901 \
      -j DNAT --to-destination 192.168.122.10:5901
    iptables -A FORWARD -p tcp -d 192.168.122.10 --dport 5901 -j ACCEPT
  '';
}
```

## 5. WireGuard

### 5.1 wg-quick (the simple, declarative way)

```nix
{ config, pkgs, ... }: {
  networking.wg-quick.interfaces = {
    # Interface name — becomes "wg0":
    wg0 = {
      # The PRIVATE key from a secret — NEVER inline (Secrets guide §6):
      privateKeyFile = config.sops.secrets."wg-private".path;

      # Port this host LISTENS on (only needed if peers connect TO you):
      listenPort = 51820;

      # This interface's addresses inside the tunnel:
      address = [ "10.10.0.2/24" "fd42:42:42::2/64" ];

      # PEERS — one per remote machine:
      peers = [
        {
          publicKey = "PEER-PUBLIC-KEY-xxxx=";     # public keys are fine inline
          # Server-style peer:
          endpoint = "203.0.113.5:51820";          # peer's real address
          allowedIPs = [ "10.10.0.0/24" ];         # what routes via this peer
          persistentKeepalive = 25;                # NAT traversal keepalive
        }
      ];

      # Route ALL traffic through the tunnel (full-tunnel):
      # set allowedIPs = [ "0.0.0.0/0" "::/0" ] on the EXIT peer, and:
      # postUp/Down for policy routing are usually unnecessary —
      # wg-quick handles 0/0 with its own fwmark magic.
    };
  };

  # Firewall: allow inbound WireGuard:
  networking.firewall.allowedUDPPorts = [ 51820 ];
  # If this host IS the exit/server, also:
  # networking.firewall.trustedInterfaces = [ "wg0" ];
}
```

### 5.2 Native (systemd-networkd) WireGuard

For networkd servers — keys via `wireguard` section, peers list, `networking.wireguard.interfaces`. More moving parts, better for complex routing. Desktop → stay with wg-quick.

### 5.3 Generating keys

```bash
# One-liner pair generation:
nix-shell -p wireguard-tools --run 'wg genkey | tee private | wg pubkey > public'
# 'private' → sops secret (Secrets guide), 'public' → peer config
```

## 6. Mullvad VPN

```nix
{ config, pkgs, ... }: {
  # The service (daemon + CLI):
  services.mullvad-vpn = {
    enable = true;

    # Block ALL network traffic until Mullvad connects at boot:
    # (prevents the boot-time leak window):
    enableEarlyBootBlocking = true;

    # Wrapper for apps that must BYPASS the VPN (e.g., banking):
    enableExcludeWrapper = true;   # provides 'mullvad-exclude <cmd>'
  };

  # Desktop app also:
  environment.systemPackages = [ pkgs.mullvad-vpn ];

  # Usage: log in with account number, then:
  #   mullvad relay set location se mma      # exit in Malmö, Sweden
  #   mullvad lockdown-mode set on            # hard kill-switch (no LAN!)
  #   mullvad exclude add 192.168.1.0/24     # keep LAN reachable
  # NOTE: verify split-tunnel vs exclude naming on your version
  # (`mullvad --help`) — CLI renamed this between releases.
}
```

Mullvad + resolved DoT: DNS inside the tunnel uses Mullvad's resolvers; your Quad9 DoT still governs when disconnected.

## 7. Tailscale

```nix
{ config, pkgs, ... }: {
  services.tailscale = {
    enable = true;

    # Router-ish features need explicit opt-in per direction:
    useRoutingFeatures = "both";   # "client"|"server"|"both"|"none"
    # ↑ enables subnet routing/exit node forwarding. "none" for plain.
    # NOTE: "both" is still valid (client+server); "server" below is exit-node-only.

    # Open needed firewall ports for the mesh:
    openFirewall = true;

    # Auth — one-time via `tailscale up` interactively is normal.
    # Declarative for headless:
    # authKeyFile = config.sops.secrets."ts-authkey".path;
  };

  # MagicDNS needs these in resolved (the module usually wires it;
  # explicit form if you override nameservers like Quad9):
  # networking.nameservers + tailscale plugin config — if MagicDNS
  # breaks, see §12 troubleshooting.

  # Exit node usage: tailscale up --exit-node=eu-fra-wg-001
  # Advertise YOUR machine as exit node:
  # services.tailscale.useRoutingFeatures = "server";
  # + tailscale up --advertise-exit-node --accept-routes
}
```

Tailscale vs WireGuard-raw: Tailscale = identity-based mesh with NAT traversal and ACLs ( coordination via their coordination server, wire is still WireGuard). Raw wg = you own everything, fewer moving parts, manual endpoint management.

## 8. Fail-Closed VPN Pattern

The leak-on-disconnect problem and the declarative fix:

```nix
{ config, pkgs, ... }: {
  # Pattern: firewall marks the VPN interface as the ONLY egress.
  # If the tunnel drops, packets have no route out — nothing leaks.

  networking.wg-quick.interfaces.wg0 = {
    address = [ "10.10.0.2/32" ];
    privateKeyFile = config.sops.secrets."wg-private".path;
    peers = [{
      publicKey = "EXITNODEPUB=";
      endpoint = "203.0.113.5:51820";
      allowedIPs = [ "0.0.0.0/0" ];      # default route INTO tunnel
    }];
    # wg-quick with 0/0 auto-installs policy routing with fwmark —
    # traffic CANNOT bypass because the main table's default route
    # is removed. Kill-switch behavior built-in.
  };

  # For non-wg VPNs (openvpn etc.) — manual kill-switch via firewall:
  networking.firewall.extraCommands = ''
    # Allow out ONLY via wg0 + lo:
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -o wg0 -j ACCEPT
    # Allow established:
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
    # Allow LAN (optional — decide consciously):
    iptables -A OUTPUT -d 192.168.1.0/24 -j ACCEPT
    # Drop the rest:
    iptables -A OUTPUT -j DROP
  '';
}
```

## 9. SSH Hardening Additions

Full SSH hardening lives in `Hardening-NixOS.md` §15. The networking-native additions:

```nix
{ config, ... }: {
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;   # keys only
      PermitRootLogin = "no";
    };
    # Host keys from secrets (not regenerated per-reinstall):
    # hostKeys = [{ path = config.sops.secrets."ssh_host_ed25519".path; type = "ed25519"; }];
  };

  # Rate-limit new SSH connections at the firewall layer:
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 22 \\
      -m recent --name sshbomb --rcheck --seconds 60 --hitcount 4 -j DROP
    iptables -A nixos-fw -p tcp --dport 22 \\
      -m recent --name sshbomb --set -j ACCEPT
  '';

  # Or fail2ban (jails configured in the self-hosting guide):
  services.fail2ban.enable = true;
}
```

## 10. Static IPs, Bridges & VLANs

```nix
{ config, pkgs, ... }: {
  # Static IP with NetworkManager is per-connection state; the
  # declarative route for a server NIC is networkd, but on NM desktops:
  # nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.50/24 \
  #   ipv4.gateway 192.168.1.1 ipv4.method manual
  # persists across rebuilds (NM owns its files).

  # Bridges (for VMs — see Virtualization guide §7):
  networking.bridges.br0.interfaces = [ "enp5s0" ];

  # VLANs:
  # vlans."enp5s0.10" = { id = 10; interface = "enp5s0"; };

  # Interfaces get predictable names; find yours: `ip a`
  # Disable predictable names only for embedded/debug cases:
  # networking.usePredictableInterfaceNames = false;
}
```

## 11. Diagnostics Toolkit

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Layered "why is the network broken" kit:
    dig              # DNS: dig +short example.com @9.9.9.9
    mtr              # combined traceroute+ping, per-hop loss
    tcpdump          # packet capture (sudo tcpdump -i any port 53)
    nmap             # port/service scanning (nmap -sV host)
    wireshark        # deep packet inspection GUI
    nethogs          # per-PROCESS bandwidth ("what's uploading?!")
    iftop            # per-connection bandwidth
    iperf3           # raw throughput tests between two hosts
    netcat           # arbitrary port tests
    fdisk
    ethtool          # link status, negotiated speed
    pciutils         # lspci (NICs)
    # curl everywhere already; httpie for readable REST debugging
  ];
}
```

```bash
# The universal 5-minute triage sequence:
ip a                       # 1. do I have an interface & address?
ip route                   # 2. is there a default route? via what?
ping -c3 9.9.9.9           # 3. does raw IP work? (no DNS involved)
resolvectl status          # 4. what resolver, is DoT up?
dig example.com            # 5. name resolution working?
curl -v https://site       # 6. app layer: TLS, proxy, headers
```

## 12. Troubleshooting

| Symptom | Fix |
|---|---|
| DoT broken after adding a VPN | VPN client replaced resolv.conf. With Mullvad/Tailscale this is expected while connected (their resolvers). Check `resolvectl status` shows the tunnel DNS. |
| VMs have no internet after firewall change | `trustedInterfaces` lost `virbr0`, or NAT (`networking.nat`) disabled — §4. |
| wg-quick interface won't start | Key file unreadable (sops ownership), endpoint typo, or UDP 51820 blocked upstream. `journalctl -u wg-quick@wg0`. |
| Tailscale MagicDNS not resolving | resolved integration — ensure `services.resolved.enable` and that you didn't override `networking.nameservers` in a way that strips the 100.100.100.100 resolver. |
| Everything resolves but one app | App has its own DNS (DoH browser, hardcoded 8.8.8.8) — per-app fix, or route port 53 through your firewall. |
| High latency to everything | Check for VPN double-hop (Mullvad + Tailscale both active) — `ip route` shows two default paths. |
| nftables ruleset errors at boot | `nft -c -f <ruleset>` validates syntax; NixOS option is rendered to a file under /etc — find it in the error output. |
| SSH works from LAN, not remote | `extraCommands` ordering — your accept must come BEFORE the default REJECT in nixos-fw, or the port isn't in allowedTCPPorts. |

## 14. Per-Interface Firewall

Global `allowedTCPPorts` opens a port on **every** interface (LAN + VPN + VM bridges). Per-interface rules scope it:

```nix
{ config, pkgs, ... }: {
  networking.firewall = {
    enable = true;

    # Global: truly public services only (usually empty on a desktop):
    allowedTCPPorts = [ ];

    # Per-interface — the pattern you want for LAN-only services:
    interfaces = {
      # LAN NIC only — SSH reachable from LAN, NOT from wg0/tailscale0:
      "enp5s0".allowedTCPPorts = [ 22 ];

      # VPN mesh only — e.g. expose Syncthing / HTTP to tailnet peers:
      "tailscale0".allowedTCPPorts = [ 8384 8080 ];

      # VM bridge only — host services for guests (DNS, HTTP cache):
      "virbr0".allowedTCPPorts = [ 53 80 ];

      # Ranges work per-interface too:
      # "enp5s0".allowedTCPPortRanges = [
      #   { from = 1714; to = 1764; }   # KDE Connect example, LAN only
      # ];
    };

    # Trust VM/container bridges wholesale (skips filtering on them):
    trustedInterfaces = [ "virbr0" "waydroid0" ];
  };
}
```

Rules of thumb:
- `interfaces."<name>".allowed*` = scoped hole. `allowed*` at top level = hole everywhere.
- Interface names are predictable (`ip a` to confirm — `enp5s0` is THIS board's name, not portable).
- `trustedInterfaces` bypasses filtering entirely on that iface — use only for NAT bridges you control (virbr0/waydroid0), never for a physical uplink.
- Verify live: `sudo nft list ruleset` (nft backend) or `sudo iptables -L nixos-fw -n -v`.

## 15. nftables vs libvirt / Waydroid Chains

The conflict: `networking.nftables.flushRuleset = true` wipes **every** table nftables manages on reload — including libvirt's `virbr0` NAT/forward chains and Waydroid's `waydroid0` rules, which are added dynamically at service start, not via Nix.

```nix
{ config, pkgs, ... }: {
  networking.nftables.enable = true;

  # With VMs/containers on this host, prefer false — Nix then only
  # manages its own `nixos-fw` table and leaves virbr0/waydroid chains alone:
  networking.nftables.flushRuleset = false;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "virbr0" "waydroid0" ];
  };

  # libvirt side (see Virtualization guide §7):
  # virtualisation.libvirtd.enable = true;
  # networking.nat = {
  #   enable = true;
  #   internalInterfaces = [ "virbr0" ];
  #   externalInterface = "enp5s0";
  # };

  # Waydroid side: when nftables is enabled, the waydroid module
  # auto-selects its nft variant (waydroid-nftables backend) —
  # mostly transparent. If `waydroid show-full-ui` has no network
  # after a firewall rebuild, restart it AFTER the firewall:
  #   sudo systemctl restart nftables.service waydroid-container.service
}
```

Diagnosis:

```bash
sudo nft list ruleset | grep -E 'virbr0|waydroid|nixos-fw'  # who owns what
journalctl -u libvirtd -u waydroid-container --since '10 min ago'
# symptom: guests boot but get no DHCP/DNS = forward chain flushed
# fix: flushRuleset = false + reboot, or restart libvirtd after firewall
```

> Waydroid/Libvirt note (from §3.2, expanded): keep `flushRuleset = false` on any VM/container host. `true` is only for clean router/server boxes with no dynamic-chain services.

## 16. WiFi Per-Vendor Firmware

NixOS ships `hardware.enableRedistributableFirmware = true` by default (covers `linux-firmware`). WiFi breaks when the card needs firmware **outside** that set or a kernel quirk:

```nix
{ config, pkgs, ... }: {
  # Baseline — usually already default-on, explicit here for clarity:
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [
    linux-firmware
    # rtw89-firmware   # only on old kernels; modern linux-firmware bundles rtw89
  ];

  # --- Intel (iwlwifi: AX200/AX210/BE200) ---
  # In-kernel driver, firmware from linux-firmware. Debugging:
  #   dmesg | grep iwlwifi   # missing .ucode = firmware package too old
  # Powersave off for latency (desktops):
  # networking.networkmanager.wifi.powersave = false;   # see §2

  # --- AMD RZ600 / MediaTek (mt7921e/mt7922: RZ616/RZ717) ---
  # In-kernel mt7921e driver. Known bad-firmware windows — if WiFi
  # vanishes after a `linux-firmware` bump, pin/overlay an older
  # linux-firmware or add kernel quirk:
  # boot.kernelParams = [ "mt7921_common.disable_clc=1" ];  # workaround, verify dmesg first
  # boot.kernelModules = [ "mt7921e" ];

  # --- Realtek (rtw88: RTL8821CE/8822CE — WiFi 5) ---
  # In-kernel rtw88. Weak-signal/disconnects → disable powersave + EEE (wired, below):
  # boot.kernelParams = [ "rtw88_core.disable_lps_deep_mode=Y" ];  # verify `modinfo rtw88_core` first

  # --- Realtek (rtw89: RTL8852AE/BE — WiFi 6/6E) ---
  # Kernel ≥5.16 has the driver; needs matching firmware:
  # boot.kernelPackages = pkgs.linuxPackages_latest;  # if card is newer than your kernel
  # hardware.firmware = with pkgs; [ linux-firmware rtw89-firmware ];
}
```

Wired Realtek EEE disable (RTL8111/8168 — your board's fix, canonical form):

```nix
{ config, pkgs, ... }: {
  systemd.services."disable-realtek-eee" = {
    description = "Disable Energy Efficient Ethernet on Realtek NIC";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ethtool}/bin/ethtool --set-eee enp5s0 eee off";
    };
  };
}
```

Verify: `sudo ethtool --show-eee enp5s0` should report `EEE: off`. Check `dmesg | grep -iE 'iwlwifi|mt792|rtw88|rtw89|firmware'` before adding quirks — don't add speculatively.

## 17. Tailscale MagicDNS vs systemd-resolved Domains

MagicDNS serves `100.100.100.100` as a split-DNS resolver for `*.ts.net` names. It fights your Quad9 DoT when resolved doesn't know which domain belongs to which resolver:

```nix
{ config, pkgs, ... }: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";   # plain client; "server"/"both" only if exit-node
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "true";
      DNSSEC = "allow-downgrade";
      # Keep Quad9 global (your baseline):
      # DNS = [ "9.9.9.9#dns.quad9.net" "149.112.112.112#dns.quad9.net" ];
    };
    # Scope tailnet names to the tailscale interface so MagicDNS
    # answers *.ts.net and Quad9 answers everything else:
    # (verify key name on your release — `man resolved.conf` / search
    #  for services.resolved + Domains; per-link Domains= is the mechanism)
    # extraConfig = ''
    #   [Resolve]
    #   Domains=~ts.net
    # '';
  };

  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
  ];
}
```

Escape hatches:
- MagicDNS breaks Quad9: `tailscale up --accept-dns=false` (Tailscale stops touching resolved; you lose `*.ts.net` short names, keep DoT).
- MagicDNS works but leaks: `resolvectl status` must show `tailscale0` with `Current Scopes: DNS` and `DefaultRoute: no` — if tailscale0 becomes default route, ALL DNS goes to 100.100.100.100.
- Per-connection NM override (§2 `ignore-auto-dns`) does NOT affect tailscale0 — that link is owned by tailscaled, not NM.

## 18. Mullvad Split-Tunnel

Two mechanisms, different names across releases — check `mullvad --help` on yours:

```nix
{ config, pkgs, ... }: {
  services.mullvad-vpn = {
    enable = true;
    enableEarlyBootBlocking = true;  # no boot-time leak window
    enableExcludeWrapper = true;     # provides `mullvad-exclude <cmd>`
  };
  environment.systemPackages = [ pkgs.mullvad-vpn ];
}
```

```bash
# App-level bypass (newer CLI: `exclude`, older: `split-tunnel`):
mullvad exclude add /usr/bin/firefox        # this app bypasses VPN
mullvad exclude list
# ...or launch one-shot without touching saved rules:
mullvad-exclude firefox                     # wrapper from enableExcludeWrapper

# LAN always needs an explicit carve-out under lockdown:
mullvad lockdown-mode set on                # hard kill-switch (blocks LAN too!)
mullvad lan set allow                       # ...then re-allow LAN explicitly

# Relay pinning (exit selection):
mullvad relay set location se mma
mullvad status                              # verify: Connected + correct city
```

Caveat: `mullvad-exclude` uses network namespaces — it does NOT work for services (systemd units), only interactive commands. For a service that must bypass VPN, bind it to the LAN interface explicitly instead.

## 19. Bridges vs NetworkManager Conflict

Declaring `networking.bridges.br0.interfaces = [ "enp5s0" ]` while NetworkManager also manages `enp5s0` = two owners, one link. Tell NM to back off:

```nix
{ config, pkgs, ... }: {
  # Bridge for VMs (libvirt macvtap alternative — see Virtualization guide):
  networking.bridges.br0.interfaces = [ "enp5s0" ];

  # Tell NetworkManager the bridge + its members are NOT its job:
  networking.networkmanager.unmanaged = [
    "interface-name:br0"
    "interface-name:vnet*"
    "interface-name:virbr*"
    # "interface-name:enp5s0"   # only if the bridge fully owns the NIC
  ];

  # Static on the bridge itself (host address lives on br0, not enp5s0):
  # systemd.network.networks."10-br0" = {
  #   matchConfig.Name = "br0";
  #   address = [ "192.168.1.50/24" ];
  #   gateway = [ "192.168.1.1" ];
  # };
}
```

Rule: the IP lives on the bridge (`br0`), never on the member (`enp5s0`). If NM shows `enp5s0` as "connected" AND `br0` exists, the unmanaged list is wrong — `journalctl -u NetworkManager` shows the fight.

## 20. Wake-on-LAN

```nix
{ config, pkgs, ... }: {
  # Declarative WoL (wakes on magic packet):
  networking.interfaces.enp5s0.wakeOnLan.enable = true;

  # Manual equivalent (debug / non-declarative NICs):
  # systemd.services."wol-enp5s0" = {
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp5s0 wol g";
  #   };
  # };
}
```

```bash
ethtool enp5s0 | grep Wake-on   # expect `g` (magic packet) present
# From LAN: wakeonlan <MAC>  (package: wol / etherwake)
# BIOS must also enable PCI/PCIe wake — NixOS can't do that part.
# Suspend (S3) wakes fine; full power-off (S5) needs PSU + board support.
```

## 21. 2.5GbE Realtek: r8125 vs r8169 Driver Choice

| Your chip (lspci) | Driver | NixOS wiring |
|---|---|---|
| RTL8111/8168 (1 GbE) | in-kernel `r8169` | nothing — stock kernel, plus EEE-off service (§16) if flapping |
| RTL8125B (2.5 GbE) | out-of-tree `r8125` (Realtek vendor) | `boot.extraModulePackages` below |
| RTL8125B on very new kernels | in-kernel `r8169` may already claim it | prefer in-kernel first, vendor only if link unstable |

```nix
{ config, pkgs, ... }: {
  # ONLY for RTL8125B that misbehaves on r8169 (link flap, no 2.5G negotiate):
  # boot.kernelModules = [ "r8125" ];
  # boot.extraModulePackages = with config.boot.kernelPackages; [ r8125 ];
  # boot.blacklistedKernelModules = [ "r8169" ];  # let vendor driver claim it

  # Verify BEFORE choosing:
  #   lspci | grep -i ethernet        # which RTL chip exactly
  #   ethtool enp5s0 | grep Speed     # negotiated vs expected
  #   dmesg | grep -iE 'r8169|r8125'  # which driver actually bound
}
```

Prefer the in-kernel `r8169` unless you have a symptom — the vendor `r8125` rebuilds out-of-tree on every kernel bump (slower upgrades, Secure Boot signing burden with Lanzaboote — see modularization-plan vendor notes).

## 22. Reference Index

- NixOS networking options: <https://search.nixos.org/options> (networking.\*) — verify `networking.firewall.interfaces.<name>.*`, `networking.nftables.flushRuleset`, `networking.interfaces.<name>.wakeOnLan.enable`, `networking.networkmanager.unmanaged`, `networking.bridges`
- WireGuard quickstart: <https://www.wireguard.com/quickstart/>
- Tailscale KB: <https://tailscale.com/kb> — MagicDNS + `--accept-dns`
- Mullvad CLI reference: <https://mullvad.net/help/using-mullvad-vpn/linux/) — `exclude` vs `split-tunnel` naming per release
- nftables wiki: <https://wiki.nftables.org/>
- systemd-resolved docs: `man resolved.conf` — `Domains=` split-DNS
- nixpkgs module sources: `services/networking/{wg-quick,wireguard,tailscale,mullvad-vpn}.nix`
- Companions: `Secrets-Management-NixOS.md` (key files), `Self-Hosting-NixOS.md` (reverse-proxy networking), `Hardening-NixOS.md` §13–15
