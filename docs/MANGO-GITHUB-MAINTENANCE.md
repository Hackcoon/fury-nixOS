# Mango Config on GitHub — What Was Done + How to Maintain It

> Date: 2026-09-15. Author: opencode session with fury.
> Repos: `Hackcoon/mango-config` (new, standalone) + `Hackcoon/fury-nixOS` (existing, links mango as submodule).
> This supersedes the 2026-09-13 `GIT-GUIDE.md` §2/§5 plan (git-init inside `~/.config/mango` with no remote) — that was never executed. The design below is what actually shipped.

## 1. What was done

You asked: "put my mango config also on github, can I do both options [same repo + separate repo]?"

Answer implemented: **both, via submodule.**

1. Staged `~/mango-config/` from live files (no secrets found, 132K):
   - `mango/config.conf`, `media.conf`, `*.sh` (chmod +x) from `~/.config/mango/`
   - `mango/dms/*.conf` from `~/.config/mango/dms/`
   - `dms/settings.json`, `dms/plugins.lock.json`, `dms/amoledBlack/` from `~/.config/DankMaterialShell/`
   - `mango-session.target` from `~/.config/systemd/user/`
   - docs: `mango-dms-hotkeys.md`, `mango-dms-nixos-guide.md`, plus `CHEATSHEET-AI-GUIDE.md`, `KEYBIND-PORT.md`, etc. from `~/.config/mango/`
   - Deliberately excluded: `*.backup*`, `*.dmsbackup*`, `*.pre-*`, `*.with-dragswap`, `*.tar.gz`, `screenshot.png`, and `plugins/mangoWmLayoutManager/` (it has its own upstream `.git` — tracked via `plugins.lock.json` instead).
2. `git init -b main`, commit `aad2a17 "Initial mango + DMS config"` (27 files), `gh repo create Hackcoon/mango-config --public --source=. --push`.
   - Live at: https://github.com/Hackcoon/mango-config
   - Local clone: `~/mango-config/` (tracks `origin/main`).
3. Linked into NixOS flake repo:
   - `git -C /etc/nixos submodule add https://github.com/Hackcoon/mango-config.git dotfiles/mango`
   - This stages `.gitmodules` + `dotfiles/mango` gitlink. **Commit is still pending** (see §4).

Layout mapping (repo → live):

| Repo path | Restores to |
|---|---|
| `mango/` | `~/.config/mango/` |
| `dms/settings.json`, `dms/plugins.lock.json` | `~/.config/DankMaterialShell/` |
| `dms/amoledBlack/` | `~/.config/DankMaterialShell/themes/` |
| `mango-session.target` | `~/.config/systemd/user/` |

## 2. Finish the pending submodule commit (one time, your terminal)

The agent could not commit in `/etc/nixos`: some `.git/objects/` subdirs are `root:root` (from `sudo nixos-rebuild`), and the sandbox has no sudo password. Run:

```bash
cd /etc/nixos
git status --short   # expect: A .gitmodules, A dotfiles/mango
sudo chown -R fury:users .git
git commit -m "Add mango-config as submodule at dotfiles/mango"
git push
git submodule status  # should show the mango commit hash
```

## 3. Daily maintenance

### Mango keybinds / scripts change (most common)

```bash
mango -p -c ~/.config/mango/config.conf   # must exit 0 silent — mango ignores invalid edits live
cd ~/mango-config
cp ~/.config/mango/config.conf mango/
cp ~/.config/mango/media.conf mango/ 2>/dev/null
cp ~/.config/mango/*.sh mango/; chmod +x mango/*.sh
cp ~/.config/mango/dms/*.conf mango/dms/
git add -u
git status --short; git diff --stat
git commit -m "mango: describe what changed"
git push
# then bump the pointer in fury-nixOS so history stays together:
cd /etc/nixos && git -C dotfiles/mango pull --ff-only && git add dotfiles/mango && git commit -m "bump mango-config" && git push
```

### DMS settings / theme change

`settings.json` is runtime-mutable (DMS rewrites it live) — expect churn, only commit meaningful diffs:

```bash
cd ~/mango-config
cp ~/.config/DankMaterialShell/settings.json dms/
cp ~/.config/DankMaterialShell/plugins.lock.json dms/ 2>/dev/null
# only if you changed the theme:
cp -r ~/.config/DankMaterialShell/themes/amoledBlack dms/
git diff -- dms/settings.json   # review — skip if just timestamps/churn
git add -u && git commit -m "dms: describe change" && git push
```

### NixOS system change (unchanged workflow)

```bash
config-status
config-diff
nix-test   # sudo nixos-rebuild test --flake /etc/nixos#nixos
config-save
```

### Cloning on a new machine

```bash
git clone --recurse-submodules https://github.com/Hackcoon/fury-nixOS.git /etc/nixos
git clone https://github.com/Hackcoon/mango-config.git ~/mango-config
cp -r ~/mango-config/mango ~/.config/
cp ~/mango-config/dms/settings.json ~/mango-config/dms/plugins.lock.json ~/.config/DankMaterialShell/
cp -r ~/mango-config/dms/amoledBlack ~/.config/DankMaterialShell/themes/
cp ~/mango-config/mango-session.target ~/.config/systemd/user/
chmod +x ~/.config/mango/*.sh
mango -p -c ~/.config/mango/config.conf
systemctl --user daemon-reload
```

Full system side (flake inputs, greeter, portals) is in `mango-dms-nixos-guide.md` inside the mango-config repo.

## 4. Troubleshooting

- `error: insufficient permission for adding an object to repository database .git/objects` in `/etc/nixos` → root-owned objects from sudo rebuilds. Fix: `sudo chown -R fury:users /etc/nixos/.git`, then retry. Recurs whenever you `sudo git` or `sudo nixos-rebuild` creates new objects — just re-chown.
- `mango -p` prints errors → fix `config.conf` before committing; mango keeps last-good config live.
- Submodule shows dirty/modified pointer after a mango push → expected; run the bump line in §3 to pin the new hash in fury-nixOS.
- `~/nixos-backups/` vs git: git = history + diffs + restore scripts; `nixos-backups/app-configs/mango-*` + `DankMaterialShell-*` = full-folder snapshots (binaries, `.git` dirs, wallpaper refs). Keep both — edit live configs first, commit to git, then sync backups per `AI-SYNC-BIBLE.md`.

## Changelog

- 2026-09-15: created. Shipped `Hackcoon/mango-config` (aad2a17, 27 files) + staged `dotfiles/mango` submodule in fury-nixOS (commit pending, §2).
