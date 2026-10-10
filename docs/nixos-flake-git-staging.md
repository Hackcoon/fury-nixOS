# Why NixOS Flakes Need `git add` for New Files

## Short answer
Yes. If you create a **new** `.nix` file under `/etc/nixos`, you must `git add` it once before `nixos-rebuild` can see it.

Edited files work without staging. New files do not.

## Why
`flake.nix` puts Nix in flake mode. Flakes evaluate the **git tree**, not the working directory.

- Modified tracked file: included, with warning `Git tree '/etc/nixos' is dirty`
- New untracked file: invisible to Nix, rebuild fails with `Path '...' is not tracked by Git`

That is exactly what happened with `modules/core/dns.nix`.

## What to run
```bash
git -C /etc/nixos status --short
git -C /etc/nixos add modules/core/dns.nix
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Do this once per new file. Edits after that need no `add`.

## Useful variants
```bash
git -C /etc/nixos add -N modules/core/dns.nix
git -C /etc/nixos add -A
```

`-N` is intent-to-add: makes empty placeholder visible without staging content. `-A` stages everything.

## Dirty warning
`warning: Git tree '/etc/nixos' is dirty` is normal. It means tracked files have uncommitted changes. Rebuild still uses your current working files.

Commit when stable, ignore while experimenting:

```bash
git -C /etc/nixos commit -m "dns provider flag"
```
