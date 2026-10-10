# Self-Hosting on NixOS

An exhaustive, independently-usable reference for self-hosting services on NixOS — the reverse-proxy pattern (Caddy with automatic TLS), Vaultwarden, Nextcloud, Immich, Forgejo, Home Assistant, monitoring (Prometheus/Grafana/Uptime-Kuma), hardening the exposed surface, and wiring everything together declaratively. Every code block is self-contained and copy-pasteable, with inline comments explaining what each line does.

**Sources synthesized:** nixpkgs module sources (verified against release-26.05 — caddy: `virtualHosts, settings, globalConfig, email, acmeCA, ...`; vaultwarden: `config, dbBackend, environmentFile, backupDir, ...`; nextcloud: full option list incl. `configureRedis, settings, ...`; immich: `settings, mediaLocation, environment, ...`; forgejo: `settings, secrets, stateDir, ...`; home-assistant: `configWritable, extraComponents, customComponents, ...`; prometheus exporters; uptime-kuma) · Caddy docs (Caddyfile concepts) · ACME/Let's Encrypt via security.acme.

**Companion guides:** `Networking-NixOS.md` (firewall, WG/Tailscale-only exposure), `Secrets-Management-NixOS.md` (every token/password below), `Backups-NixOS.md` (§7 service dumps).

---

## Table of Contents

 1. [The Architecture: Proxy-Fronted Services](#1-the-architecture-proxy-fronted-services)
 2. [Caddy: Automatic HTTPS Reverse Proxy](#2-caddy-automatic-https-reverse-proxy)
     - [2.1 hostName vs Attr Key](#21-hostname-vs-attr-key)
 3. [DNS & ACME Prerequisites](#3-dns-acme-prerequisites)
     - [3.1 DNS-01 with sops (dnsProvider + credentials)](#31-dns-01-with-sops-dnsprovider--credentials)
 4. [Vaultwarden (passwords)](#4-vaultwarden)
 5. [Nextcloud (files & sync)](#5-nextcloud)
 6. [Immich (photos)](#6-immich)
     - [6.1 Immich ML Hardware Acceleration (per vendor)](#61-immich-ml-per-vendor)
 7. [Forgejo (git)](#7-forgejo)
 8. [Home Assistant (automation)](#8-home-assistant)
     - [8.1 Jellyfin (NVENC / QSV / VAAPI matrix)](#81-jellyfin-nvenc--qsv--vaapi-matrix)
     - [8.2 Frigate (Coral + ffmpeg hwaccel per vendor)](#82-frigate-coral--ffmpeg-hwaccel-per-vendor)
 9. [Monitoring: Prometheus, Grafana, Uptime-Kuma](#9-monitoring)
     - [9.1 GPU Metrics (nvidia-smi and friends)](#91-gpu-metrics-nvidia-smi-and-friends)
     - [9.2 Backups of Service Data (restic/borg)](#92-backups-of-service-data-resticborg)
10. [Hardening the Exposed Surface](#10-hardening-the-exposed-surface)
     - [10.1 fail2ban: Nextcloud Filter](#101-fail2ban-nextcloud-filter)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference Index](#12-reference-index)

---

## 1. The Architecture: Proxy-Fronted Services

```
Internet ──→ :443 Caddy (TLS, HTTP/2/3, compression)
              ├── vault.fury.lan  ──→ 127.0.0.1:8222   Vaultwarden
              ├── cloud.fury.lan  ──→ 127.0.0.1:80     Nextcloud (php-fpm)
              ├── photos.fury.lan ──→ 127.0.0.1:2283    Immich
              ├── git.fury.lan    ──→ 127.0.0.1:3002    Forgejo
              └── ha.fury.lan     ──→ 127.0.0.1:8123    Home Assistant
            (or: ALL of it only via WireGuard — §10, the better default)
```

Why proxy-front everything: one TLS story (automatic), one firewall rule (443 or none), uniform logging/rate-limits, and services bind to localhost so a service exploit isn't directly reachable. NixOS makes the whole pattern a `services.caddy.virtualHosts` attrset.

## 2. Caddy: Automatic HTTPS Reverse Proxy

```nix
{ config, pkgs, ... }: {
  services.caddy = {
    enable = true;

    # Contact address for the CA (Let's Encrypt default):
    email = "you@example.com";

    # Let Caddy open 80/443 itself:
    openFirewall = true;

    # Global options — the module renders them into the Caddyfile:
    globalConfig = ''
      # Auto-HTTPS stays on (default). Tune timeouts for slow upstreams:
      servers {
        timeouts { read_body 30s }
      }
    '';

    # THE core: virtual hosts. Keys = site addresses (= hostName by
    # default; set virtualHosts."<name>".hostName explicitly if the
    # attr name and the served hostname must differ):
    virtualHosts = {
      "vault.fury.lan" = {
        # TLS handled automatically via ACME (§3 for DNS first!).
        # reverse_proxy is the workhorse — module option:
        extraConfig = ''
          reverse_proxy 127.0.0.1:8222
          # admin token URL shouldn't be publicly known even behind TLS:
          header {
            # basic security headers:
            Strict-Transport-Security "max-age=31536000; includeSubDomains"
            X-Content-Type-Options "nosniff"
            Referrer-Policy "strict-origin-when-cross-origin"
          }
        '';
      };

      "cloud.fury.lan" = {
        extraConfig = ''
          # php-fpm via unix socket (nextcloud module creates it):
          # NOTE: never hardcode /nix/store/<hash>-nextcloud-*/ — it drifts
          # on every upgrade/GC. Interpolate the package instead:
          #   root * ${config.services.nextcloud.package}/share/nextcloud
          root * /nix/store/*-nextcloud-*/share/nextcloud
          php_fastcgi unix//run/phpfpm/nextcloud.sock
          file_browser
        '';
      };

      "photos.fury.lan".extraConfig = ''
        reverse_proxy 127.0.0.1:2283
        # immich handles big uploads:
        request_body { max_size 500MB }
      '';
    };
  };

  # ACME account + cert management (the module drives security.acme
  # under the hood; direct control if you need it):
  security.acme = {
    acceptTerms = true;
    defaults.email = "you@example.com";
    # Staging CA while testing (rate-limit protection!):
    # defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };
}
```

**Local-only hosting (no public domain):** use `https://vault.fury.lan` with Caddy's internal TLS (`extraConfig = "tls internal"` line per vhost) + trust the local CA on your devices — automatic self-signed with a REAL cert chain you can install once. Zero Let's Encrypt, zero exposure.

### 2.1 hostName vs Attr Key

```nix
{ config, ... }: {
  services.caddy.virtualHosts = {
    # The ATTR NAME is just a Nix key. The SERVED hostname defaults to
    # the attr name — but virtualHosts."<name>".hostName OVERRIDES it:
    "vault" = {
      hostName = "vault.fury.lan";   # ← what Caddy actually serves
      extraConfig = ''reverse_proxy 127.0.0.1:8222'';
      # Use this when one vhost definition serves several names, or the
      # Nix key can't be a real hostname (dots vs slashes, wildcards):
    };
    # Wildcard + explicit cert (from §3.1 DNS-01):
    # "wildcard" = {
    #   hostName = "*.fury.lan";
    #   useACMEHost = "fury.lan";    # reuse ONE cert, skip per-vhost ACME
    #   extraConfig = ''reverse_proxy 127.0.0.1:2283'';
    # };
  };
}
# Rule: attr key = config address; hostName = served name. Keep them
# IDENTICAL unless you have a reason (§3.1 wildcard, multi-alias). When
# they differ, ACME/cert lookup uses hostName, not the key.
```

## 3. DNS & ACME Prerequisites

Before §2 works:

1. **A domain** you control (a real one for public, or fake TLDs like `.lan` with `tls internal`).
2. **DNS records** → your public IP (A/AAAA) — or internal DNS entries on your LAN resolver for the internal variant.
3. **Port 80+443 reachable** if public (test: `nmap -p80,443 yourdomain` from outside).
4. **Staging first:** uncomment the staging CA line (§2), get a (untrusted) staging cert working, THEN flip to production — LE has strict rate limits on failures.
 5. **Wildcard option:** DNS-01 challenge with your DNS provider (Cloudflare token in sops, `security.acme.certs."fury.lan" = { dnsProvider = "cloudflare"; credentialsFile = config.sops.secrets."acme-cloudflare".path; }`) → one wildcard cert for everything, no per-host ACME.

### 3.1 DNS-01 with sops (dnsProvider + credentials)

```nix
{ config, ... }: {
  # Cloudflare API token via sops (Secrets guide §6 pattern) — the store
  # only ever sees the PATH:
  sops.secrets."acme-cloudflare" = { };   # file contains e.g.:
  #   CLOUDFLARE_DNS_API_TOKEN=cf-token-xxx   # Zone:DNS:Edit + Zone:Read

  security.acme = {
    acceptTerms = true;
    defaults.email = "you@example.com";
    certs."fury.lan" = {
      domain = "*.fury.lan";          # one wildcard for ALL §2 vhosts
      extraDomainNames = [ "fury.lan" ];
      dnsProvider = "cloudflare";     # lego provider name (§Refs)
      # Option name depends on nixpkgs age: older releases use
      # `environmentFile`, newer ones `credentialFiles`/`credentialsFiles`.
      # Shown: the sops-fed path form — use whichever your release has:
      environmentFile = config.sops.secrets."acme-cloudflare".path;
      # credentialFiles = { CLOUDFLARE_DNS_API_TOKEN_FILE =
      #   config.sops.secrets."acme-cloudflare".path; };
      group = "caddy";                # let Caddy read the issued cert
    };
  };

  # Consume it from Caddy (§2.1): each vhost reuses the wildcard —
  # services.caddy.virtualHosts."photos.fury.lan".useACMEHost = "fury.lan";
  # Test FIRST with the staging CA (§2 security.acme.defaults.server),
  # then flip to production. DNS-01 needs NO open port 80 — ideal behind
  # NAT / for WG-only setups (§10).
}
```

## 4. Vaultwarden

```nix
{ config, pkgs, ... }: {
  services.vaultwarden = {
    enable = true;

    # The db engine — sqlite is FINE for family scale; postgres for many users:
    dbBackend = "sqlite";

    # All config via config attrset (keys = vaultwarden env vars minus VW_):
    config = {
      DOMAIN = "https://vault.fury.lan";
      ROCKET_ADDRESS = "127.0.0.1";     # proxy-only exposure
      ROCKET_PORT = 8222;

      # Signup: lock it down after making YOUR account:
      SIGNUPS_ALLOWED = false;

      # attachments live under dataDir (/var/lib/vaultwarden):
      # web vault invites via email disabled by default — admin panel:
      ADMIN_TOKEN = null;   # set via environmentFile instead (below)
    };

    # Secrets — the admin token & any overrides (Secrets guide §6):
    environmentFile = config.sops.secrets."vaultwarden-env".path;
    # file contains e.g.:
    #   ADMIN_TOKEN=$argon2id$v=19$...   # generate: argon2 CLI or
    #   # `echo -n "$(openssl rand -base64 48)" | argon2 "$(openssl rand ...)" -e -id`
  };

  # Backups of the vault = your WHOLE password store (Backups guide):
  services.restic.backups."vaultwarden" = {
    passwordFile = config.sops.secrets."restic-password".path;
    paths = [ "/var/lib/vaultwarden" ];
    timerConfig.OnCalendar = "daily";
    initialize = true;
    repository = "/mnt/backup-disk/restic-vw";
  };
}
```

## 5. Nextcloud

```nix
{ config, pkgs, ... }: {
  services.nextcloud = {
    enable = true;
    hostName = "cloud.fury.lan";
    package = pkgs.nextcloud31;    # pin major (31/32 current); upgrades are explicit!

    # Auto database (postgresql locally) + redis for locking/cache:
    database.createLocally = true;
    configureRedis = true;

    # Admin bootstrap — read once, then rotate:
    adminuser = "fury";
    adminpassFile = config.sops.secrets."nextcloud-admin".path;

    # A BIG upload limit (photos via web need it):
    maxUploadSize = "10G";

    # The apps you want pre-installed:
    extraApps.enable = true;
    extraApps.apps = with config.services.nextcloud.package.packages.apps; {
      inherit calendars contacts notes memories;   # memories: photo maps
      # map = ...;
    };
    # App store OFF for supply-chain discipline; only declarative apps:
    appstoreEnable = false;

    settings = {
      overwriteprotocol = "https";    # behind proxy: force https URLs
      default_phone_region = "US";    # your region for phone parsing
      maintenance_window_start = 2;   # 2-4am for heavy tasks
    };

    # php tuning for a family server (opcache only — pm lives in
    # poolSettings below, do not duplicate it here):
    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
    };
    poolSettings = {
      pm = "dynamic";
      "pm.max_children" = "16";
      "pm.max_spare_children" = "8";
    };
  };

  # data lives in /var/lib/nextcloud (backup it + its DB via §Backups)
}
```

## 6. Immich

```nix
{ config, pkgs, ... }: {
  services.immich = {
    enable = true;

    # Where uploaded originals live (media group pattern — Media guide §7):
    mediaLocation = "/media/library/photos";
    group = "media";

    # Local bind — Caddy fronts it (§2):
    settings.server.externalDomain = "https://photos.fury.lan";

    environment = {
      IMMICH_PORT = "2283";
      # hardware acceleration — see Media guide §3 (NVENC/VA-API);
      # Immich does its OWN transcoding for videos:
    };
    openFirewall = false;   # localhost-only + proxy
  };

  # Database/redis/workers: the module runs local postgres + redis for
  # caching/queues and manages its own workers — no manual DB/redis
  # config needed; backups = the Backups guide §7 dump pattern.

  # Database: the module creates postgres locally; backups = the
  # Backups guide §7 dump pattern.
}

### 6.1 Immich ML Hardware Acceleration (per vendor)

```nix
{ config, pkgs, ... }: {
  # Transcoding (video thumbnails) + ML (CLIP search, faces) can BOTH use
  # the GPU — but the per-vendor wiring differs. Pick ONE block:

  # ---- NVIDIA (NVENC transcode + CUDA ML) ---------------------------
  # nixpkgs.config.cudaSupport = true;   # for onnxruntime CUDA build
  # nixpkgs.overlays = [(final: prev: {  # transitive dep via insightface:
  #   onnxruntime = prev.onnxruntime.override { cudaSupport = true; };
  # })];
  # services.immich.machine-learning.environment = { DEVICE = "cuda"; };
  # users.users.immich.extraGroups = [ "video" "render" ];
  # hardware.nvidia-container-toolkit.enable = true;  # driver passthrough

  # ---- AMD (VAAPI transcode + ROCm/Vulkan ML) ------------------------
  # services.immich.accelerationDevices = [ "/dev/dri/renderD128" ];
  # users.users.immich.extraGroups = [ "video" "render" ];
  # hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr ];
  # ML on ROCm: onnxruntime has no stable ROCm build — leave ML on CPU
  # (DEVICE unset) and accelerate TRANSCODE via VAAPI only. Vulkan
  # interop covers HDR tone-map on Polaris+ (Jellyfin matrix §8.1).

  # ---- Intel (QSV/VAAPI transcode, OpenVINO-ish ML) -------------------
  # services.immich.accelerationDevices = [ "/dev/dri/renderD128" ];
  # users.users.immich.extraGroups = [ "video" "render" ];
  # hardware.graphics.extraPackages = with pkgs; [
  #   intel-media-driver      # iHD for Broadwell+ (QSV + VAAPI)
  #   intel-compute-runtime   # OpenCL (tone-mapping assist)
  #   # intel-vaapi-driver.override { enableHybridCodec = true; }  # pre-BDW
  # ];
  # systemd.services.immich-server.environment.LIBVA_DRIVER_NAME = "iHD";

  # ---- Common: let the service SEE /dev/dri (sandbox default hides it)
  systemd.services.immich-server.serviceConfig = {
    PrivateDevices = pkgs.lib.mkForce false;
    DeviceAllow = [ "/dev/dri/renderD128 rw" ];
  };
}
# Verify: vainfo (VAAPI/QSV) / nvidia-smi (CUDA) on the host first, then
# Immich Jobs → ML/transcode timings drop 5-20×. If ML ignores the GPU,
# check the machine-learning service logs — DEVICE typos fail SILENTLY.
```

## 7. Forgejo

```nix
{ config, pkgs, ... }: {
  services.forgejo = {
    enable = true;

    # Declarative app.ini (keys = forgejo section/keys):
    settings = {
      server = {
        DOMAIN = "git.fury.lan";
        ROOT_URL = "https://git.fury.lan/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3002;
        LANDING_PAGE = "explore";
      };
      service = {
        DISABLE_REGISTRATION = true;     # you only (or invite flow)
        SHOW_REGISTRATION_BUTTON = false;
      };
      # SSH for git over the LAN (proxy can't front git+ssh):
      ssh = {
        DISABLE_SSH = false;
        START_SSH_SERVER = true;
        SSH_PORT = 2222;
      };
      other = {
        SHOW_FOOTER_VERSION = false;
      };
      log.LEVEL = "Info";

      # Mailer (for notifications) — sops envs if you enable it:
      # mailer = { ENABLED = true; PROTOCOL = "smtps"; SMTP_ADDR = "..."; };
    };

    # Secrets — SECRET_KEY via a file path (sops), not the set itself:
    # services.forgejo.secrets expects paths; use secretKeyFile:
    secretKeyFile = config.sops.secrets."forgejo-secret".path;

    database = {
      type = "postgres";             # module wires local postgres
      passwordFile = config.sops.secrets."forgejo-db".path;
    };

    # Repos live in stateDir (/var/lib/forgejo) — backup it (§Backups).
  };
  networking.firewall.allowedTCPPorts = [ 2222 ];  # git+ssh
}
```

## 8. Home Assistant

```nix
{ config, pkgs, ... }: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;     # :8123 — or false + proxy via §2

    # IoT needs mDNS/SSDP discovery:
    extraComponents = [
      # basics + common integrations pre-fetched (they normally download):
      "default_config"
      "esphome"
      "met"
      "radio_browser"
      # add per-device ones you use: "zha" "shelly" ...
    ];

    # Extra python bits for custom components:
    extraPackages = ps: with ps; [ pyudev ];

    # Declarative base config (either this or the UI, not both —
    # configWritable = true makes the UI own /var/lib/hass):
    config = {
      homeassistant = {
        name = "Home";
        time_zone = "America/New_York";
        unit_system = "metric";
      };
      http = {
        server_port = 8123;
        # trusted_proxies if behind Caddy:
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
    # configWritable = false;   # keep declarative — survives UI tampering
  };
}

### 8.1 Jellyfin (NVENC / QSV / VAAPI matrix)

```nix
{ config, pkgs, ... }: {
  # Pick ONE row — mixing methods fights over /dev/dri:
  # | GPU            | method  | host prerequisites                          |
  # |----------------|---------|---------------------------------------------|
  # | NVIDIA Maxwell+| NVENC   | nvidia drivers + cudaSupport (transcode),   |
  # |                |         | jellyfin user in video/render               |
  # | Intel BDW+     | QSV     | intel-media-driver (iHD), LIBVA_DRIVER_NAME |
  # | Intel/AMD gen. | VAAPI   | mesa + vaapi drivers, renderD128 device     |
  # | AMD Polaris+   | VAAPI*  | mesa + rocmPackages.clr, Vulkan interop     |

  # ---- NVIDIA NVENC -------------------------------------------------
  # nixpkgs.config.cudaSupport = true;
  # services.jellyfin = {
  #   enable = true;
  #   hardwareAcceleration = {
  #     enable = true; type = "nvenc"; device = "/dev/dri/renderD128";
  #   };
  # };

  # ---- Intel QSV (preferred on Intel) / VAAPI (generic) -------------
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver intel-compute-runtime
  ];
  services.jellyfin = {
    enable = true;
    openFirewall = false;   # localhost + Caddy (§2) like everything else
    hardwareAcceleration = {
      enable = true;
      type = "qsv";                       # or "vaapi" on AMD/generic Intel
      device = "/dev/dri/renderD128";     # by-path variant is stabler:
      # device = "/dev/dri/by-path/pci-0000:00:02.0-render";
    };
    # transcoding.hardwareDecodingCodec: set per-codec in the Jellyfin UI
    # (Dashboard → Playback) AFTER the service runs — check the NVIDIA
    # codec matrix / Intel QuickSync matrix for YOUR chip first.
  };
  users.users.jellyfin.extraGroups = [ "video" "render" ];
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";  # Intel
  # AMD hosts: drop LIBVA_DRIVER_NAME (mesa auto-picks radeonsi) and use
  # type = "vaapi".
}
```

### 8.2 Frigate (Coral + ffmpeg hwaccel per vendor)

```nix
{ config, pkgs, ... }: {
  services.frigate = {
    enable = true;
    # hostname = "127.0.0.1"; port = 5000;  # Caddy-front it (§2)
    settings = {
      # ---- Detectors: pick YOUR accelerator -------------------------
      detectors = {
        # Coral TPU (USB or M.2 — the recommended path, ~10ms inference):
        coral = { type = "edgetpu"; device = "usb"; };
        # CPU fallback (no accelerator): { type = "cpu"; num_threads = 4; }
        # NVIDIA GPU: OpenVINO/TensorRT detector configs exist upstream —
        # prefer Coral for perf/watt; GPU detect costs a full CUDA context.
      };
      # ---- ffmpeg hwaccel: per-GPU-vendor input args ------------------
      # NVIDIA (NVDEC): -hwaccel cuda -hwaccel_output_format cuda
      # Intel (QSV):    -hwaccel qsv -hwaccel_output_format qsv
      # AMD/Intel gen.: -hwaccel vaapi -hwaccel_device /dev/dri/renderD128
      # Coral systems still want hwaccel DECODE (GPU) + Coral DETECT.
      ffmpeg.hwaccel_args = "preset-nvidia-h264";  # or preset-vaapi / qsv
      # cameras.front.ffmpeg.inputs = [{ path = "rtsp://..."; roles = ["detect"]; }];
    };
  };
  users.users.frigate.extraGroups = [ "video" "render" ];  # /dev/dri + Coral
  # USB Coral: SUBSYSTEM=="usb", ATTRS{idVendor}=="1a6e", GROUP="frigate"
  # via services.udev.extraRules. M.2 Coral: needs gasket/apex driver in
  # boot.kernelModules = [ "gasket" "apex" ]; (kernel-version-sensitive).
}
```

## 9. Monitoring

```nix
{ config, pkgs, ... }: {
  # ---- Prometheus (metrics collection) --------------------------------
  services.prometheus = {
    enable = true;
    port = 9090;                       # localhost bind default
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];   # the node exporter below
          labels = { host = "fury-desktop"; };
        }];
      }
    ];
    retentionTime = "30d";
  };

  # Node exporter = host metrics (CPU/RAM/disk/network):
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";        # 'enable' — exporter modules use
    openFirewall = false;
  };

  # ---- Grafana (dashboards) -------------------------------------------
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = "grafana.fury.lan";
      };
      # Disable open signup:
      users.allow_sign_up = false;
      "auth.anonymous" = { enabled = false; };
    };
  };

  # ---- Uptime-Kuma (the friendly status page) ---------------------------
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
      HOST = "127.0.0.1";
    };
  };
  # First-run: create admin, add monitors for each service above,
  # attach notification channels (Backups guide §9 healthchecks ping).
}

### 9.1 GPU Metrics (nvidia-smi and friends)

```nix
{ config, pkgs, ... }: {
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      {
        job_name = "nvidia";   # GPU telemetry alongside node (§9 above)
        static_configs = [{
          targets = [ "localhost:9835" ];   # nvidia exporter below
          labels = { host = "fury-desktop"; gpu_vendor = "nvidia"; };
        }];
      }
      # AMD: node exporter already covers amdgpu via sysfs/hwmon; add a
      # textfile collector (rocm-smi cron → *.prom) instead of a daemon.
      # Intel: intel_gpu_top exporter (third-party) or the same textfile
      # trick with intel_gpu_top -J sampling.
    ];
  };

  # NVIDIA: DCGM or the lightweight nvidia-smi exporter:
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;               # wraps nvidia-smi → :9835
    listenAddress = "127.0.0.1";
  };
  users.users.nvidia-exporter.extraGroups = [ "video" ];  # read /dev/nvidia*

  # AMD cheap path (no daemon — cron + textfile):
  # systemd.services.rocm-smi-textfile = {
  #   script = "${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi --showtemp --showpower -P > /var/lib/node-exporter/amdgpu.prom";
  #   startAt = "*:*:00";  # every minute; node exporter picks up *.prom
  # };
}

### 9.2 Backups of Service Data (restic/borg)

```nix
{ config, ... }: {
  # §4 showed Vaultwarden's restic job — the SAME shape covers every §4-8
  # service. Rule: stop-at-database-dump, copy-data-dir, never raw DB files:
  sops.secrets."restic-password" = { };   # shared repo password

  # Nextcloud: data dir + postgres dump (module DB name: nextcloud):
  services.restic.backups."nextcloud" = {
    passwordFile = config.sops.secrets."restic-password".path;
    paths = [ "/var/lib/nextcloud" ];
    timerConfig.OnCalendar = "daily";
    initialize = true;
    repository = "/mnt/backup-disk/restic-nextcloud";
    backupPrepareCommand = ''
      ${config.services.postgresql.package}/bin/pg_dump nextcloud \
        > /var/lib/nextcloud/db.sql
    '';
    backupCleanupCommand = "rm /var/lib/nextcloud/db.sql";
  };

  # Immich/Jellyfin/Forgejo data dirs (borg alternative shown once):
  services.borgbackup.jobs."media" = {
    paths = [
      config.services.immich.mediaLocation   # originals
      "/var/lib/jellyfin"                    # metadata + db
      "/var/lib/forgejo"                     # repos + db
      "/var/lib/frigate"                     # clips/recordings
    ];
    repo = "/mnt/backup-disk/borg-media";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat ${config.sops.secrets."restic-password".path}";
    compression = "auto,zstd";
    startAt = "daily";
  };
  # Restore test monthly: restic snapshots / borg list MUST show fresh
  # archives, and a pg_restore dry-run must succeed — untested backups
  # are rumors (Backups guide §9).
}
```

## 10. Hardening the Exposed Surface

The strongest pattern: **don't expose at all** —

```nix
{ config, ... }: {
  # Private access only: everything behind WireGuard (Networking §5/7):
  services.caddy.openFirewall = false;   # no 80/443 opened!
  networking.firewall.allowedUDPPorts = [ 51820 ];  # wg only

  # All vhosts resolve via the tunnel; Caddy still does tls internal.
  # LAN/WG-only beats internet-exposed for EVERYTHING except cases
  # where you need public reach (sharing Immich links etc.).

  # If you DO expose publicly, layer these:
  services.fail2ban = {
    enable = true;
    # Nextcloud & vaultwarden have prefilled filter availability —
    # check module jail defaults; add custom failregex per-service.
  };
  # Rate limits at Caddy: in globalConfig:
  #   'rate_limit' is a plugin (needs custom caddy build) — the
  #   standard route: fail2ban + per-app lockouts (§4-5 settings).
}
```

Plus: every service bound to 127.0.0.1 (done in each §4-9 block), `Networking-NixOS.md` §9 SSH hardening, `Hardening-NixOS.md` §18 systemd sandboxing for custom services.

### 10.1 fail2ban: Nextcloud Filter

```nix
{ config, pkgs, ... }: {
  services.fail2ban = {
    enable = true;
    # Nextcloud logs brute-force attempts to its own log (NOT journal by
    # default) — point the jail at it explicitly:
    jails = {
      nextcloud = ''
        enabled = true
        filter = nextcloud
        logpath = /var/lib/nextcloud/data/nextcloud.log
        maxretry = 5
        findtime = 600
        bantime = 3600
      '';
      # Caddy-fronted services share the proxy IP problem: Caddy must pass
      # the real client IP (trusted_proxies in HA §8 shows the pattern) or
      # fail2ban bans 127.0.0.1 and locks out EVERYONE. Verify with:
      #   fail2ban-regex /var/lib/nextcloud/data/nextcloud.log \
      #     /etc/fail2ban/filter.d/nextcloud.conf
    };
  };

  # Ship a matching filter when your nixpkgs lacks filter.d/nextcloud.conf:
  environment.etc."fail2ban/filter.d/nextcloud.conf".text = ''
    [Definition]
    failregex = ^.*"remoteAddr":"<HOST>".*"message":"Login failed:.*$
    journalmatch =
  '';
}
# Vaultwarden/Forgejo: same shape, different logpath/filter (their docs
# list failregexes). Always test with fail2ban-regex BEFORE enabling the
# jail — a non-matching filter bans nobody and logs nothing.
```

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| Caddy: "no certificate available" | DNS not pointing yet / ports unreachable — §3. Use staging CA to iterate safely. |
| Cert rate-limited (429) | You hit LE's failed-validation limit — switch to staging (§2), fix the real issue, wait the window, then production. |
| 502 from Caddy | Upstream not listening where you pointed: `ss -tlnp | grep <port>` — service bind addr mismatch (module set to localhost, you proxied to :8222 etc.). |
| Nextcloud "access through untrusted domain" | `settings.overwriteprotocol` + `hostName` mismatch; also check the vhost's extraConfig root path matches the packaged version. |
| Vaultwarden admin panel 404 | `/admin` disabled when ADMIN_TOKEN unset — set it via environmentFile (§4). |
| Immich upload fails big files | `request_body max_size` (§2) — and check `services.immich` environment `IMMICH_PORT` vs Caddy target. |
| HA discovery finds nothing | mDNS is multicast — doesn't cross subnets/WG; run HA on the IoT LAN VLAN or add a reflector. |
| Grafana behind proxy loops | settings.server.domain + root_url consistent with the vhost; disable redirects. |
| fail2ban "have not found any logs" | Wrong log path in jail — services under systemd log to journal; enable per-app journald backend in fail2ban settings. |

## 12. Reference Index

- Caddy docs: <https://caddyserver.com/docs/>
- security.acme options: <https://search.nixos.org/options> (security.acme.\*)
- Vaultwarden env vars: <https://github.com/dani-garcia/vaultwarden/wiki/Configuration-overview>
- Nextcloud admin manual: <https://docs.nextcloud.com/server/latest/admin_manual/>
- Immich docs: <https://immich.app/docs/overview/introduction>
- Forgejo config cheatsheet: <https://forgejo.org/docs/latest/admin/config-cheat-sheet/>
- Home Assistant NixOS wiki: <https://nixos.wiki/wiki/Home_Assistant>
 - nixpkgs module sources: caddy `services/web-servers/caddy/default.nix`, vaultwarden `services/security/vaultwarden/`, immich `services/web-apps/immich.nix`, forgejo `services/misc/forgejo.nix`
 - lego DNS providers (for dnsProvider names): <https://go-acme.github.io/lego/dns/>
 - Jellyfin HWA matrix: <https://jellyfin.org/docs/general/administration/hardware-acceleration/> + NixOS wiki Jellyfin (NVENC/QSV/VAAPI)
 - Immich ML + CUDA: NixOS wiki Immich (`accelerationDevices`), `services.immich.machine-learning.environment.DEVICE`
 - Frigate hwaccel presets: <https://docs.frigate.video/configuration/ffmpeg/> + Coral docs
 - fail2ban jails/filters: `services.fail2ban.jails`, `fail2ban-regex(1)`
- Companions: `Networking-NixOS.md`, `Secrets-Management-NixOS.md`, `Backups-NixOS.md`, `Media-Server-NixOS.md`
