# DMS Version Upgrade Guide (NixOS Flake + `nh`)

How to move DankMaterialShell to a new upstream tag on this system.
DMS is pinned by tag in the system flake and rebuilt with `nh`.

## 0. How versioning works here

* Pin: `/etc/nixos/flake.nix` — `dms.url = "github:AvengeMedia/DankMaterialShell/vX.Y.Z"`
* Lock: `/etc/nixos/flake.lock` — records the exact commit for that tag.
* Module: `dms.nixosModules.dank-material-shell` (the `programs.dank-material-shell` option).
* `nixpkgs` only carries an older DMS, so the flake input is the source of truth.

Important: changing the tag in `flake.nix` is what selects the new version.
`nix flake update` / `nh --update` only refresh the lock for the tag that is
already written down. To get a new release you always edit `flake.nix` first.

## 1. Pick a target version

1. Read the release notes:
   `https://github.com/AvengeMedia/DankMaterialShell/releases`
   Check for breaking / packaging changes (new build tags, renamed modules,
   split packages such as `dank-greeter`, new dependencies).
2. List recent tags:
   ```bash
   gh api 'repos/AvengeMedia/DankMaterialShell/tags?per_page=10' \
     --jq '.[].name'
   ```
3. Decide patch vs minor:
   * Patch (`1.6.0` -> `1.6.1`): safe to take promptly.
   * Minor/major (`1.6` -> `1.7`): read the announcement post and the
     `Package Maintainers` section before touching anything.

## 2. Aliases used in this guide

Defined in `/etc/nixos/modules/programs/shell.nix` under `shellAliases`.
`programs.nh.flake = "/etc/nixos"` is set in `/etc/nixos/modules/core/nix.nix`,
so the explicit `/etc/nixos` argument below can be omitted if preferred.

| Alias | Command | Purpose |
|---|---|---|
| `cden` | `cd /etc/nixos` | go to system config |
| `nix-track` | `git -C /etc/nixos add -A` | stage edits so the flake can see them |
| `config-diff` / `config-status` | `git diff` / `git status` in `/etc/nixos` | review changes |
| `nh-test` | `nh os test /etc/nixos` | build and activate temporarily (no boot entry) |
| `nh-os` | `nh os switch /etc/nixos` | build and activate permanently |
| `nh-boot` | `nh os boot /etc/nixos` | build and stage for next boot only |
| `nh-build` | `nh os build /etc/nixos` | build without activating |
| `nh-up-input <name>` | `nh os switch /etc/nixos --update-input <name>` | refresh one locked input and switch |
| `nh-upgrade` | `nh os switch /etc/nixos --update` | refresh ALL inputs and switch (heavy) |
| `nh-info` / `nh-rollback` | `nh os info` / `nh os rollback` | list generations / roll back |

Rule of thumb: use `nh-os` for a DMS version bump. Use `nh-upgrade` only when
you intentionally want new `nixpkgs`, kernel, drivers, and everything else too.

## 3. Upgrade procedure

```bash
cden

# 1. Check current pin and lock
rg -n 'DankMaterialShell/v' flake.nix
nix flake metadata --json | python3 -c \
  "import json,sys; d=json.load(sys.stdin); \
   n=d['locks']['nodes']['dms']; \
   print('tag:', n['original'].get('ref')); \
   print('rev:', n['locked']['rev'])"

# 2. Edit the tag, e.g. v1.6.0 -> v1.6.1
$EDITOR flake.nix
#   dms = {
#     url = "github:AvengeMedia/DankMaterialShell/v1.6.1";
#     inputs.nixpkgs.follows = "nixpkgs-unstable";
#   };

# 3. Refresh only the dms lock entry
nix flake lock --update-input dms

# 4. Confirm the lock moved to the new tag's commit
nix flake metadata --json | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(d['locks']['nodes']['dms'])"

# 5. Review exactly what changed
git -C /etc/nixos diff -- flake.nix flake.lock

# 6. Stage the change (flakes ignore untracked files)
git -C /etc/nixos add -A

# 7. Test before committing to it
nh-test

# 8. If test looks good, activate permanently
nh-os
```

## 4. Verify the new shell

```bash
nh-info
systemctl --user status dms
journalctl --user -b -u dms --no-pager | tail -n 50
```

Then log out / restart DMS from within the shell if prompted, and open
Settings to confirm new options appear. If the release notes mention plugin
API changes, update plugins as well.

Save the working config:

```bash
git -C /etc/nixos add -A
git -C /etc/nixos commit -m "dms: bump to vX.Y.Z"
```

## 5. Troubleshooting

### Build fails: `hash mismatch in ...-go-modules.drv`

The tag shipped with a stale Go `vendorHash` (upstream tagged before running
their `nix: update vendorHash` commit). This is an upstream packaging bug,
not a config error.

```text
error: hash mismatch in fixed-output derivation '...-dms-shell-...-go-modules.drv':
  specified: sha256-AAAA...
  got:       sha256-BBBB...
```

What to do:

1. Do not force the build. Revert `flake.nix` to the previous tag and
   re-run `nix flake lock --update-input dms` so `git status` is clean.
2. Check whether upstream fixed it on `master`:
   ```bash
   gh api 'repos/AvengeMedia/DankMaterialShell/commits?per_page=10&path=flake.nix' \
     --jq '.[] | .sha[0:7] + " " + (.commit.author.date|split("T")[0]) + " " + (.commit.message|split("\n")[0])'
   ```
   If a newer `nix: update vendorHash` commit exists but no new tag yet,
   wait for the next tag.
3. Only track `master` (`url = ".../master"`) for a temporary test build.
   It moves with every upstream commit, so pin back to a tag afterwards.

### `warning: Git tree '/etc/nixos' is dirty`

Normal when `flake.nix` / `flake.lock` have uncommitted edits. Tracked-file
edits still evaluate. Untracked new files are invisible to the flake until
you run `git add`. Always `git add -A` before `nh-test` / `nh-os` when you
add new modules or packages.

### `git add` fails: `insufficient permission ... .git/objects`

Some object directories under `/etc/nixos/.git/objects` are root-owned.
One-time fix from an interactive shell:

```bash
sudo chown -R "$(id -un)":"$(id -gn)" /etc/nixos/.git/objects
```

### Rebuild asks for a password / hangs on activation

`nh os test` and `nh os switch` activate the system and need privilege
escalation at the end even though the build itself runs as your user.
Run them from an interactive terminal. Builds are throttled on this machine
(`cores = 2`, `max-jobs = 1`), so allow several minutes for the DMS Go build.

## 6. Rollback

If the new version misbehaves:

```bash
nh-rollback
# or: sudo nixos-rebuild switch --rollback
nh-info
```

Then set `flake.nix` back to the previous tag, refresh the lock
(`nix flake lock --update-input dms`), verify with `git diff`, and `nh-os`
again to return the config to a known-good state.
