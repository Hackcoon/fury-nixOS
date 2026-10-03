# fury-nixOS — modular NixOS flake for three machines

One repo drives a desktop, a laptop, and a future AMD box. `configuration.nix`
is a thin entry point: an annotated imports list plus per-machine option flips.
Everything real lives in `modules/`. Comment style and rules:
`docs/module-style-guide.md`.

## Machines

| Machine | Hardware | State |
|---|---|---|
| Desktop | GTX 1660 SUPER, Ryzen 5 3600, ext4 | Active |
| Laptop | i7-10750H + GTX 1660 Ti Mobile (hybrid Optimus) | Commented blocks, fresh install |
| AMD PC | Ryzen 7 7700 + RX 7800 XT (RDNA3) | Commented blocks, future build |

`hardware-configuration.nix` is tracked once as a working example (UUIDs and
module lists are not secrets). Per-machine regens stay uncommitted (ignored
after the first commit) — always regenerate on a new install, never copy.

## Install on a new machine

1. Install stock NixOS (minimal ISO is fine), boot the installed system.
2. Replace the default config with this repo (keeps nothing but the hardware file):
   ```sh
   sudo mv /etc/nixos /etc/nixos-backup
   sudo git clone https://github.com/Hackcoon/fury-nixOS.git /etc/nixos
   ```
3. Generate this machine's hardware file (never copy one from another box):
   ```sh
   sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix > /dev/null
   ```
4. Edit `/etc/nixos/configuration.nix`, exactly one machine section ON:
   - **This desktop:** `hardware-profiles.nvidia.enable = true` (already the default).
   - **Laptop:** that to `false`, uncomment the LAPTOP block
     (`nvidia-prime` + BusIDs from `lspci | grep -E "VGA|3D"`,
     `intel.enable`, `laptop.enable`, `laptop.powerMode`), comment out
     `./modules/hardware/nvidia.nix` in imports.
   - **AMD PC:** `nvidia.enable = false`, comment out `nvidia.nix`,
     uncomment the AMD PC block (`amd-gpu.enable`).
5. First build (staging new files so the flake can see them happens automatically
   on later runs via the `nix-track` alias — for the very first build run it by hand):
   ```sh
   cd /etc/nixos && sudo git add -A   # flakes ignore untracked files
   sudo nixos-rebuild switch --flake /etc/nixos#nixos
   ```

Optional quality-of-life: make `/etc/nixos` user-writable to avoid sudo on
every edit — `sudo chown -R $(whoami):users /etc/nixos` (root keeps
`hardware-configuration.nix` and `/etc/secureboot` regardless).

## Everyday use

- Rebuild: `nix-switch` (permanent) after `nix-test` (trial run). Full alias
  list in `modules/programs/shell.nix` — classic and `nh` variants.
- DNS: `dns.provider` flips quad9/cloudflare/google/opendns/native (see the
  DNS banner in `configuration.nix` for portal/VPN and max-privacy recipes).
- Laptop GPU: `nvidia-offload <app>` runs one app on the 1660 Ti;
  `nvidia-prime.mode = "sync"` makes it render everything (plugged-in only).
- Laptop power: `laptop.powerMode = powersave | balanced | performance`.
- Rollback: every build is a boot generation; `nix-rollback` / `nh-rollback`
  revert. Btrfs snapshots (opt-in `btrfs-root`) add file-level undo.

## Layout

```
flake.nix               # inputs + nixosConfigurations.nixos
configuration.nix       # imports + per-machine flips (annotated)
hardware-configuration.nix  # generated per machine; repo copy is an example, regens stay local
home.nix                # Home Manager user config
modules/core/           # boot, nix, locale, network, dns, default-apps,
                        #   appimage, flatpak, fonts
modules/hardware/      # nvidia, amdgpu, audio, ssd, laptop, power-modes,
                        #   hardware-profiles, razer, realtek-eee
modules/desktop/        # kde, hyprland, mango-dms, fury-dwm, xfce-chicago95,
                        #   qylock, themes, portals
modules/programs/       # shell, gaming, virtualisation, thunar, firefox, zen
modules/ai/             # ai-services, ai-stt, ai-tts, ai-ocr, comfyui (HEAVY)
modules/services/       # printing, searxng, blocky
modules/system/         # desktop-extras, btrfs
modules/users/          # user fury
modules/packages/       # system-packages, brave-webgpu, brave-fast, apps-fixed
modules/unused/        # retired modules (uncomment to revive)
pkgs/                   # custom derivations (tolaria, recordly, openwolf)
docs/                   # guides + module-style-guide.md
```

Import tags in `configuration.nix`: `KEEP MINIMAL` (never drop),
`OPTIONAL`, `HEAVY` (build cost), `MACHINE-SPECIFIC`.
