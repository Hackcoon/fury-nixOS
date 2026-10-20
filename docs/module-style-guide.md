# NixOS Config Structure & Style Guide

> Give this file to any AI working in `/etc/nixos` so it keeps the layout,
> commenting system, and rules below. Human is `fury`; verify every change
> with the commands at the bottom.

## Machines (one repo, three targets)

| Machine | Hardware | Status |
|---|---|---|
| Desktop (this box) | GTX 1660 SUPER, Ryzen 5 3600, ext4 | Active config |
| Laptop | i7-10750H + GTX 1660 Ti Mobile (hybrid Optimus) | Commented blocks, fresh install pending |
| AMD PC | Ryzen 7 7700 + RX 7800 XT (RDNA3) | Commented blocks, future machine |

Per-machine flips live in `configuration.nix` banner sections (DNS,
hardware-profiles DESKTOP, laptop, AMD PC, OTHER MACHINES). Never copy
`hardware-configuration.nix` between machines — regenerate it per install.

## Repo layout

```
flake.nix               # inputs (nixpkgs 26.05, unstable, lanzaboote, DMS,
                        #   zen, comfyui-nix, home-manager...) + nixosConfigurations
configuration.nix       # THIN entry point: imports list + per-machine option flips.
                        # No logic — only wiring. Annotated KEEP/OPTIONAL/HEAVY.
hardware-configuration.nix  # GENERATED per machine. Do not hand-edit, do not copy.
home.nix                # Home Manager (user dotfiles: git, kitty, btop, zen...).
modules/core/           # boot, nix, locale, network, dns, default-apps, appimage,
                        #   flatpak, fonts — keep all (app runtimes + type are fundamentals)
modules/hardware/      # nvidia (desktop), amdgpu (AMD PC), audio, ssd, laptop,
                        #   power-modes, hardware-profiles, razer, realtek-eee
modules/desktop/        # kde, hyprland, mango-dms, fury-dwm, xfce-chicago95,
                        #   qylock, themes, portals
modules/programs/       # shell, gaming, virtualisation, thunar,
                        #   firefox, zen (parked)
modules/ai/             # ai-services, ai-stt, ai-tts, ai-ocr, comfyui — ALL HEAVY
modules/services/       # printing, searxng, blocky
modules/system/         # desktop-extras (all-off toggles), btrfs (opt-in)
modules/users/          # user fury
modules/packages/       # system-packages (~150 pkgs), brave-webgpu, brave-fast,
                        #   apps-fixed (X11 wrappers)
modules/unused/        # Parked modules (e.g. tide-island). Not deleted.
pkgs/                   # Custom callPackage derivations (tolaria, recordly, openwolf)
docs/                   # Guides (this file lives here)
```

## Import tags (configuration.nix only)

Every import line carries one: `KEEP MINIMAL` (boot/login/network — never
drop), `OPTIONAL` (safe to drop), `HEAVY` (big build cost: CUDA/AI, gaming,
VMs, extra DEs, custom browser builds), `MACHINE-SPECIFIC` (don't blindly
copy to another box). Original descriptive comments are preserved AFTER `//`.

## Comment system (the important part)

```
# ============================================================================
# FILE HEADER — name + what the file is, closed top AND bottom
# ============================================================================

  # ── Snippet title ──
  # What this snippet does and why (detached notes live HERE, above).
  <code, with per-setting whys kept INLINE at their setting>
  # ----------------------------------------------------------------------
```

Rules:

1. **Title (`──`) + explanation above the snippet, closing `---` after it.**
   No opener divider between a title and its own code — the closer alone
   separates blocks.
2. **Frame snippets, not lines.** Sub-groups inside one snippet keep small
   `──`/`----` landmarks; they don't get full frames.
3. **Preserve inline per-setting comments.** Never consolidate them upward
   unasked. Consolidate upward ONLY when told (e.g. generated-file text).
4. **Generated strings stay clean.** Everything inside `''` lands verbatim in
   a store file (and changes the system drv hash). Explanations go in Nix
   comments above; the string keeps settings + in-file toggles only.
5. **Section banners in configuration.nix** use `# ===...===` blocks:
   DNS, hardware-profiles DESKTOP, laptop, AMD PC, OTHER MACHINES,
   DESKTOP EXTRAS, BTRFS, AI, plus the imports list and an UNUSED MODULES
   block at the end.
6. **Retired modules** move to `modules/unused/` + one commented line in the
   UNUSED MODULES block. Same depth keeps `../../` references resolving.
7. **No external-provenance mentions.** Reads as the owner's implementation.

## Module design rules

- New hardware/feature modules are **gated** (`mkEnableOption`, inert until
  enabled) so importing is harmless on all machines. Exception: `nvidia.nix`
  is UNCONDITIONAL — it must be commented out of imports on non-NVIDIA boxes.
- One home per service. Known duplicate traps: `nh` (core/nix.nix vs
  desktop-extras toggle — different retention = eval error if both on),
  flatpak/printing/appimage (standalone module vs desktop-extras toggle).
- Nix forbids two values for one setting in a block — parked alternatives
  must say "comment the active one out FIRST, then uncomment."
- `dns.provider` (quad9/cloudflare/google/opendns/native) drives both
  `dns.nix` and Blocky. `dns.upstreamOverride` (null default) lets Blocky use
  a verbatim list on DoT-blocked networks. Fallback recipe (all three at
  once: dns import + blocky import + `dns.provider` line) is commented in
  configuration.nix — dns-less alone FAILS evaluation.
- PRIME (laptop): `offload` = iGPU desktop + `nvidia-offload <app>`;
  `sync` = NVIDIA renders everything (hotter, ~1–2h battery). Sync does NOT
  cool the CPU (shared heatpipes). BusIDs verified via `lspci`.

## Gotchas for AI agents

- **Ownership:** some paths are root-owned (`modules/system/`,
  `modules/desktop/hyprland.nix`, historically others). No sudo in agent
  shells — stage to `/tmp`, verify, hand the user the `sudo cp` line.
  Directory writability allows rename-swaps only in user-owned dirs.
- **Flakes only see indexed files.** A file must be tracked in HEAD or staged
  in the index, or evaluation fails with "not tracked by Git" — this applies
  to git-IGNORED files too (they are invisible, not merely uncommitted).
  `git add` every new/moved file. `hardware-configuration.nix` is committed
  once as an example and stays ignored afterwards, so per-machine regens never
  commit — but a fresh clone has no copy at all until one is generated.
- **Verify everything, every time:**
  `nix-instantiate --parse <file>` per touched file, then full
  `nix eval --no-warn-dirty '/etc/nixos#nixosConfigurations.nixos.config.system.build.toplevel.drvPath'`.
  Same drv hash as before = comment-only change. A changed hash must trace to
  an intended generated-file/content change.
- Test risky claims live (temporary edit → eval → revert), e.g. fallback
  scenarios and Nix semantics like duplicate attributes.
