# NixOS + Mango + Dotfiles Backup Guide

Found on this machine:
- **NixOS:** `/etc/nixos/` (already a git repo, no remote, dirty)
- **mango:** `/home/fury/.config/mango/` (`config.conf`, `media.conf`, `*.sh`, `dms/`)
- **All dotfiles:** `/home/fury/.config/` (131 entries incl. hypr, kde, ghostty, kitty, mango, rofi, waybar, DankMaterialShell, etc.)
- **Home dotfiles:** `~/.zshrc`, `~/.zshenv`, `~/.gitconfig`, `~/.gtkrc-2.0`, etc.

Goal: one private GitHub repo with everything, so rebuilds stay atomic.

Layout in repo (`~/dotfiles/`):
```
dotfiles/
  nixos/  -> /etc/nixos
  config/ -> ~/.config (includes mango/)
  home/   -> selected ~/.* files
```

## 1. Login + prep

```bash
gh auth login
git config --global user.name "furynix"
git config --global user.email "235014707+Hackcoon@users.noreply.github.com"

mkdir -p ~/dotfiles/nixos ~/dotfiles/config ~/dotfiles/home
```

## 2. Copy configs

```bash
# NixOS system - exclude build output
rsync -av --delete --exclude='.git' --exclude='result' --exclude='result-*' /etc/nixos/ ~/dotfiles/nixos/

# ALL of ~/.config - exclude caches, browsers, secrets, heavy apps
rsync -av --delete \
  --exclude='BraveSoftware/' \
  --exclude='Electron/' \
  --exclude='mozilla/' \
  --exclude='librewolf/' \
  --exclude='chromium/' \
  --exclude='google-chrome/' \
  --exclude='Bionic/' \
  --exclude='CapoRhythia/' \
  --exclude='CherryStudio/' \
  --exclude='LM Studio/' \
  --exclude='LM-Studio/' \
  --exclude='obsidian/Cache/' \
  --exclude='Code/Cache/' \
  --exclude='VSCodium/Cache/' \
  --exclude='*/Cache/' \
  --exclude='*/CachedData/' \
  --exclude='*/GPUCache/' \
  --exclude='*/Crashpad/' \
  --exclude='pulse/' \
  --exclude='.ssh/' \
  --exclude='.gnupg/' \
  --exclude='.pki/' \
  --exclude='*secret*' \
  --exclude='*token*/' \
  ~/.config/ ~/dotfiles/config/

# Verify mango came along:
ls ~/dotfiles/config/mango/

# Selected home dotfiles (add more as needed)
cp -v ~/.zshrc ~/.zshenv ~/.gitconfig ~/.gtkrc-2.0 ~/.Xresources ~/dotfiles/home/ 2>/dev/null || true
cp -v ~/.config/topgrade.toml ~/dotfiles/home/topgrade.toml 2>/dev/null || true
```

> Private repo required. Never commit: `~/.ssh/`, `~/.gnupg/`, `~/.pki/`, `/etc/NetworkManager/system-connections/`, `~/.config/pulse/cookie`, API keys in CherryStudio / LM Studio / Antigravity / Gemini, `hardware-configuration.nix` leaks UUIDs (ok if private).

## 3. Make it one repo

```bash
cd ~/dotfiles
git init
cat > .gitignore <<'EOF'
# NixOS build outputs
**/result
**/result-*
nixos/.git/

# backups / temp
*.bak*
*.backup*
*~
*.swp
.zcompdump*.zwc

# caches / electron / browsers (in case rsync filter missed)
config/BraveSoftware/
config/Electron/
config/mozilla/
config/librewolf/
config/**/Cache/
config/**/GPUCache/
config/**/Crashpad/
config/**/CachedData/
config/pulse/

# secrets - NEVER commit these
**/.ssh/
**/.gnupg/
**/.pki/
**/*secret*
**/*token*
**/.webui_secret_key
home/.ssh/
EOF

cat > README.md <<'EOF'
# dotfiles
nixos/  -> /etc/nixos
config/ -> ~/.config (includes mango/ -> ~/.config/mango)
home/   -> ~/.* (zshrc, gitconfig, etc)
EOF

  git add nixos config home .gitignore README.md
  git status --short  # review before commit - never blind `git add -A`
  git commit -m "backup: nixos + mango + all dotfiles"
  git branch -M main
```

## 4. Push to GitHub

```bash
gh repo create dotfiles --private --source=. --push
# manual alternative:
# git remote add origin git@github.com:YOURUSER/dotfiles.git
# git branch -M main
# git push -u origin main
```

## 5. Use the flake from `~/dotfiles` (recommended pattern)

`--flake` requires `nixos/flake.nix` in the repo. If you have no flake yet,
either add one first or use legacy `sudo nixos-rebuild switch` (no `--flake`)
until you do.

```bash
# Preferred: keep the flake in ~/dotfiles, build from there directly.
# No symlink/copy needed - /etc/nixos stays untouched.
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#$(hostname)
```

> Flakes only see **tracked** files: `git add` new files first or the rebuild
> will ignore them. Caveat: on encrypted-home setups root may not read
> `~/dotfiles` — if the build fails with permission errors, copy/symlink to
> `/etc/nixos` instead.

## 6. Restore on new machine

```bash
gh auth login
gh repo clone YOURUSER/dotfiles ~/dotfiles
# Backup anything already on the target before overwriting:
# (rsync --delete below mirrors source -> target, deletions included)
cp -a ~/.config ~/.config.pre-restore 2>/dev/null || true
sudo cp -a /etc/nixos /etc/nixos.pre-restore 2>/dev/null || true
sudo mkdir -p /etc/nixos
# Never copy hardware-configuration.nix across hosts - it is host-local
# (UUIDs, devices). Regenerate on the new host instead:
sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
# then merge /tmp/hardware-configuration.nix into the new host's config,
# keeping it untracked/host-local.
sudo rsync -av --exclude='hardware-configuration.nix' ~/dotfiles/nixos/ /etc/nixos/
mkdir -p ~/.config
rsync -av ~/dotfiles/config/ ~/.config/
cp -v ~/dotfiles/home/.zshrc ~/dotfiles/home/.zshenv ~/dotfiles/home/.gitconfig ~/ 2>/dev/null || true
# --flake needs nixos/flake.nix; otherwise legacy `sudo nixos-rebuild switch`.
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#$(hostname)
```

Replace `YOURUSER` with your GitHub username and `#$(hostname)` with your flake host name if different.

## 7. Daily backup

```bash
cd ~/dotfiles
rsync -av --delete --exclude='.git' --exclude='result' /etc/nixos/ nixos/
rsync -av --delete \
  --exclude='BraveSoftware/' \
  --exclude='Electron/' \
  --exclude='mozilla/' \
  --exclude='librewolf/' \
  --exclude='chromium/' \
  --exclude='google-chrome/' \
  --exclude='Bionic/' \
  --exclude='CapoRhythia/' \
  --exclude='CherryStudio/' \
  --exclude='LM Studio/' \
  --exclude='LM-Studio/' \
  --exclude='obsidian/Cache/' \
  --exclude='Code/Cache/' \
  --exclude='VSCodium/Cache/' \
  --exclude='*/Cache/' \
  --exclude='*/CachedData/' \
  --exclude='*/GPUCache/' \
  --exclude='*/Crashpad/' \
  --exclude='pulse/' \
  --exclude='.ssh/' \
  --exclude='.gnupg/' \
  --exclude='.pki/' \
  --exclude='*secret*' \
  --exclude='*token*/' \
  ~/.config/ config/
cp -v ~/.zshrc ~/.zshenv ~/.gitconfig home/ 2>/dev/null || true
git status --short  # review - never blind `git add -A` (secrets check)
git add -A
git status --short
git commit -m "update $(date -I)" || echo "nothing to commit - skipping push"
git push
```

## 8. Backup any file / folder

Same pattern — copy into `~/dotfiles/`, commit, push.

```bash
cd ~/dotfiles

# a) single file - keep same folder structure
# example: ~/Documents/notes.txt -> ~/dotfiles/Documents/notes.txt
mkdir -p Documents
cp -v ~/Documents/notes.txt Documents/

# b) whole folder
# example: ~/Projects/myapp -> ~/dotfiles/Projects/myapp
mkdir -p Projects
rsync -av ~/Projects/myapp/ Projects/myapp/

# c) file outside $HOME (needs sudo)
# example: /etc/samba/smb.conf -> ~/dotfiles/etc/samba/smb.conf
mkdir -p etc/samba
sudo cp -v /etc/samba/smb.conf etc/samba/
sudo chown -R $(id -un):$(id -gn) etc/

# d) commit it
git add -A
git status --short
git commit -m "add notes, myapp, smb.conf"
git push
```

Restore any file:

```bash
# repo -> system (reverse the copy)
cp -v ~/dotfiles/Documents/notes.txt ~/Documents/notes.txt
rsync -av ~/dotfiles/Projects/myapp/ ~/Projects/myapp/
sudo cp -v ~/dotfiles/etc/samba/smb.conf /etc/samba/smb.conf
```

Rules:
1. Text/config/code = OK for GitHub (private repo safest).
2. Never commit large binaries, ISOs, videos, `~/.cache`, `node_modules/`, `.git/`, secrets (`id_rsa`, `.env` with keys, browser profiles).
3. Check size first: `du -sh <path>` — if >10MB, use external drive, not git.
4. Keep structure: `~/dotfiles/` mirrors real paths so you always know where to restore.

## 9. Encrypted secrets in the same repo (sops-nix + age)

Plain git backup above deliberately excludes secrets. To version
them safely, encrypt with sops-nix (age) and commit the
*ciphertext* — private repo + encryption, defense in depth.

```bash
# one-time: age key from existing SSH key (never commit keys.txt)
mkdir -p ~/.config/sops/age
nix-shell -p age ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt"
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"  # system recipient for boot-time decrypt
```

`~/dotfiles/.sops.yaml` (commit this — it holds *public* recipients only):

```yaml
keys:
  - &admin age1YOURPERSONALKEYHERE
  - &system age1YOURHOSTSSHKEYHERE
creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *admin
          - *system
```

```bash
cd ~/dotfiles
mkdir -p secrets
nix run nixpkgs#sops -- secrets/secrets.yaml  # add e.g. WIFI_PSK: "…" then save
```

Wire into flake (system decrypts at activation to `/run/secrets/`, never the store):

```nix
# flake.nix inputs: sops-nix.url = "github:Mic92/sops-nix";
# modules: sops-nix.nixosModules.sops
sops.defaultSopsFile = ./secrets/secrets.yaml;
sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
sops.secrets.wifi_psk = { owner = "root"; };
# consume as: config.sops.secrets.wifi_psk.path
```

Rules: `keys.txt` and `/etc/ssh/*_key` never enter git
(already excluded). Rotate with `sops updatekeys
secrets/secrets.yaml` after adding a host. Home Manager secrets
use `sops-nix.homeManagerModules.sops` + `sops.age.keyFile`
instead — same encrypted file, per-user path under
`/run/user/$UID/secrets/`.

## 10. Multi-host pattern: same repo, host-named modules

`hardware-configuration.nix` is per-machine (UUIDs, devices,
CPU/GPU vendor) — never share it across hosts. Layout:

```
nixos/
  flake.nix            # nixosConfigurations.<hostname> = …
  hosts/<hostname>/
    default.nix          # thin: imports hardware + roles
    hardware-configuration.nix  # generated, host-local
  modules/
    gpu/amd.nix intel.nix nvidia.nix
    roles/base.nix roles/graphical.nix
```

```nix
# hosts/desktop/default.nix — thin entrypoint
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/base.nix
    ../../modules/roles/graphical.nix
    ../../modules/gpu/nvidia.nix   # or amd.nix / intel.nix per host
  ];
  networking.hostName = "desktop";
}
```

```bash
# onboard a new machine: regenerate hardware scan on the target, keep it local
sudo nixos-generate-config --show-hardware-config > ~/dotfiles/nixos/hosts/NEWHOST/hardware-configuration.nix
# rebuild that host only:
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#NEWHOST
```

Per-machine driver notes (shared repo, divergent imports —
backup is mostly GPU-independent except here):
- **AMD:** `amdgpu` kernel driver, Mesa VA-API/VDPAU, `hardware.graphics.enable = true`. No proprietary blob.
- **Intel:** `i915`/`xe` depending on generation, `intel-media-driver` for VA-API on Broadwell+. Same Mesa path as AMD.
- **NVIDIA:** proprietary `nvidia` driver + `hardware.nvidia.modesetting.enable = true`, CUDA/NVDEC only here. Offload vs sync vs offload-prime differs per laptop/desktop — keep it in the host's dir, never in shared `base.nix`. Consider `nixos-hardware` model profiles for laptops.
- Flakes only see tracked files: `git add` the new host dir before rebuilding.

## 11. Impermanence note + real backups (restic / borg)

Git backup above versions *config*, not *state*. Two complements:

- **Impermanence (opt-in):** root wiped per boot (tmpfs or btrfs
  subvolume rollback), explicit `environment.persistence."/persist"`
  for what survives (`/var/lib/nixos`, `/etc/machine-id`,
  `/etc/ssh`, `/etc/NetworkManager/system-connections`,
  `users.<name>.hashedPasswordFile`). `neededForBoot = true` on
  `/persist`, and point sops-nix at the *persisted* key path or
  boot-time decrypt races the bind-mount. Don't adopt this to
  "fix" backups — adopt it to force declarative config; git repo
  from §§1–8 is the prerequisite either way.
- **restic (versioned, encrypted snapshots):** declarative timer,
  password via sops (§9), backs up `/persist` + `/home`:
  ```nix
  services.restic.backups.persist = {
    initialize = true;
    paths = [ "/persist" "/home/fury" ];
    passwordFile = config.sops.secrets.restic_password.path;
    repository = "sftp://user@box:/backups/hostname";
    timerConfig = { OnCalendar = "daily"; Persistent = true; };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 5" "--keep-monthly 12" ];
  };
  ```
- **borg (deduplicated, append-only):** same shape via
  `services.borgbackup.jobs`. Either is for `/persist`,
  databases, media — git stays for text config. Check
  `du -sh` first; repos >10MB of binaries don't belong in
  `~/dotfiles/`.
