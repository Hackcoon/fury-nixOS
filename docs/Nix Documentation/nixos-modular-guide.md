# Making Your NixOS Config Modular — A Practical Guide

**For:** your setup — `/etc/nixos`, flake-based, NixOS 26.05, Secure Boot via Lanzaboote, KDE + XFCE sessions.
**Status:** done once already (2026-09-06). This is the playbook for doing it again, extending it, or doing it on a second machine.

Companion docs:
- `nixos-modularization-plan.md` — the original audit + migration plan
- `~/Downloads/newconfigs-nix/README.md` — the staging-area workflow

---

## 1. The Mental Model

NixOS is already modular — `configuration.nix` is just one module. The module
system **merges** everything you `imports = [ ... ]`:

- **Lists concatenate** across files: `environment.systemPackages` in five
  modules = one combined list. This is why splitting is *safe*.
- **Attrsets merge recursively**: `nix.settings.substituters` in two files
  combines.
- **Scalars conflict** (error!) unless identical: `networking.hostName`
  must live in exactly ONE module. That's your guardrail — if you
  accidentally define a scalar twice, Nix tells you instead of silently
  picking one.

So "modularizing" is not rewriting — it's *cutting the same config into
files and adding imports*. Zero behavior change if done right, and you
verify that with closure diffs (§6).

## 2. Directory Layout (what you have now)

```
/etc/nixos/
├── flake.nix                 # inputs + nixosSystem wiring
├── flake.lock                # pinned revisions
├── configuration.nix         # THIN: imports + stateVersion only (~60 lines)
├── hardware-configuration.nix# generated — do not edit
├── home.nix                  # Home Manager entry (user-level)
└── modules/
    ├── core/       boot, nix (gc/caches), network, locale
    ├── hardware/   nvidia, audio+bluetooth, ssd, realtek-eee
    ├── desktop/    kde, xfce-chicago95, qylock, fonts, themes, portals
    ├── programs/   shell, gaming, appimage, virtualisation,
    │               thunar, firefox, ai-services
    ├── services/   flatpak, printing
    ├── users/      users
    └── packages/   system-packages, apps-fixed (wrapped/patched apps)
```

**Grouping rule of thumb** — one module per *topic you'd edit together*:
- Don't split by NixOS option type (all `services.*` in one file = giant file again).
- Don't go one-option-per-file either (import list becomes unreadable).
- If a module grows past ~150 lines or mixes two concerns, split it.

## 3. The Mechanics

### A module is any nix file returning an attrset

```nix
# modules/hardware/nvidia.nix
{ config, pkgs, lib, ... }:   # take only what you use

{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.modesetting.enable = true;
}
```

### The entry point just imports everything

```nix
# configuration.nix
{ config, pkgs, lib, unstablePkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/core/boot.nix
    ./modules/core/nix.nix
    # ... one line per module
  ];
  system.stateVersion = "26.05";
}
```

### Extra flake arguments flow through automatically

`unstablePkgs` comes from `specialArgs` in flake.nix — any module that
wants it just declares it in its argument set:

```nix
{ config, pkgs, lib, unstablePkgs, ... }:   # ← gets it
{ config, pkgs, ... }:                       # ← doesn't, fine
```

### ⚠️ The #1 flakes gotcha

**In a git repo, Nix only sees files git tracks.** New module not
building with "file not found" or "not tracked by Git"? Run:

```bash
sudo git -C /etc/nixos add <file>   # index is enough; commit later
```

Always `git add` **before** `nixos-rebuild`, even if you're not ready to
commit yet.

## 4. Module Design Rules (learned the hard way)

1. **One scalar, one home.** Scalars (numbers, strings, booleans) defined
   in two modules = eval error (unless identical). Define each in exactly
   one file.
2. **Comment the WHY, not the WHAT.** `powerManagement.enable = true`
   explains itself; "prevents KWin crashing on resume after losing VRAM"
   is the knowledge worth keeping. You lost ~40 alias comments in the
   first split — the audit that restored them is why this rule is here.
3. **Header comment every module**: what it is + cross-references.
   `# XCURSOR_THEME must match google-cursor in packages/system-packages.nix`
   saves future-you a broken cursor hunt.
4. **Keep wrapped/patched apps in their own file** (`apps-fixed.nix`)
   with a loud "do NOT also add the raw package" warning — the raw +
   wrapped duplicate was a live bug in the monolith.
5. **Commented-out optionals are documentation.** Keep near-future
   things (scx scheduler, smartd, hibernation priority flip) as
   commented blocks with full instructions, in the module where they'd
   be enabled.

## 5. Where Things Belong — system vs Home Manager

| Concern | Belongs in | Why |
|---|---|---|
| Bootloader, Secure Boot, kernel | `core/` | machine-wide, pre-login |
| NVIDIA, audio, SSD, EEE workaround | `hardware/` | system hardware |
| Display managers, SDDM themes | `desktop/` | system-wide sessions |
| `programs.zsh` *system defaults* | `programs/shell.nix` | NixOS option, all users |
| Packages everyone needs | `packages/` | system profile |
| **git identity, SSH config** | `home.nix` | yours only |
| Editor/kitty/terminal settings | `home.nix` | user prefs |
| Aliases, prompt, fzf/zoxide init | `home.nix` (future) | your shell UX |
| User-only apps (AI tools, browsers) | `home.nix` (future) | per-user profile |

Rule: if it needs sudo to matter → system module. If it lives in
`$HOME` and only affects your session → Home Manager.

## 6. Home Manager — The Foundation You Now Have

### What's wired up today (start-small on purpose)

```nix
# flake.nix (inputs)
home-manager.url = "github:nix-community/home-manager/release-26.05";
home-manager.inputs.nixpkgs.follows = "nixpkgs";   # ONE nixpkgs — critical

# flake.nix (modules)
home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;     # inherit unfree/cuda config
  home-manager.useUserPackages = true;  # per-user profile
  home-manager.users.fury = import ./home.nix;
}
```

`home.nix` currently manages: git (user.name/email, settings) + delta
pager. That's it — one real thing, verified working, on purpose.

### The three non-negotiables

1. **Match release branches.** HM `release-26.05` ↔ nixpkgs `nixos-26.05`.
   Mismatched pair = warnings now, breakage later. (We hit this: master
   HM was 26.11 against your 26.05 nixpkgs.)
2. **`inputs.nixpkgs.follows = "nixpkgs"`** so HM builds against the same
   nixpkgs revision as the system. Otherwise two nixpkgs evaluations →
   profile drift and doubled downloads.
3. **`useGlobalPkgs`** so unfree/cuda permission flags apply inside HM
   too.
4. **`home.stateVersion` must be set** (e.g. `home.stateVersion = "26.05";`
   in home.nix) — HM refuses to activate without it; set once, never bump casually.

### NixOS-integrated vs standalone mode

You have **NixOS-integrated**: HM config applies via `nixos-rebuild
switch`, activating `home-manager-fury.service`. No separate
`home-manager switch` command (though the CLI is in systemPackages for
`home-manager build` dry-runs). Everything moves in lockstep — one
flake.lock, one rollback.

Standalone (`homeConfigurations` flake output) is for dotfile repos used
across machines WITHOUT NixOS. Skip it.

### Migrating things in — the safe loop

Move ONE thing per rebuild. Per thing:

1. In `/etc/nixos/home.nix`, add the HM option.
2. Remove the old system-module line (or it will conflict/duplicate).
3. `nix-test` → check it works interactively.
4. Commit: `config-save` alias does `git add . && git commit`.

First candidates, easiest → hardest:
- `programs.zoxide` / `programs.fzf` (replace the `eval "$(zoxide init zsh)"`
  lines in shell.nix's interactiveShellInit)
- `programs.kitty` + your terminal font
- zsh itself: aliases → oh-my-zsh theme/plugins → completions
- user apps out of system-packages.nix

### When HM meets existing dotfiles

HM *takes over* files. If `~/.gitconfig` had been an unmanaged file that
HM wanted to write, it fails unless `home-manager.backupFileExtension`
is set (e.g. `home-manager.backupFileExtension = "hm-backup";` — then
existing files move to `~/.gitconfig.hm-backup`) — check for those
backups after the first switch of each new program, then delete.

### Version notes for your HM 26.05

Option renames already handled in home.nix — these bit us during setup:
- `userName`/`userEmail` → `settings.user.name`/`settings.user.email`
- `extraConfig` → `settings`
- `programs.git.delta` → top-level `programs.delta`

## 7. The Staging Workflow (mock sandbox)

Try risky things in `~/Downloads/newconfigs-nix` first:

```bash
cd ~/Downloads/newconfigs-nix
# port your /etc/nixos change here first, then:
nix flake check                             # parse + option errors
nixos-rebuild build --flake .#nixos         # full eval (result/ appears)
nix store diff-closures /run/current-system ./result
```

Reading the diff:
- **Empty / tiny `system` delta** → identical system, ship it
- **A package vanished** → you lost a setting in the edit — find it
- **Size-only changes** → usually locale/wrapper noise
- **`∅ → ε`** HM plumbing entries → expected when HM manages a new thing

Keep the staging flake.lock copied fresh from `/etc/nixos` before
comparing, so both evaluate the same revisions.

## 8. Daily Commands (your aliases, mapped to the new world)

| Alias | Still works? |
|---|---|
| `nix-test` / `nix-switch` | yes — same flake, now thin entry |
| `config-diff` / `config-status` / `config-log` | yes — and now *useful*, diffs are per-module |
| `config-save` | yes — `git add .` catches new modules |
| `nix-generations` / `nix-rollback` | yes — unchanged |
| `nix-upgrade` | yes — but ALSO updates home-manager with follows |

The one NEW habit: **`git add` before rebuild** (flakes-in-git, §3).

## 9. Rollback Ladder (worst → best)

1. **File level:** restore from `/etc/nixos/config-backup-2026-09-06.tar.gz`
   or `~/nixos-backup-2026-09-06/` (pre-migration monolith)
2. **Git level:** `sudo git -C /etc/nixos log` → `sudo git checkout <sha> -- .`
   → rebuild
3. **Generation level:** `nix-rollback`, or pick a previous generation in
   the boot menu (works even if the config is broken — it's store paths,
   not files)

## 10. Checklist: Adding a New Module

1. Create `modules/<group>/<name>.nix` with the header comment + topic
2. Add to `configuration.nix` imports
3. `sudo git -C /etc/nixos add modules/<group>/<name>.nix` ← before rebuild!
4. `nix-test` → verify interactively
5. `config-save` → commit
6. (risky changes: stage in the sandbox first, §7)

## 11. Future Extensions

- **Options in your own modules:** when two machines share config, make
  modules take `{ config, lib, ... }: with lib; { options.<myhost>.<thing> =
  mkOption ...` and gate differences per-host in flake.nix. The plan doc's
  Phase 2 has the full pattern.
- **sops-nix / agenix** for real secrets (Hermes key, SSH keys) — the
  ai-services.nix header already points there. Full wiring in §12.
- **A second host:** flake.nix gets a second `nixosConfigurations.<name>`
  entry sharing the same modules/ tree with per-host option toggles.
  Full per-host layout (hosts/<name>/) in §12.

## 12. Per-Host Modules, Disko, Impermanence, Secrets, Overlays, devShells

### 12.1 home.stateVersion + backupFileExtension (the two HM one-liners)

```nix
# home.nix — both REQUIRED, set once, never bump casually:
{
  home.stateVersion = "26.05";   # HM's data-version pin (≠ system.stateVersion, same value by convention)
  # Top-level NixOS glue (in configuration.nix or users.nix, NOT home.nix):
  # home-manager.backupFileExtension = "hm-backup";  # HM moves colliding dotfiles to *.hm-backup instead of failing
}
```

Without `home.stateVersion` HM refuses to activate. Without `backupFileExtension` the first switch of any program that owns a dotfile (`~/.gitconfig`) fails if you hand-created it.

### 12.2 Per-host modules (hosts/<name>/ + vendor hardware)

```
flake.nix                  # two nixosConfigurations, shared modules/ + per-host
hosts/
  fury-desktop/            # THIS machine (TU116 NVIDIA, RTL8111, enp5s0)
    default.nix            # imports ../../modules/* + ./hardware.nix
    hardware.nix           # imports ../../modules/hardware/nvidia.nix + realtek-eee.nix
  fury-laptop/             # second machine (AMD iGPU, mt7921 WiFi)
    default.nix
    hardware.nix           # imports ../../modules/hardware/amd.nix (NOT nvidia.nix)
modules/hardware/
  amd.nix intel.nix nvidia.nix   # vendor-split (see plan doc vendor notes)
```

```nix
# flake.nix — per-host selection (shared tree, different entry points):
# nixosConfigurations = {
#   fury-desktop = nixpkgs.lib.nixosSystem {
#     inherit system; specialArgs = { inherit unstablePkgs; };
#     modules = [ ./hosts/fury-desktop/default.nix ];
#   };
#   fury-laptop = nixpkgs.lib.nixosSystem {
#     inherit system; specialArgs = { inherit unstablePkgs; };
#     modules = [ ./hosts/fury-laptop/default.nix ];
#   };
# };
# Rebuild: nixos-rebuild switch --flake /etc/nixos#fury-desktop
```

Rule: `hosts/<name>/hardware.nix` picks the vendor module(s); `modules/hardware/*` never imports each other. CPU/GPU selection = one import line per host.

### 12.3 Disko (declarative disks — new machines / reinstalls only)

```nix
# hosts/fury-laptop/disko.nix (example — ADAPT UUIDs/sizes, never copy blindly):
# { disko.devices.disk.main = {
#     type = "disk"; device = "/dev/nvme0n1";
#     content = {
#       type = "gpt";
#       partitions = {
#         ESP = { size = "512M"; type = "EF00"; content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; }; };
#         root = { size = "100%"; content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; }; };
#       };
#     };
#   };
# };
# Inputs: disko.url = "github:nix-community/disko"; + disko.nixosModules.disko in modules.
# WARNING: `disko` FORMATS on install (`nixos-install` / disko-install) — never add to an
# existing booted host's imports unless you want a wiped disk. Keep it host-local under hosts/.
```

### 12.4 Impermanence (opt-in stateless root)

```nix
# Impermanence = / is tmpfs, only listed paths persist (opt-in per host):
# inputs.impermanence.url = "github:nix-community/impermanence";
# hosts/<name>/persistence.nix:
# { environment.persistence."/persist" = {
#     hideMounts = true;
#     directories = [ "/etc/nixos" "/var/lib/nixos" "/var/log" ];
#     files = [ "/etc/machine-id" ];
#   };
#   # HM side: home.persistence."/persist/home/fury" = { directories = [ "Documents" ".ssh" ]; };
# }
# Start ONLY with /etc/nixos + /var/lib/sops-nix persisted; grow the list from
# `find / -newer /persist/.marker` after each reboot. NOT for your daily driver until tested in a VM.
```

### 12.5 Secrets wiring (sops-nix / agenix — copy-pasteable)

```nix
# flake.nix inputs: sops-nix.url = "github:Mic92/sops-nix"; + sops-nix.nixosModules.sops in modules.
# { config, ... }: {
#   sops.defaultSopsFile = ../secrets/secrets.yaml;   # ENCRYPTED file, committed
#   sops.age.keyFile = "/var/lib/sops-nix/key.txt";    # plaintext key, NEVER committed
#   sops.secrets."wg-private" = { };                   # → /run/secrets/wg-private (tmpfs)
#   sops.secrets."hermes-env" = { owner = "hermes"; }; # service env file
# }
# Consume: privateKeyFile = config.sops.secrets."wg-private".path;
# agenix equivalent: age.secrets."wg-private".file = ../secrets/wg-private.age;
# See git guide §14 (.sops.yaml policy, updatekeys, verify) + Secrets-Management-NixOS.md.
```

### 12.6 Overlays dir

```
overlays/
  default.nix      # import list: [ (import ./cuda-pin.nix) (import ./my-tools.nix) ]
  cuda-pin.nix     # final: prev: { ... } — one concern per file
```

```nix
# overlays/default.nix: [ (import ./cuda-pin.nix) ]
# Wiring (inside any module or flake pkgs import):
# { nixpkgs.overlays = [ (import ../overlays/default.nix) ]; }
# Rule: overlays are GLOBAL (every pkgs consumer sees them) — keep them minimal,
# version-pinned, and out of hosts/ (hosts pick modules, overlays patch pkgs).
```

### 12.7 devShells (per-project envs, flake output — not system config)

```nix
# flake.nix outputs: perSystem or legacy devShells.x86_64-linux.default:
# devShells.x86_64-linux.default = pkgs.mkShell {
#   buildInputs = with pkgs; [ nil nixd nixfmt git gh ];
#   shellHook = ''eval "$(direnv hook bash)"'';
# };
# Enter: `nix develop` (flake dir) — pairs with programs.direnv + nix-direnv (§shell.nix).
# Keep TOOLCHAIN shells here (per-repo), SYSTEM tools in modules/packages/.
```
