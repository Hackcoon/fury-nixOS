# Backup Sync Bible (fury) — instructions for any AI agent

> Last updated: 2026-09-13.
> Purpose: keep `~/nixos-backups/` an exact, restorable mirror of the live configs.
> When the user says "sync the backups" (or asks if backups are current), follow this file top to bottom.

## The pairs (live → backup)

| Live source | Backup dest | Notes |
|---|---|---|
| `~/.config/mango/` | `app-configs/mango-2026-09-13/` | MangoWC + scripts + `dms/` fragments |
| `~/.config/DankMaterialShell/` | `app-configs/DankMaterialShell-2026-09-13/` | Settings, themes, plugins |
| `~/.config/suckless/` | `app-configs/suckless-2026-09-13/` | dwm, sxhkd, scripts, rofi, built binaries |
| `~/.config/hypr/` | `app-configs/hypr-2026-09-13/` | Hyprland config |
| `~/.config/kitty/` | `app-configs/kitty-2026-09-13/` | Read by mango's kitty; dwm uses `suckless/kitty` |
| `~/.config/rofi/` | `app-configs/rofi-2026-09-13/` | Used by aliases menu, dwm helpers |
| `~/.config/dunst/` | `app-configs/dunst-2026-09-13/` | Standalone dunst (mango side) |
| `~/.config/waybar/` | `app-configs/waybar-2026-09-13/` | |
| `~/.config/vicinae/` | `app-configs/vicinae-2026-09-13/` | Launcher |
| `~/.config/flameshot/` | `app-configs/flameshot-2026-09-13/` | dwm screenshots |
| `~/.config/systemd/` | `app-configs/systemd-2026-09-13/` | `mango-session.target`, DMS gate |
| `~/.local/bin/` | `app-configs/local-bin-2026-09-13/` | `brave-fast`, built dwm/st/slstatus/tabbed |
| `~/.local/share/applications/` | `app-configs/local-applications-2026-09-13/` | Custom launchers, `mimeapps.list` |
| `~/.Xresources` `~/.fehbg` `~/.zshrc` | `app-configs/dotfiles-2026-09-13/` | Tiny home-root dotfiles |
| `/etc/nixos/` | `nixos-config-2026-09-13/` | System flake (incl. `.git`); **exclude `result` symlink** |
| Hotkey docs | `mango-ultimate-hotkeys.md`, `dwm-ultimate-hotkeys.md` | Living docs with appendices (see their AI rules) |

Unmanaged (do not touch): `nixos-backup-2026-09-06/` (stale archive), `kde backups/` (single color file), `app-configs/gimp/` (manual tarball).

Deliberately excluded: `~/Pictures/wallpapers` (1.8G images; settings referencing them ARE backed up), `~/fury-dwm` (project repo; sources already inside `suckless` copy), `~/.nix-profile` (imperative installs; system packages come from `/etc/nixos`).

## Verify (read-only, always first)

```sh
diff -rq ~/.config/mango ~/nixos-backups/app-configs/mango-2026-09-13
diff -rq ~/.config/DankMaterialShell ~/nixos-backups/app-configs/DankMaterialShell-2026-09-13
diff -rq ~/.config/suckless ~/nixos-backups/app-configs/suckless-2026-09-13
diff -rq ~/.config/hypr ~/nixos-backups/app-configs/hypr-2026-09-13
for d in kitty rofi dunst waybar vicinae flameshot; do diff -rq ~/.config/$d ~/nixos-backups/app-configs/$d-2026-09-13; done
diff -rq ~/.local/bin ~/nixos-backups/app-configs/local-bin-2026-09-13
diff -rq ~/.local/share/applications ~/nixos-backups/app-configs/local-applications-2026-09-13
diff -rq ~/.config/systemd ~/nixos-backups/app-configs/systemd-2026-09-13
for f in .Xresources .fehbg .zshrc; do cmp -s ~/$f ~/nixos-backups/app-configs/dotfiles-2026-09-13/$f || echo "DIFFERS: $f"; done
diff -rq /etc/nixos ~/nixos-backups/nixos-config-2026-09-13 | grep -v "Only in /etc/nixos: result"
```

No output = in sync. Any output = stale, refresh per below.

## Refresh (when stale)

1. Verify first (above) so you only touch what drifted.
2. Refresh by full re-copy (never patch backup dirs in place):
   `cp -a <live> <dest>` — delete the stale dest dir first if it exists.
   New snapshots get today's date (`-YYYY-MM-DD`) and this table gets updated to point at them.
3. `/etc/nixos`: `cp -a /etc/nixos <dest> && rm -f <dest>/result` (drop the `result` symlink).
4. Re-run Verify until silent.
5. Validation after any live-config change (before backing up):
   - mango: `mango -p -c ~/.config/mango/config.conf` → exit 0, silent.
   - nixos: `nix-instantiate --parse <edited .nix>` at minimum.
   - hotkey docs: follow their own AI-rules sections (tables + appendix + changelog + date).

## Rules

1. Backups are mirrors, never sources of truth — edits go to live configs first, then sync here.
2. `cp -a` (preserve modes/symlinks). Never `mv` live data.
3. Never store secrets: if a config gains tokens/keys, exclude that file and note it here.
4. Dated dirs are immutable across days — same-day refreshes may update in place; a new day gets a NEW dated dir and this table is updated. Prune old ones only when asked.
5. `DankMaterialShell/settings.json` is runtime-mutable (DMS rewrites it live) — expect it to drift often; refresh as-is, never hand-edit it.
6. After any sync, update `Last updated` at top and add a Changelog entry.
7. Report per-pair IDENTICAL-or-refreshed, plus validation results.

## Changelog

- 2026-09-13: created. Covers all 15 pairs; everything verified IDENTICAL same-day.
- 2026-09-13: first live run caught 2 real drifts — mango backup predated the `SUPER+K` bind, and DMS had runtime-rewritten `settings.json` (dropped `runUserMatugenTemplates`). Both refreshed; added rules 4–5.
