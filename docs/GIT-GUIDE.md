# Git Guide — mango / dwm / hyprland / nixos configs (fury)

> Last updated: 2026-09-13.
> One repo per config folder. Uses the shell aliases in `/etc/nixos/modules/programs/shell.nix`
> (rebuild + `exec zsh` — or `sz` — after changing them).

## 0. New aliases (already added to `shell.nix`)

| Alias | Does |
|---|---|
| `mango-status` / `mango-save` | status / add-all + commit for `~/.config/mango` |
| `dwm-status` / `dwm-save` | status / add-all + commit for `~/.config/suckless` |
| `hypr-status` / `hypr-save` | status / add-all + commit for `~/.config/hypr` |
| `config-status` / `config-save` | existing: same for `/etc/nixos` (with sudo) |
| `config-savem "msg"` | stage-all + commit with inline message |
| `config-stage <paths>` + `config-commitm "msg"` | focused commits: stage only chosen files |
| `config-diff` / `config-log` | existing: review nixos diffs / recent commits |

All `-save` variants run `git commit` with no `-m`, so the editor prompts for a message.

## 1. NixOS config — already a repo, commit what's pending

```sh
config-status
config-diff
nix-test
config-save
config-log
```

Workflow forever: edit → `nix-test` → `config-save`.

## 2. Mango — init once

```sh
cd ~/.config/mango
git init -b master
cat > .gitignore <<'EOF'
*.backup*
*.dmsbackup*
config.conf.with-dragswap
config.conf.pre-dragswap-*
EOF
mango -p -c ~/.config/mango/config.conf   # must exit 0 silent before first commit
git add -A && git commit -m "mango config initial snapshot"
```

Workflow after: edit `config.conf` → `mango -p` → `mango-save`.

Note: `settings.json` is runtime-mutable (DMS rewrites it live). Keep it tracked, but only
commit when the diff is meaningful — ignore churn.

## 3. DWM/suckless — init once

Sources matter, build outputs don't:

```sh
cd ~/.config/suckless
git init -b master
cat > .gitignore <<'EOF'
*.o
dwm/dwm
dwm/dwmtabs
st/st
slstatus/slstatus
tabbed/tabbed
tabbed/xembed
EOF
git add -A && git commit -m "suckless initial snapshot"
```

Workflow after: edit `config.def.h` → `make && sudo make install` → `Super+Shift+r`
→ `dwm-save`. (`sxhkdrc` edits only need `Super+Escape`, then `dwm-save`.)

## 4. Hyprland — init later (optional, when you want it)

```sh
cd ~/.config/hypr
git init -b master
git add -A && git commit -m "hyprland initial snapshot"
```

Then: edit → `hypr-save`. (Add a `.gitignore` first if the folder has logs/caches.)

## 5. Off-machine backup (recommended)

No remotes exist yet (`git remote -v` is empty). At minimum for `/etc/nixos`:

```sh
cden
sudo git remote add origin git@github.com:<you>/nixos-config.git
sudo git push -u origin master
```

Same pattern (without sudo) for mango/suckless/hypr into private repos.

## 6. How this relates to `~/nixos-backups`

Git = history + diffs. `nixos-backups/` = full-folder snapshots (built binaries, `.git`
dirs themselves, wallpaper refs, system tarballs). They complement each other —
see `AI-SYNC-BIBLE.md` for the backup side.

## Changelog

- 2026-09-13: created (repos: nixos existing; mango/suckless/hypr init steps; 6 new aliases).
