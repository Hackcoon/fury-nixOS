# Backups on NixOS

An exhaustive, independently-usable reference for backups on NixOS — restic and borgbackup (the two declarative NixOS modules), snapshot-based protection (btrfs/snapper), the 3-2-1 strategy, offsite with rclone/B2, and the part everyone skips: tested restores. Every code block is self-contained and copy-pasteable, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual (services.restic, services.borgbackup) · restic docs (backends, forget/prune, caches) · BorgBackup docs (repos, quotas, per-host keys) · borgbackup module source (for `patterns`/`startAt` semantics) · 3-2-1 backup strategy (US-CERT formulation). Schema verified against nixpkgs release-26.05 (options lists extracted from module sources: restic — `repository, repositoryFile, passwordFile, paths, exclude, pruneOpts, timerConfig, ...`; borgbackup — `repo, paths, patterns, startAt, compression, environment, ...`).

**Companion guides:** `Troubleshooting-Recovery-NixOS.md` (restores gone wrong), `Secrets-Management-NixOS.md` (repo passwords/keys are secrets!).

---

## Table of Contents

1. [Strategy First: What, Where, How Often](#1-strategy-first-what-where-how-often)
2. [The NixOS Truth: What Even Needs Backing Up](#2-the-nixos-truth-what-even-needs-backing-up)
3. [restic — The Modern Default](#3-restic-the-modern-default)
4. [borgbackup — The Server-Grade Classic](#4-borgbackup-the-server-grade-classic)
5. [Snapshots ≠ Backups (btrfs + snapper)](#5-snapshots-backups-btrfs-snapper)
6. [Offsite: rclone, Backblaze B2, S3](#6-offsite-rclone-backblaze-b2-s3)
7. [Service Dumps Before Backup (DBs, VMs)](#7-service-dumps-before-backup)
8. [Testing Restores (the part that matters)](#8-testing-restores-the-part-that-matters)
9. [Monitoring & Alerts](#9-monitoring-alerts)
10. [Troubleshooting](#10-troubleshooting)
11. [Deep Cuts: forget vs prune, repositoryFile, btrfs send, multi-host](#11-deep-cuts-forget-vs-prune-repositoryfile-btrfs-send-multi-host)
12. [Reference Index](#12-reference-index)

---

## 1. Strategy First: What, Where, How Often

| Rule | Meaning | This guide's coverage |
|---|---|---|
| **3-2-1** | 3 copies, 2 different media, 1 offsite | local restic + offsite §6 |
| **RPO** (recovery point) | How much data loss is acceptable? | sets your `startAt` timer |
| **RTO** (recovery time) | How long until you're back? | sets your restore drill cadence §8 |
| **The backup you never tested is a hope, not a backup** | — | §8, mandatory |

**Backup the data, not the system.** NixOS already "backs up" the system declaratively: your flake in git IS the system backup (plus `/etc/nixos` + `/etc/secureboot` per your setup). What needs real backups: `/home`, service state (`/var/lib/<svc>`), secrets (via sops — encrypted already), and any data that would hurt to lose.

## 2. The NixOS Truth: What Even Needs Backing Up

```bash
# The inventory exercise — 10 minutes, do it once, revisit yearly:
du -sh /var/lib/* 2>/dev/null | sort -h | tail -15   # service state
du -sh /home/fury/* 2>/dev/null | sort -h | tail -15 # user data

# What's already declarative (skip!): everything derivable from your
# flake. What's stateful (backup!):
#   /home/fury          ← documents, configs, keys, browser profiles
#   /var/lib/libvirt    ← VM images (Virtualization guide) — big! (see §7)
#   /etc/nixos          ← your flake (also in git, but belt+suspenders)
#   /etc/secureboot     ← SB keys (Hardening §22) — IRREPLACEABLE
#   /var/lib/sops-nix   ← if using host keys rather than user keys
```

## 3. restic — The Modern Default

Restic: deduplicating, encrypting, snapshotting, verifiable. One tool, many backends.

### 3.1 The core service (local disk / NAS)

```nix
{ config, pkgs, ... }: {
  services.restic.backups = {
    # The attrset name is arbitrary — used in systemd unit names:
    "fury-local" = {
      # ---- Destination --------------------------------------------------
      # Any restic backend syntax works. Local path:
      repository = "/mnt/backup-disk/restic-fury";

      # The repo password — from sops (Secrets guide §6 — it's a secret!):
      passwordFile = config.sops.secrets."restic-password".path;

      # ---- Source selection ---------------------------------------------
      paths = [
        "/home/fury"
        "/etc/nixos"
        "/etc/secureboot"
        "/var/lib/sops-nix"
      ];

      # Exclude the noise (doubles dedupe ratios and speeds runs):
      exclude = [
        "*.tmp"
        # Browser caches — huge, worthless, restorable by re-download:
        "/home/fury/.cache"
        "*/Cache"
        "*/cache"
        # VM images churn massively; snapshot them separately (§7):
        "/var/lib/libvirt/images"
        # Trash & venvs (reconstructible):
        "/home/fury/.local/share/Trash"
        "*/node_modules"
        "*/.venv"
        "*/target"           # rust builds
      ];

      # ---- Schedule & retention ----------------------------------------
      # A systemd timer — any OnCalendar expression:
      timerConfig = {
        OnCalendar = "daily";              # 02:00-ish; see man systemd.time
        Persistent = true;                 # catch up if machine was off
        RandomizedDelaySec = "30m";        # avoid thundering-herd on NAS
      };

      # Initialize the repo on first run (idempotent, safe):
      initialize = true;

      # Prune policy — keep what a HUMAN would want back:
      pruneOpts = [
        "--keep-daily 7"       # last 7 days
        "--keep-weekly 5"      # one per week for 5 weeks
        "--keep-monthly 12"    # one per month for a year
        "--keep-yearly 3"      # then 3 yearly archive points
      ];

      # Optional: verify repo integrity on each run (reads + checks packs):
      runCheck = true;
      checkOpts = [ "--read-data-subset=5%" ];   # spot-check 5% of packs/run

      # Hooks for §7 (database dumps etc.):
      backupPrepareCommand = "/run/current-system/sw/bin/backup-prepare";
      backupCleanupCommand = "/run/current-system/sw/bin/backup-cleanup";
    };
  };
}
```

### 3.2 How it works under you (worth knowing)

```bash
# The module creates: restic-backups-fury-local.service + .timer
systemctl list-timers | grep restic

# Manual run (before relying on the timer):
sudo systemctl start restic-backups-fury-local.service

# Inspect the repo directly:
sudo restic -r /mnt/backup-disk/restic-fury \
  --password-file /run/secrets/restic-password snapshots

# What changed in the last snapshot? (dedupe stats = sanity check):
sudo restic -r ... diff <snap1-id> <snap2-id>

# THE restore (§8 drills this):
sudo restic -r ... restore latest --target /tmp/restore-test
```

## 4. borgbackup — The Server-Grade Classic

Borg shines when: repo serves MANY machines (per-host names/appends), you want append-only repos (ransomware protection on the server), or you prefer per-repo quotas.

```nix
{ config, pkgs, ... }: {
  services.borgbackup.jobs = {
    "fury" = {
      # Repo path — no {hostname} placeholder (rejected by archiveBaseName type);
      # per-host naming comes from archiveBaseName default ($hostname-$job):
      repo = "ssh://backup@nas.lan/./repos/fury";

      # ---- What ----------------------------------------------------------
      paths = [ "/home/fury" "/etc/nixos" "/etc/secureboot" ];

      # ---- When ----------------------------------------------------------
      startAt = "daily";
      persistentTimer = true;        # catch-up if missed (like restic's)

      # ---- Retention & mechanics -----------------------------------------
      compression = "auto,zstd";    # modern, fast (auto = skip incompressible)
      # zstd < 19: faster; 19/lzma: smaller. zstd is the right default.

      dateFormat = "+%Y-%m-%dT%H:%M:%S";   # archive name suffix (leading + required by date)

      # Pruning — note: borg module prunes via a separate unit each run:
      prune = {
        keep = {
          within = "1d";              # everything from today
          daily = 7;
          weekly = 5;
          monthly = 12;
        };
      };

      # Passphrase — via encryption.passCommand (not BORG_PASSPHRASE_FILE,
      # which the module never reads — it sets BORG_PASSCOMMAND/BORG_PASSPHRASE):
      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      };

      # Environment — only non-passphrase vars here (SSH key):
      environment = {
        BORG_RSH = "ssh -i ${config.sops.secrets."borg-sshkey".path}";
      };
      # (read-only use; the module wires BORG_* env into the unit)

      # ---- Hooks --------------------------------------------------------
      # postHook runs via trap on EXIT with $exitStatus set, but prefer the
      # stable vars $archiveName / $repo (BORG_REPO) for notifications:
      preHook = "echo backup starting $(date)";
      postHook = ''
        echo "backup $archiveName to $repo finished with $exitStatus" | systemd-cat -t borgbackup || true
      '';
      appendFailedSuffix = true;    # JOB-level: failed archives get .failed suffix
    };
  };

  # ---- Being a borg SERVER (the NAS side) -----------------------------
  # NixOS can host repos for other machines with append-only protection:
  # allowSubRepos/quota are REPOS-level (server side); appendFailedSuffix
  # is JOB-level (moved to the job above):
  services.borgbackup.repos = {
    # per-remote-host repos with auto-append-only + quota:
    laptop = {
      path = "/var/lib/borgbackup/laptop";
      authorizedKeys = [ "ssh-ed25519 AAAA... laptop-key" ];  # from sops ideally
      allowSubRepos = true;
      quota = "100G";
    };
  };
}
```

## 5. Snapshots ≠ Backups (btrfs + snapper)

Snapshots protect against *logical* mistakes (rm -rf, bad update) instantly, but live on the SAME disk — they are not offsite, not even a second copy. Pair them:

```nix
{ config, pkgs, ... }: {
  # On a btrfs root (or btrfs data subvol):
  services.snapper = {
    snapshotInterval = "hourly";   # top-level systemd timer cadence (not per-config)
    cleanupInterval = "1d";        # top-level cleanup cadence
    configs = {
      "home" = {
        SUBVOLUME = "/home";
        FSTYPE = "btrfs";

        # Free-space-aware cleanup:
        FREE_SPACE_CHECK = "yes";

        # Retention via timeline + number cleanup:
        TIMELINE_CREATE = "yes";
        TIMELINE_LIMIT_HOURLY = "6";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "2";
        TIMELINE_LIMIT_MONTHLY = "1";
      };
      "root" = {
        SUBVOLUME = "/";
        FSTYPE = "btrfs";
        # Pre/post pacman-style snapshots around rebuilds:
        TIMELINE_CREATE = "no";
        NUMBER_LIMIT = 10;            # keep last 10 manual/number-cleanup snaps
      };
    };
  };
  # → snapper covers "oops" (seconds ago), restic covers "disaster" (offsite).
  # ZFS users: zfs-auto-snapshot equivalent; same philosophy.
}
```

## 6. Offsite: rclone, Backblaze B2, S3

The 1-offsite leg. restic speaks S3/B2 natively:

```nix
{ config, ... }: {
  services.restic.backups."fury-offsite" = {
    # Backblaze B2 (cheap, restic-friendly). Same sops discipline:
    repository = "b2:fury-backups:restic";
    # repositoryFile also exists if you rotate endpoints.

    passwordFile = config.sops.secrets."restic-password".path;
    environmentFile = config.sops.secrets."restic-b2-env".path;
    # ↑ file containing BOTH (B2 keys are secrets!):
    #   AWS_ACCESS_KEY_ID=keyId
    #   AWS_SECRET_ACCESS_KEY=masterKey
    # (restic's S3-clone env convention — the module injects it.)

    paths = [ "/home/fury" "/etc/nixos" ];
    exclude = [ "/home/fury/.cache" "*/node_modules" ];

    # Offsite runs can be lighter-touch than local:
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    pruneOpts = [ "--keep-monthly 12" "--keep-yearly 3" ];
    initialize = true;
  };
}
```

SFTP alternative: `repository = "sftp:backup@offsite:/repos/fury"` with an SSH key from sops — the BORG_RSH pattern from §4 applies to restic's sftp backend identically.

## 7. Service Dumps Before Backup

Cold backups of RUNNING databases can be torn/inconsistent. The prepare-hook pattern:

```nix
{ config, pkgs, ... }: {
  services.restic.backups."fury-local" = {
    # ... §3.1 config ...
    backupPrepareCommand = ''
      # Runs as root before paths are read.
      # --- PostgreSQL: consistent dump, WAL-safe -------------------------
      ${pkgs.postgresql}/bin/pg_dumpall -U postgres \
        > /var/backups/pg-all.sql
      # --- MariaDB equivalent ----------------------------------------------
      # ${pkgs.mariadb}/bin/mysqldump --all-databases > /var/backups/mysql-all.sql
      # --- Libvirt: live VMs are huge+torn — skip running ones ------------
      #   (either shutoff first, or backup only shutoff domains):
      # for vm in $(virsh list --name --state-shutoff); do
      #   echo "safe: $vm"
      # done
    '';
    backupCleanupCommand = ''
      rm -f /var/backups/pg-all.sql     # no stale dumps accumulating
    '';
    # and ADD the dump dir to paths:
    # paths = [ ... "/var/backups" ];
  };
}
```

(Nextcloud/Immich etc.: the Self-Hosting guide's maintenance hooks fit here the same way — freeze app, dump DB, unfreeze.)

## 8. Testing Restores (the part that matters)

```bash
# ---- The quarterly drill (put it in your calendar NOW) -----------------

# 1. VERIFY the repo (before trusting it):
sudo restic -r <repo> --password-file <pw> check --read-data-subset=10%

# 2. Restore to a SCRATCH location — never over live data:
sudo restic -r <repo> --password-file <pw> \
  restore latest --target /tmp/restore-drill

# 3. Actually open the files. A "successful restore" that produces
#    unreadable documents is a failed backup:
file /tmp/restore-drill/home/fury/Documents/important.pdf

# 4. Single-file recovery speed test (the real-world case):
sudo restic -r <repo> --password-file <pw> \
  dump latest home/fury/Documents/important.pdf > /tmp/recovered.pdf
#    'dump' streams ONE file out — no full restore needed. Your
#    day-to-day recovery tool.

# 5. Full-machine rehearsal (Troubleshooting guide's chroot §5):
#    boot the spare/live system, restore flake from backup, rebuild,
#    restore /home, boot. Time it. That's your real RTO.

# ---- Automated canary (monitoring §9's heart) --------------------------
# A tiny timer that restores a canary file weekly and compares:
```

```nix
{ config, pkgs, ... }: {
  systemd.services.backup-canary = {
    description = "Backup restore canary";
    script = ''
      set -e
      # restore the canary file and verify checksum:
      sudo -u root ${pkgs.restic}/bin/restic \
        -r /mnt/backup-disk/restic-fury \
        --password-file /run/secrets/restic-password \
        dump latest home/fury/.backup-canary \
        | cmp - /home/fury/.backup-canary-reference \
        || { echo "CANARY MISMATCH"; exit 1; }
      echo canary-ok
    '';
  };
  systemd.timers.backup-canary = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
```

## 9. Monitoring & Alerts

A backup without a failure alert is Schrödinger's backup:

```nix
{ config, pkgs, ... }: {
  # restic module: runCheck (§3.1) covers repo health.

  # Timer-level alerts — did the backup RUN? Two approaches:

  # 1. systemd OnFailure wiring (works for any unit):
  systemd.services."restic-backups-fury-local" = {
    unitConfig.OnFailure = "notify-backup-failure.service";
  };
  systemd.services."notify-backup-failure" = {
    description = "Alert on backup failure";
    script = ''
      # your channel: ntfy, gotify, email via msmtp, healthchecks.io ping...
      ${pkgs.curl}/bin/curl -fsS \
        "https://healthchecks.example.com/ping/<uuid>/fail" || true
    '';
  };

  # 2. healthchecks.io-style dead-man switch (alert when it does NOT run):
  #    append to backupCleanupCommand:
  #      curl -fsS https://hc-ping.com/<uuid> || true
  #    the service pings healthchecks.io; if the ping stops arriving,
  #    healthchecks emails you. Catches "timer silently never ran".
}
```

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `repository is already initialized` errors on boot | You set `initialize = true` while the repo was hand-initialized — harmless, but cleanest is to let the module own init (one or the other). |
| Timer never fires | `systemctl list-timers` (exists? next elapse?), then `journalctl -u restic-backups-fury-local.timer`. `Persistent = true` catches missed runs. |
| Backup takes forever / grows huge | Check `exclude` (§3.1) — usually `.cache`/VM images/node_modules. `restic diff` between snaps shows the churn source. |
| `file does not exist` in dump/restore | Paths in snapshots are RELATIVE to the paths= roots — `dump latest home/fury/x` not `dump latest /home/fury/x`. |
| B2: `NoSuchBucket` / 401 | environmentFile keys wrong (sops §10) or bucket name typo in `repository`. B2 application keys need bucket-scoped if restricted. |
| borg: `Repository already exists` on new host | `borg init` was run by hand — with the module, DON'T init manually; or point repo at a fresh path. Passphrase mismatch across runs breaks repo access identically (sops consistency). |
| Restored DB dump won't load | Dump was taken from a running service without §7's prepare hook — start over with dumps in the pipeline; older torn dump unrecoverable. |
| Restic check reports pack corruption | Restic can rebuild index: `restic rebuild-index`; if data packs lost: `--read-data` identifies which; affected snapshots' files list via `restic find --pack <id>` — restore those files from offsite. |
| Canary fails but backups "succeeded" | You're backing up a canary that changed — reference file drifted. Re-pin reference, but FIRST understand why (this is the alarm working as intended!). |

## 11. Deep Cuts: forget vs prune, repositoryFile, btrfs send, multi-host

### 11.1 encryption.mode repokey-blake2 + doInit caution

```nix
{ config, ... }: {
  services.borgbackup.jobs."fury" = {
    # repokey-blake2 = key stored IN repo (passphrase via passCommand), BLAKE2
    # checksum (faster than SHA256 on AMD Zen / Intel without SHA-NI offload).
    # Alternatives: repokey (SHA256), keyfile-blake2 (key OUTSIDE repo — safer
    # against passphrase-guess if repo leaks, but lose key = lose everything).
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
    # doInit = true creates the repo on first run — CAUTION: if the path already
    # holds a repo with a DIFFERENT passphrase, init silently succeeds then every
    # backup fails auth. Verify empty dir first: ssh backup@nas.lan ls repos/fury
    doInit = true;
  };
}
```

### 11.2 exclude (restic) vs patterns (borg)

```nix
{ config, ... }: {
  services.restic.backups."fury-local" = {
    # exclude = shell globs matched against full path, one per line in exclude-file:
    exclude = [ "*.tmp" "/home/fury/.cache" "*/node_modules" "*/target" ];
  };
  services.borgbackup.jobs."fury" = {
    # patterns = borg PATTERN style (fm: = fnmatch, pf: = path-full, re:, sh:):
    patterns = [ "fm:*.tmp" "- /home/fury/.cache" "- */node_modules" "+ /home/fury" ];
    # Order matters (first match wins) — excludes (-) BEFORE includes (+).
  };
}
```

### 11.3 restic forget vs pruneOpts + repositoryFile rotation

```bash
# pruneOpts IS forget --prune run AFTER backup (module source: restic.nix pruneCmd).
# Manual equivalents:
restic -r <repo> forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12
restic -r <repo> forget --keep-within 30d   # alternate time-window style
restic -r <repo> prune                       # full repack (slow, after many forgets)
```

```nix
{ config, ... }: {
  services.restic.backups."fury-offsite" = {
    # repository vs repositoryFile: EXACTLY ONE (assertion in module).
    # repositoryFile wins for rotation — endpoint URL lives in a sops secret
    # you can re-key without editing the Nix file (B2 -> S3 migration):
    repositoryFile = config.sops.secrets."restic-repo-url".path;  # contains "b2:fury-backups:restic"
    # repository = "b2:fury-backups:restic";  # use this OR repositoryFile, never both
    passwordFile = config.sops.secrets."restic-password".path;
    pruneOpts = [ "--keep-monthly 12" "--keep-yearly 3" ];
  };
}
```

### 11.4 systemd OnFailure alerting (expanded)

```nix
{ config, pkgs, ... }: {
  systemd.services."restic-backups-fury-local".unitConfig.OnFailure = "notify-backup-failure.service";
  systemd.services."borgbackup-job-fury".unitConfig.OnFailure = "notify-backup-failure.service";
  systemd.services."notify-backup-failure" = {
    description = "Alert on backup failure";
    script = ''
      ${pkgs.curl}/bin/curl -fsS "https://healthchecks.example.com/ping/<uuid>/fail" || true
      echo "backup $MONITOR_UNIT failed" | ${pkgs.systemd}/bin/systemd-cat -t backup -p emerg || true
    '';
  };
  # Dead-man switch (catches timer-never-ran): ping on SUCCESS in backupCleanupCommand
  # + healthchecks.io period = timer interval + grace. Both directions covered.
}
```

### 11.5 btrfs send/receive + snapper timeline (the "oops + disaster" pair)

```bash
# Snapper timeline covers "oops" (hourly local). For a SECOND disk copy:
sudo btrfs subvolume snapshot -r /home /home/.snapshots/manual-$(date +%F)
sudo btrfs send /home/.snapshots/manual-2026-09-12 | sudo btrfs receive /mnt/backup-disk/btrfs/
# Incremental after first full:
sudo btrfs send -p /home/.snapshots/manual-prev /home/.snapshots/manual-new | sudo btrfs receive /mnt/backup-disk/btrfs/
# Timeline retention lives in services.snapper.configs.*.TIMELINE_LIMIT_* (§5) —
# send/receive does NOT prune; prune the receive side with btrfs subvolume delete.
```

### 11.6 Multi-host restic/borg with per-machine hardware notes

```nix
{ config, ... }: {
  # Per-host repo dirs (never share one restic repo across OS installs — lock contention):
  #   NAS layout: /repos/<hostname>/restic  +  /repos/<hostname>/borg
  services.restic.backups."fury-local".repository = "/mnt/backup-disk/restic-fury";
  # Laptop (Intel iGPU, small SSD): exclude VM images + .cache, daily, weekly offsite
  # Desktop (AMD dGPU + HDD bulk): include /mnt/data, longer hourly snapper timeline
  # Server (ZFS): prefer zfs-auto-snapshot + restic --stdin dumps, not btrfs §11.5
  services.borgbackup.jobs."fury".repo = "ssh://backup@nas.lan/./repos/fury";
  # Server side quotas per host: services.borgbackup.repos.<host>.quota (§4) —
  # size by hardware: laptop 100G, desktop 500G, VM-host 1T (images excluded anyway).
}
```

## 12. Reference Index

- restic docs: <https://restic.readthedocs.io/>
- restic backend table: <https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html>
- Borg docs: <https://borgbackup.readthedocs.io/>
- nixpkgs module sources: `nixos/modules/services/backup/{restic,borgbackup}.nix`
- borgmatic (if you outgrow the module): <https://torsion.org/borgbackup/>
- Snapper: <https://github.com/openSUSE/snapper>
- Healthchecks.io dead-man pattern: <https://healthchecks.io/docs/>
- 3-2-1 backup rule: <https://us-cert.cisa.gov/ncase/backup/> (CISA formulation)
- Companions: `Troubleshooting-Recovery-NixOS.md` (§8's full rehearsal), `Secrets-Management-NixOS.md` (every password/key above)
