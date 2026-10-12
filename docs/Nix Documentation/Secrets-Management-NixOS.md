# Secrets Management on NixOS

An exhaustive, independently-usable reference for managing secrets on NixOS — the problem (the Nix store is world-readable), the solutions (sops-nix, agenix), imperative fallbacks (environment files, systemd credentials), and the anti-patterns to avoid. Every code block is self-contained and copy-pasteable, with inline comments explaining what each line does.

**Sources synthesized:** sops-nix README (numtide) · agenix README (ryantm) · NixOS Manual (secret files, activation scripts) · systemd.exec(5) LoadCredential/ SetCredential · systemd-creds(7). Schema verified against nixpkgs release-26.05; cross-check <https://search.nixos.org/options> before adopting.

**Companion guides:** `Hardening-NixOS.md` (store hardening), your flake setup (`new-flake.nix` — sops-nix slots in exactly where lanzaboote/qylock do).

---

## Table of Contents

1. [Why Secrets Are a Problem on NixOS](#1-why-secrets-are-a-problem-on-nixos)
2. [Choosing Your Tool](#2-choosing-your-tool)
 3. [sops-nix: The Complete Setup](#3-sops-nix-the-complete-setup)
     - [3.6 sops.age.sshKeyPaths (host keys as decryption keys)](#36-sopsagesshkeypaths)
     - [3.7 The updatekeys Flow](#37-the-updatekeys-flow)
     - [3.8 Systemd Ordering (after sops-nix)](#38-systemd-ordering)
 4. [agenix: The Alternative](#4-agenix-the-alternative)
     - [4.1 git-crypt Alternative](#41-git-crypt-alternative)
     - [4.2 Age Plugins (1Password / Vault)](#42-age-plugins-1password--vault)
 5. [Secrets Without a Framework (env files, tmpfiles, activation)](#5-secrets-without-a-framework)
 6. [Per-Service Secrets Patterns](#6-per-service-secrets-patterns)
 7. [Secrets in Your Flake Structure](#7-secrets-in-your-flake-structure)
     - [7.1 Per-Host Keys (multi-machine repos + vendor modules)](#71-per-host-keys-multi-machine-repos--vendor-modules)
     - [7.2 Remote Deploy (nixos-anywhere + disko + secrets)](#72-remote-deploy-nixos-anywhere--disko--secrets)
8. [Rotation, Backup & Recovery](#8-rotation-backup-recovery)
9. [Anti-Patterns & Common Mistakes](#9-anti-patterns-common-mistakes)
10. [Troubleshooting](#10-troubleshooting)
11. [Reference Index](#11-reference-index)

---

## 1. Why Secrets Are a Problem on NixOS

Everything in `configuration.nix` — every string, every attribute — lands in the **world-readable** `/nix/store`. These are all **leaks**:

```nix
# ❌ ALL of these put the secret in a store path readable by every
#    process and every user on the machine — shown as fragments:
#
#   services.foo.password = "hunter2";
#   environment.etc."foo.env".text = ''
#     API_KEY=sk-live-abcdef...
#   '';
#   wireguard.interfaces.wg0.privateKey = "AAAA...";
#   users.users.fury.hashedPassword = "$6$...";
```

Even `hashedPassword` belongs in sops — offline cracking of a hash beats nothing. The `/nix/store` also **never forgets**: secrets baked into old generations stay readable until GC collects them, and any `nix copy`/push to a builder ships them along.

The correct model: **store only an encrypted blob** in your config/repo; decrypt at **activation time** into a runtime location (`/run/secrets`, mode 600, owner-restricted), never into the store.

## 2. Choosing Your Tool

| Tool | Encryption | Best for | Trade-offs |
|---|---|---|---|
| **sops-nix** | age/SSH keys via sops; one file, many keys | Multi-host flakes, teams — the de-facto standard | YAML/JSON structure; sops tooling needed |
| **agenix** | age keys; one file per secret, per-host keys | Single-host, simpler mental model | N files for N secrets; rekey on host changes |
| systemd credentials | plaintext file loaded by systemd | single service, secret already available at boot | no encryption — just a delivery mechanism |
| environmentFile + tmpfiles | plaintext, you protect the file | last resort / secrets available pre-network | manual discipline required |

Both sops-nix and agenix **encrypt with age** (or SSH keys) and decrypt during **activation** — before services start, after the store is mounted. Both are flakes you add exactly like your existing lanzaboote input.

## 3. sops-nix: The Complete Setup

### 3.1 Add the flake input

```nix
# In your flake.nix inputs (alongside lanzaboote/qylock):
{
  inputs = {
    # ... your existing inputs ...
    sops-nix.url = "github:Mic92/sops-nix";

    # Pin it to your nixpkgs to avoid a second copy of nixpkgs:
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### 3.2 Import the module

```nix
# In flake.nix outputs — add to the modules list of nixosConfigurations:
#   modules = [
#     ./configuration.nix
#     lanzaboote.nixosModules.lanzaboote
#     qylock.nixosModules.default
#     sops-nix.nixosModules.sops   # ← add this
#   ];
```

### 3.2.1 Generate the encryption key (age)

```bash
# One-time, on this machine:
nix-shell -p age --run 'age-keygen -o ~/.config/sops/age/keys.txt'

# The PUBLIC key (used to encrypt TO this machine) — print it:
nix-shell -p age --run 'age-keygen -y ~/.config/sops/age/keys.txt'
# → age1xxxxx...  copy this; it goes in .sops.yaml
```

The private key stays at `~/.config/sops/age/keys.txt` — **back it up somewhere safe** (password manager, encrypted USB). Lose it = lose every secret encrypted to it.

### 3.3 The sops config (which keys encrypt which files)

```yaml
# .sops.yaml — at the ROOT of your /etc/nixos (the flake repo).
# Sops reads this to decide encryption rules per path pattern:
keys:
  # Your machine's age public key(s) — every host that must decrypt:
  - &fury-desktop age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  # Optionally a second admin's key (recovery / team):
  # - &admin2 age1yyyyy...

creation_rules:
  # All files under secrets/ are encrypted to fury-desktop (+ admin2):
  - path_regex: secrets/.*\.(yaml|json|env)$
    key_groups:
      - age:
          - *fury-desktop
          # - *admin2
```
# After changing .sops.yaml, re-encrypt every file to the new key set:
#   sops updatekeys secrets/secrets.yaml

### 3.4 Create an encrypted secrets file

```bash
# secrets.yaml — a single file holding MANY secrets:
nix-shell -p sops --run 'sops secrets/secrets.yaml'

# In the editor that opens, write plain YAML; on save it's encrypted:
#   wireguard_private: AAAA...
#   nextcloud_admin: hunter2
#   ssh_host_ed25519: |
#     -----BEGIN OPENSSH PRIVATE KEY-----
#     ...
```

Commit this file to git — it's ciphertext. 

### 3.5 Use the secrets in configuration.nix

```nix
{ config, ... }: {
  # Point sops-nix at the encrypted file (path in your config dir):
  sops.defaultSopsFile = ../secrets/secrets.yaml;  # relative to this module

  # Age decryption: normally automatic (it reads the default key
  # location). Explicit form for non-default paths:
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # (useful on servers where you place the key via install media)
  # SSH host keys as fallback decryption keys:
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Declare which secrets to materialize and HOW:
  sops.secrets = {
    # Each attrset becomes a file under /run/secrets/<name>,
    # root-owned 0400 by default.
    "wireguard_private" = { };

    # Per-secret ownership — for service users:
    "nextcloud_admin" = {
      owner = "nextcloud";
      group = "nextcloud";
      mode = "0400";
    };

    # Restart behavior when the secret changes on rebuild:
    "ssh_host_ed25519" = {
      path = "/etc/ssh/ssh_host_ed25519_key";   # place it somewhere specific
      mode = "0600";
      # restartUnits = [ "sshd.service" ];      # bounce dependents on change
    };
  };
}
```

### 3.6 sops.age.sshKeyPaths (host keys as decryption keys)

```nix
{ config, ... }: {
  # DEFAULT: sops-nix auto-imports your OpenSSH host keys as age keys
  # (derived from services.openssh.hostKeys — ed25519 entries). This is
  # why a fresh machine often "just works" with zero keyFile config:
  # sops.age.sshKeyPaths defaults to the ed25519 host key paths.

  # Explicit form — decrypt with the host SSH key (no separate age key
  # file to provision on servers):
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Explicit age key file INSTEAD (workstations, install media flows):
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # sops.age.sshKeyPaths = [ ];  # ← disable host-key fallback when you
  #   # pin keyFile, else sops-nix still tries converting (possibly
  #   # nonexistent) host keys and the error misleads you.

  # sops.age.generateKey = true;  # generate keyFile if missing (fresh
  #   # installs, ephemeral CI builders — NOT for machines whose key is
  #   # already the encryption recipient in .sops.yaml).
}
```

```bash
# Encrypt TO a host's SSH key: convert host pubkey → age recipient:
nix-shell -p ssh-to-age --run \
  'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
# → age1xxx...  paste into .sops.yaml keys:, then §3.7 updatekeys.
# Or derive from a USER key for your editing identity:
#   ssh-to-age < ~/.ssh/id_ed25519.pub
```

Catch-22 warning: never encrypt a secret that *delivers the very SSH host key* sops-nix decrypts with (shipping `/etc/ssh/ssh_host_*` via sops itself) — on first boot there is nothing to decrypt with. Host keys ship via nixos-anywhere/disko provisioning (§7.2) or age `keyFile`, never via the mechanism they unlock.

### 3.7 The updatekeys Flow

```bash
# After EVERY .sops.yaml change (new host, removed admin, new file rule):
sops updatekeys secrets/secrets.yaml        # re-encrypt one file
sops updatekeys secrets/*.yaml              # ... or all of them

# Typical flows:
# ADD a host: 1) age-keygen -y on the new host → pubkey
#             2) add to .sops.yaml keys: + creation_rules
#             3) sops updatekeys <files> → commit → deploy
# REMOVE a host: 1) delete its key from .sops.yaml
#             2) sops updatekeys <files> → commit → ROTATE the actual
#                secret values inside (removed host could have cached them!)
# ADD a file: create under a path matching a creation_rule, then
#             `sops <newfile>` — rules auto-apply on first save.
# VERIFY recipients: sops -d secrets/secrets.yaml > /dev/null && echo OK
```

### 3.8 Systemd Ordering (after sops-nix)

```nix
{ config, ... }: {
  sops.secrets."nextcloud-admin" = {
    owner = "nextcloud";
    # restartUnits: sops-nix bounces these when the secret CHANGES:
    restartUnits = [ "phpfpm-nextcloud.service" ];
  };

  # Hard ordering for services that read the secret file at ExecStart:
  systemd.services.nextcloud-setup = {
    after = [ "sops-nix.service" ];      # decrypt FIRST, then configure
    wants = [ "sops-nix.service" ];
    # (sops activation itself runs pre-services by default; this is the
    # belt-and-braces for custom units, timers, and restartUnits races.)
  };
  # User-password secrets need neededForUsers (§6), NOT this — users are
  # created in an EARLIER activation phase than sops-nix.service.
}
```

### 3.9 Templates (compose a config file from several secrets)

```nix
{ config, ... }: {
  # Build a full config FILE from multiple secrets — useful when a
  # service wants one config file, not env vars:
  sops.templates."vault.env" = {
    content = ''
      VAULT_TOKEN=${config.sops.placeholder."vault_token"}
      VAULT_ADDR=https://vault.example.com
    '';
    owner = "vault";
  };
  # → materialized at /run/secrets/rendered/vault.env
}
```

## 4. agenix: The Alternative

```bash
# 1. Keys: same age keygen as §3.2.1.

# 2. In your flake: agenix.url = "github:ryantm/agenix";
#    modules += [ agenix.nixosModules.default ];
```

```nix
# 3. secrets.nix — declares every secret + which hosts may decrypt:
let
  fury-desktop = "age1xxxxx...";
in
{
  "wireguard-private.age".publicKeys = [ fury-desktop ];
  "nextcloud-admin.age".publicKeys = [ fury-desktop ];
}
```

```bash
# 4. Create/edit (one file per secret):
nix-shell -p agenix --run 'agenix -e wireguard-private.age'
```

```nix
# 5. configuration.nix:
{ ... }: {
  age.secrets = {
    wireguard-private = {
      file = ../secrets/wireguard-private.age;
      # owner/group/mode/path like sops-nix:
      owner = "root"; mode = "0400";
    };
  };
  # → /run/agenix/wireguard-private   # sops-nix uses /run/secrets/*
}
```

**sops-nix vs agenix in practice:** sops-nix's single multi-secret YAML + templates scales better with many services; agenix's one-file-per-secret keeps diff history per secret and makes sharing individual secrets easier. Both are excellent — pick one and stay consistent.

### 4.1 git-crypt Alternative

```bash
# Transparent git encryption (whole-file, GPG-based) — no NixOS module,
# no activation wiring. For repos where sops-nix feels heavy:
nix-shell -p git-crypt --run 'git-crypt init'        # one-time per repo
# .gitattributes — WHAT gets encrypted (everything else stays plaintext):
#   secrets/** filter=git-crypt diff=git-crypt
#   *.key filter=git-crypt diff=git-crypt
nix-shell -p git-crypt --run 'git-crypt add-gpg-user ADMIN_GPG_ID'
# → commits carry ciphertext; checkout on an unlocked machine = plaintext.
```

```nix
{ config, ... }: {
  # Consumption is §5-shaped: the file arrives via git checkout, so point
  # modules at its PATH (never its content):
  # services.vaultwarden.environmentFile = "/etc/nixos/secrets/vault.env";
}
# Trade-offs vs sops-nix/agenix: GPG keyring management (heavier than age),
# ALL collaborators unlock ALL files (no per-file/per-host recipients),
# no templates/restartUnits/neededForUsers — you hand-roll §5 patterns.
# Good for: small single-host repos, dotfiles, bootstrapping the keys that
# sops-nix itself will later use. Bad for: multi-host flakes with
# host-specific secrets (§7.1) — use sops-nix there.
```

### 4.2 Age Plugins (1Password / Vault)

```nix
{ config, pkgs, ... }: {
  # sops delegates to age, and age supports PLUGINS (external recipients
  # like 1Password/vault/HSMs). sops-nix exposes them for decryption:
  # sops.age.plugins = with pkgs; [ age-plugin-op vault-plugin ];
  #   # ↑ adds plugin binaries to PATH for sops-install-secrets.
  # Then .sops.yaml recipients can be plugin identities (e.g. 1Password
  # Connect references) alongside plain age1 keys.
}
# Reality check: plugins shine for HUMAN editing identities (your laptop
# unlocks via 1Password biometric, no keys.txt to back up). MACHINES
# should still decrypt with host keys (§3.6) or keyFile — unattended
# boots can't answer a 1Password prompt. Pattern: encrypt to BOTH the
# admin's plugin identity AND each host's age key; humans edit via the
# plugin, servers decrypt via their own keys.
```

## 5. Secrets Without a Framework

### 5.1 The environmentFile pattern (many NixOS modules support it natively)

```nix
{ config, pkgs, ... }: {
  # Most services expose an environmentFile option — the file is NOT
  # in the store, you create it once on the machine:
  services.vaultwarden = {
    enable = true;
    environmentFile = "/var/lib/vaultwarden/env";  # root:root 0400
    # containing e.g.:
    #   ADMIN_TOKEN=$argon2id$...
  };

  # Persist the file's protection across restarts:
  systemd.tmpfiles.rules = [
    "Z /var/lib/vaultwarden 0700 vaultwarden vaultwarden -"
  ];
}
```

### 5.2 systemd LoadCredential (per-service secret handoff)

```nix
{ config, pkgs, ... }: {
  # Hand a file to a service at runtime without global env pollution:
  systemd.services.myservice = {
    serviceConfig = {
      # systemd copies the file to a private per-service location:
      LoadCredential = "api-key:/etc/credentials/myservice.key";
      # Inside the service: read $CREDENTIALS_DIR/api-key
    };
  };
}
```

### 5.3 Activation script (last resort)

```nix
{ config, pkgs, ... }: {
  # Runs at switch-to-configuration time. Root powers, be careful:
  system.activationScripts.secrets.text = ''
    # Only create once — never overwrite (you'd clobber edits):
    if [ ! -e /etc/credentials/special.key ]; then
      umask 077
      echo "generating..."
      ${pkgs.openssl}/bin/openssl rand -hex 32 > /etc/credentials/special.key
    fi
  '';
}
```

## 6. Per-Service Secrets Patterns

The recurring wiring, for services you'll actually run (see Self-Hosting guide):

```nix
{ config, ... }: {
  # WireGuard — the classic sops use case:
  sops.secrets."wg-private" = { };
  networking.wg-quick.interfaces.wg0 = {
    # wg-quick reads the FILE at runtime; the store only sees the path:
    privateKeyFile = config.sops.secrets."wg-private".path;
    # ❌ NOT: privateKey = "..."; ← store leak!
  };

  # Forgejo:
  sops.secrets."forgejo_db" = { owner = "forgejo"; };
  services.forgejo = {
    database.passwordFile = config.sops.secrets."forgejo_db".path;
  };

  # Any oci-container:
  sops.secrets."registry_env" = { };
  virtualisation.oci-containers.containers.app.environmentFiles = [
    config.sops.secrets."registry_env".path
  ];

  # Your own user's password:
  sops.secrets."fury_hashed_password" = { neededForUsers = true; };
  users.users.fury.hashedPasswordFile =
    config.sops.secrets."fury_hashed_password".path;
  # neededForUsers = true: materialize EARLY — user creation happens
  # before normal activation. Critical, commonly missed!
}
```

## 7. Secrets in Your Flake Structure

```
/etc/nixos/
├── flake.nix            # + sops-nix input & module
├── configuration.nix    # sops.secrets declarations
├── secrets/
│   ├── secrets.yaml     # sops-encrypted (SAFE in git)
│   └── wg-private.age   # agenix-encrypted (SAFE in git)
├── .sops.yaml           # key routing config (§3.3)
└── .gitignore           # NEVER ignore the encrypted files; DO
                         # ignore any plaintext drafts by habit.
```

Host-specific routing (multi-machine flakes) lives in `.sops.yaml` `creation_rules` — match `secrets/fury-desktop/.*` to that host's key only, so your laptop's secrets aren't decryptable on the server and vice versa.

### 7.1 Per-Host Keys (multi-machine repos + vendor modules)

```yaml
# .sops.yaml — per-host files + one shared file, per-vendor secrets isolated:
keys:
  - &admin age1adminxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &server age1serverxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &desktop age1desktopxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
creation_rules:
  - path_regex: secrets/shared/.*\.yaml$        # every host + admin
    key_groups: [{ age: [*admin, *server, *desktop] }]
  - path_regex: secrets/server/.*\.yaml$        # server-only (ACME DNS
    key_groups: [{ age: [*admin, *server] }]    # token, Nextcloud admin)
  - path_regex: secrets/desktop/.*\.yaml$       # desktop-only (WG key,
    key_groups: [{ age: [*admin, *desktop] }]   # NVIDIA API tokens)
```

```nix
# hosts/server/gpu-nvidia.nix — host-specific secrets for a VENDOR module:
{ config, ... }: {
  # This host has an NVIDIA GPU: its CUDA/NVENC service tokens live in
  # the server-only file; the shared file holds nothing vendor-specific:
  sops.defaultSopsFile = ../../secrets/shared/common.yaml;
  sops.secrets."acme-cloudflare" = {
    sopsFile = ../../secrets/server/services.yaml;  # per-host override
  };
  sops.secrets."nvidia-license-token" = {
    sopsFile = ../../secrets/server/gpu-nvidia.yaml;
    owner = "jellyfin";
  };
}
# hosts/desktop/gpu-amd.nix mirrors it with ../../secrets/desktop/gpu-amd.yaml
# (ROCm tokens, AMD-only registry creds). Rule: vendor-specific secrets
# NEVER land in shared/ — a CUDA token decryptable on an AMD-only box is
# a leak shaped like convenience. After adding a host: §3.7 updatekeys.
```

### 7.2 Remote Deploy (nixos-anywhere + disko + secrets)

```bash
# The bootstrap problem: a fresh disk has no /var/lib/sops-nix/key.txt
# and no host SSH keys — so NOTHING encrypted to the target can decrypt.
# Order matters: provision keys FIRST, secrets SECOND.

# 1. Generate the target's age key OFFLINE (on your admin machine):
age-keygen -o keys/server.age.txt        # public key → .sops.yaml (§7.1)
sops updatekeys secrets/server/*.yaml    # re-encrypt to include it

# 2. nixos-anywhere ships the key OUT-OF-BAND (never in the flake):
nixos-anywhere --flake .#server \
  --target-host root@192.168.1.50 \
  --extra-files <(printf '%s' "$(cat keys/server.age.txt)" \
    | install -Dm600 /dev/stdin extra-files/var/lib/sops-nix/key.txt)
#   ↑ --extra-files lands BELOW disko formatting: disko wipes the disk,
#   then extra-files are copied — key survives partitioning. Point
#   sops.age.keyFile at /var/lib/sops-nix/key.txt on the target.

# 3. disko runs during install (disko.nix in the target's modules);
#    first boot decrypts via the shipped keyFile; LATER, rotate to host
#    SSH keys (§3.6): ssh-to-age the new host pubkey, updatekeys, deploy,
#    then delete the bootstrap keyFile entry.
# Classic failure: encrypting ONLY to the target's FUTURE ssh host key
# before it exists — install succeeds, first boot has empty /run/secrets.
# Always include the bootstrap keyFile recipient until rotation completes.
```

## 8. Rotation, Backup & Recovery

- **Backing up keys:** the age private keys (per host) are the crown jewels — password manager + encrypted offline copy. Encrypted secret files without keys are noise.
- **Rotating a secret:** `sops secrets/secrets.yaml` → edit value → save → rebuild. For leaked keys: add a new key to `.sops.yaml`, `sops updatekeys` (re-encrypts to new key set), **remove** the compromised key, updatekeys again, then rotate the actual secret values inside.
- **Disaster recovery:** reinstalling a host = new age key = update `keys:` + `sops updatekeys` on every file → old machine's key can no longer decrypt (that's the point).
- **Backups of secrets:** the *encrypted* repo IS the backup, provided keys are backed up separately (§ above). Never `borg`/`restic` the decrypted `/run/secrets` — it's tmpfs, gone at reboot, and should stay that way.

## 9. Anti-Patterns & Common Mistakes

| ❌ Anti-pattern | ✅ Instead |
|---|---|
| `password = "..."` in config | `passwordFile`/`hashedPasswordFile` + sops/agenix |
| `echo secret > /etc/...` by hand | activation script or tmpfiles with 0400 |
| Secrets in flake inputs (URLs with tokens) | fetch via env at eval time is worse — use sops for *runtime*, private flake for *eval-time* |
| `environment.variables.SECRET = ...` | per-service LoadCredential; env vars leak to `/proc/*/environ` of every child |
| Putting the age key in the same git repo | keys live on the machines / password manager only |
| `neededForUsers` forgotten for password secrets | users created before activation → set `neededForUsers = true` (§6) |
| Assuming /run/secrets survives reboot | tmpfs by design — declarations re-materialize it each boot; fine |
| Encrypting to SSH keys when you don't need host SSH access | age keys are simpler & faster; SSH keys as sops keys pull in agent complexity |

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `sops.secrets` files missing after rebuild | Check `systemctl status sops-nix` / activation output. Usually: key file not found (`sops.age.keyFile` wrong) or the secret name doesn't match a key in the YAML. |
| `cannot decrypt` with correct key | The file was encrypted to a DIFFERENT key set — check `.sops.yaml` at commit time vs now; `sops updatekeys secrets/secrets.yaml`. |
| Service starts before secret exists | Order: sops activation runs pre-services by default. If you have `restartUnits` racing, add `systemd.services.<name>.after = [ "sops-nix.service" ];` to your service or use `wantedBy` correctly. |
| User password not applied | `neededForUsers = true` missing (§6) — user mutation happens in an earlier activation phase. |
| Permission denied reading secret in service | owner/group of the sops.secrets entry ≠ the service user. Set `owner`/`group` explicitly. |
| `sops` editor opens empty/creates new file each time | You're opening the path, not the file — `sops <file>` edits existing if present. Use `nix-shell -p sops` consistently for stable tool versions. |
| agenix: `no rule to make target` | The `.age` file must be committed & the secrets.nix `publicKeys` entry must exist BEFORE `agenix -e` succeeds. |
| `/run/agenix` empty on boot | Key not present at early activation (e.g., key on a mounted partition that mounts later) — move key to the root FS or initrd-available location. |

## 11. Reference Index

- sops-nix: <https://github.com/Mic92/sops-nix>
- agenix: <https://github.com/ryantm/agenix>
- sops itself: <https://github.com/getsops/sops>
- age format: <https://age-encryption.org/>
- systemd credentials: `man systemd.exec` (LoadCredential), `man systemd-creds`
 - NixOS manual — managing secrets: <https://nixos.org/manual/nixos/stable/#sec-removing-secrets>
 - nixos-anywhere: <https://github.com/nix-community/nixos-anywhere> (+ disko: <https://github.com/nix-community/disko>)
 - git-crypt: <https://github.com/AGWA/git-crypt>
 - age plugins: <https://github.com/getsops/sops#encrypting-using-age> + `sops.age.plugins` option
- Companions: `Hardening-NixOS.md`, `Networking-NixOS.md` (WireGuard usage), `Self-Hosting-NixOS.md` (services that consume secrets)
