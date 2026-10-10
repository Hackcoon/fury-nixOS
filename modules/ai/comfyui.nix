# ============================================================================
# comfyui.nix — ComfyUI image/video generation service values.
#
# NOTE — this service comes from a FLAKE, not nixpkgs:
#   flake input:  comfyui-nix.url = "github:utensils/comfyui-nix" (see flake.nix)
#   flake module: comfyui-nix.nixosModules.default (wired in flake.nix modules)
# That flake module declares every `services.comfyui.*` option used below. It
# auto-disables nixpkgs' own `services.comfyui` module, so there is no option
# collision — all values here come from the flake.
# Upstream: https://github.com/utensils/comfyui-nix
# Full guide (models, VRAM tuning, workflows): docs/comfyui-nixos-guide.md
#
# Tailored for this host: GTX 1660 SUPER 6GB (Turing TU116) + proprietary
# NVIDIA driver (modules/hardware/nvidia.nix, driver >= 580 satisfies the
# flake's CUDA 13 runtime). 6GB VRAM => `--lowvram` is mandatory; prefer
# SD1.5/SDXL + LTX-Video / Wan 1.3B-5B over Flux-Dev-FP16 / Wan-14B / Hunyuan.
# HEAVY+MACHINE-SPECIFIC: works on the 1660 Ti laptop too, just heavy. Update
# with: sudo nix flake update comfyui-nix && rebuild.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Service core: CUDA backend, Manager, localhost binding ──
  # gpuSupport "cuda" = this box is NVIDIA Turing ("rocm" = AMD gfx1100,
  # "none" = CPU-only test). Manager pip-installs into <dataDir>/.venv so the
  # Nix store stays read-only — but after installing nodes via Manager UI a
  # FULL restart is required (sudo systemctl restart comfyui): Manager's
  # soft-restart skips the flake's Nix patching (e.g. Comfyroll Studio's
  # hardcoded /usr/share/fonts fix). Bound to localhost; for LAN use
  # "0.0.0.0" + openFirewall=true.
  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    enableManager = true;
    port = 8188;
    listenAddress = "127.0.0.1";
    openFirewall = false;
  # ----------------------------------------------------------------------

    # ── Data home: /home for easy file management ──
    # Holds models/, output/, input/, user/, custom_nodes/, .venv/, .cache/.
    # Under /home the flake auto-disables ProtectHome. Isolated alternative:
    # "/var/lib/comfyui". createUser=false = reuse existing fury/users.
    dataDir = "/home/fury/comfyui-data";
    user = "fury";
    group = "users";
    createUser = false;
  # ----------------------------------------------------------------------

    # ── 6GB-VRAM survival kit ──
    # --lowvram + --disable-pinned-memory are mandatory at 6GB. Fallbacks in
    # guide §8: "--use-pytorch-cross-attention" / "--disable-xformers".
    extraArgs = [
      "--lowvram"
      "--disable-pinned-memory"
    ];
  # ----------------------------------------------------------------------

    # ── Custom nodes: bundled ON, declarative parked ──
    # Bundled = flake's curated set linked (Impact Pack, KJNodes, GGUF,
    # LTXVideo, WanVideoWrapper, MMAudio, PuLID...). Set false to manage
    # manage custom_nodes/ manually via Manager/git + `customNodes` below.
    bundledCustomNodes = true;

    # Declarative (pure-Nix, pinned) extra nodes. Example:
    # customNodes = {
    #   comfyui_controlnet_aux = pkgs.fetchFromGitHub {
    #     owner = "Fannovel16";
    #     repo = "comfyui_controlnet_aux";
    #     rev = "v1.0.0";
    #     hash = "sha256-..."; # nix-prefetch-github Fannovel16 comfyui_controlnet_aux --rev v1.0.0
    #   };
    # };
    # Extra Python deps for declarative nodes (same overridden Python set as
    # ComfyUI, so torch/CUDA isn't duplicated). Cannot combine with a custom
    # `services.comfyui.package`.
    # extraPythonPackages = ps: with ps; [ bcrypt pyjwt bleach ];

    # If dataDir lived on a separate mount (NFS/ZFS dataset), wait for it:
    # requiresMounts = [ "home-fury-comfyui\\x2ddata.mount" ];
  };
  # ----------------------------------------------------------------------
}
