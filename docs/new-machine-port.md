# New-machine port — manual dotfiles

Copies live in `dotfiles/` (tracked). Nothing here auto-deploys; place by hand.
After the base flake is up (`configuration.nix` + fresh `hardware-configuration.nix`),
copy each file to its path below, then log out/in (kitty/vicinae) or just run it (fastfetch).

## 1. Kitty (static pinned-black fallback)

- Source: `dotfiles/kitty/kitty-pinned-black.conf`
- Place at: `~/.config/kitty/kitty.conf` (backup the existing one first)
- Note: fully self-contained — Catppuccin Mocha inlined, background pinned
  `#000000` last so it wins. No `/nix/store` paths, no wallust dependency.
- On the main machine kitty is Home-Manager-managed with a wallust overlay;
  this copy is the fallback that always looks right. If you adopt HM kitty on
  the new box too, you don't need this file at all.

## 2. Vicinae theme

- Source: `dotfiles/vicinae/monochrome-fury.toml`
- Place at: `~/.local/share/vicinae/themes/monochrome-fury.toml`
  (`mkdir -p ~/.local/share/vicinae/themes` first)
- Select inside Vicinae: Settings → Theme → monochrome-fury.
- Requires the `vicinae` package (already in the flake's launcher stack).

## 3. Fastfetch

- Source: `dotfiles/fastfetch/config.jsonc` + `dotfiles/fastfetch/goated_4k.png`
- Place at: `~/.config/fastfetch/config.jsonc`
  (`mkdir -p ~/.config/fastfetch` first)
- The config shows `~/Pictures/goated_4k.png` as its logo image (line 5,
  `"source"`). Copy `goated_4k.png` to `~/Pictures/` verbatim, or edit that
  line to point at any image you like.
- Requires the `fastfetch` package.

## Deliberately NOT here

- **quickshell fury-bar** — skipped by owner decision (2026-10-11).
- **Wallpapers** (`~/Pictures`, 1.9G) — too big for git; re-download per machine.
- **Kokoro voices/venv, parakeet models** — re-download; see module docs.
- **Secrets, `hardware-configuration.nix`** — manual transfer / regenerate, never git.
