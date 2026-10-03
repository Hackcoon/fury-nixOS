# ComfyUI on NixOS — Complete Guide (Image + Video)
## Tailored for this machine: GTX 1660 SUPER 6GB (Turing) / NixOS 26.05 / AMD CPU

> Source flake: `github:utensils/comfyui-nix` — slightly opinionated pure Nix flake for ComfyUI with Python 3.12 + curated custom nodes.
> This guide is adapted to **your** `/etc/nixos` setup (stable `nixos-26.05`, proprietary NVIDIA driver, 6 GB VRAM).

---

## 0. What you have, and what that means

Detected on this host:

```
07:00.0 VGA: NVIDIA TU116 [GeForce GTX 1660 SUPER] (rev a1)
nvidia-smi: 595.71.05, 6144 MiB
RAM: 31 GiB, disk / : 156 GiB free
Driver in config: modules/hardware/nvidia.nix -> nvidiaPackages.stable, open=false, modesetting on
```

Implications:

1. **Use the `#cuda` build.** You are Turing + NVIDIA proprietary + driver 595 — this satisfies comfyui-nix's requirement (driver >= 580, CUDA 13 runtime bundled in Nix closure, Turing through Blackwell supported in one package).
2. **6 GB VRAM is the main constraint.** You can do a lot, but you must pick the right models + flags. Forget 24 GB workflows (Flux Dev FP16, Wan 14B FP16, HunyuanVideo FP16). Use quantized / lightweight variants:
   - Images: SD 1.5 > SDXL > SDXL Turbo > Flux Schnell FP8 / GGUF Q4. Flux Dev only as GGUF/FP8 with `--lowvram`.
   - Video: LTX-Video (bundled, fastest on low VRAM) > Wan 2.1 1.3B > Wan 2.2 5B TI2V > Wan 14B only with GGUF + low steps. HunyuanVideo is effectively out of reach on 6 GB.
3. **Your NixOS is `nixos-26.05` stable.** comfyui-nix tracks `nixos-unstable`. Do **not** `follows = "nixpkgs"` it to stable — let it use its own pinned nixpkgs, otherwise CUDA wheels break. Just add it as a separate input.
4. **Disk:** budget 30–80 GB. One SDXL checkpoint ~7 GB, one Flux GGUF ~11 GB, one Wan 5B set ~15 GB, plus `.venv`, caches, outputs. You have 156 GB free — fine.

---

## 1. How ComfyUI works (60-second mental model)

ComfyUI is a node-graph frontend for diffusion models. No forms like A1111/Forge — you wire nodes:

```
Load Checkpoint -> CLIP Text Encode (positive/negative) -> Empty Latent -> KSampler -> VAE Decode -> Save Image
```

For Flux / Wan the loaders differ (`UNETLoader` / `Load Diffusion Model` + `DualCLIPLoader` + `EmptySD3LatentImage`), but the idea is identical.

Key concepts:

- `models/checkpoints/` — full SD 1.5 / SDXL checkpoints (`.safetensors`)
- `models/diffusion_models/` + `models/unet/` — Flux / Wan / LTX diffusion weights (new split-checkpoint format)
- `models/text_encoders/` — CLIP-L, T5-XXL, UMT5 (prompt understanding)
- `models/vae/` — image decoder (e.g. `ae.safetensors`, `sdxl_vae.safetensors`)
- `models/loras/` — style/character add-ons
- `models/controlnet/` — edge/depth/pose guidance
- `models/upscale_models/` — Real-ESRGAN etc.
- `models/clip_vision/` — needed for image-to-video (Wan I2V)
- Workflows are JSON. Any PNG output by ComfyUI embeds its workflow — drag it back in to reload.

Official docs to bookmark:

- https://docs.comfy.org/ — official manual, model layout, LoRA/ControlNet/Flux tutorials
- https://comfy.org/workflows/ — searchable workflow templates
- https://comfyui-wiki.com/ — community wiki (install, custom nodes, Wan 2.2 guides)
- https://github.com/Comfy-Org/ComfyUI — upstream
- https://github.com/Comfy-Org/ComfyUI-Manager — manager
- https://github.com/utensils/comfyui-nix — the Nix flake you are using

---

## 2. Prerequisites on NixOS

You already have most of this. Verify:

### 2.1 Flakes enabled

`modules/core/nix.nix` should contain (standard on this system):

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### 2.2 NVIDIA already correct — do not change

Your `modules/hardware/nvidia.nix` is already right for ComfyUI CUDA:

- `services.xserver.videoDrivers = [ "nvidia" ]`
- `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable`
- `hardware.graphics.enable = true`
- `open = false` is correct for TU116

No CUDA toolkit install needed. comfyui-nix bundles CUDA 13.0 libs in the Nix closure via nixpkgs. Host only provides the kernel driver (>= 580 — you have 595).

Check anytime:

```bash
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
```

### 2.3 Binary caches (mandatory — otherwise you compile for hours)

comfyui-nix auto-configures caches for the flake, but the **daemon must trust them**. Add once:

```nix
# in modules/core/nix.nix or configuration.nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://comfyui.cachix.org"
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

Then:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Alternative ad-hoc:

```bash
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use comfyui
cachix use nix-community
```

If you see torch/CUDA building from source instead of downloading, your keys are wrong — re-check exact strings above.

---

## 3. Installation — 3 ways (use option B for daily use)

### Option A — Quick test, no system change (5 min)

Best for “does my GPU work?”:

```bash
# CPU test (slow, just checks UI boots):
nix run github:utensils/comfyui-nix -- --open

# Real test — CUDA on your 1660 SUPER:
nix run github:utensils/comfyui-nix#cuda -- --open --lowvram --disable-pinned-memory
```

Open http://127.0.0.1:8188 if `--open` doesn’t pop a browser.

Data lands in `~/.config/comfy-ui/` by default. Custom port:

```bash
nix run github:utensils/comfyui-nix#cuda -- --open --port 8189 --lowvram
```

Full CLI parity: all [ComfyUI CLI options](https://docs.comfy.org/comfyui-cli/reference) work. Useful ones:

| Flag | When to use on 6 GB |
|------|---------------------|
| `--lowvram` | **always** on 1660 SUPER |
| `--disable-pinned-memory` | low RAM pressure / OOM in video |
| `--use-pytorch-cross-attention` | fallback if xformers OOMs |
| `--disable-xformers` | ROCm-style fallback, sometimes helps Turing |
| `--enable-manager` | install custom nodes from UI |
| `--listen 0.0.0.0` | LAN access ( + open firewall) |
| `--base-directory /path` | override data dir per-run |

### Option B — Declarative NixOS service (recommended)

This is the “NixOS way”: ComfyUI as a systemd service with pinned custom nodes.

**Step 1 — add input to `/etc/nixos/flake.nix`:**

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  # ... your existing inputs ...
  comfyui-nix.url = "github:utensils/comfyui-nix";
  # NOTE: do NOT add follows = "nixpkgs" here.
  # comfyui-nix needs its pinned unstable nixpkgs for CUDA wheels.
};
```

Add `comfyui-nix` to the `outputs = { ..., comfyui-nix, ... }:` argument list, and to `modules = [ ... ]` either import the module directly:

```nix
modules = [
  ./configuration.nix
  # ... others ...
  comfyui-nix.nixosModules.default
];
```

Or create a dedicated file `modules/ai/comfyui.nix` and import it from `configuration.nix` (cleaner, matches your `modules/*` layout).

**Step 2 — service config tailored to GTX 1660 SUPER 6 GB:**

```nix
# modules/ai/comfyui.nix
{ config, pkgs, lib, ... }:
{
  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";          # Turing NVIDIA
    enableManager = true;         # built-in ComfyUI-Manager
    port = 8188;
    listenAddress = "127.0.0.1";  # "0.0.0.0" only for LAN
    dataDir = "/home/fury/comfyui-data";  # easy file access
    user = "fury";
    group = "users";
    createUser = false;           # use existing user
    openFirewall = false;         # true only with listen 0.0.0.0
    extraArgs = [
      "--lowvram"
      "--disable-pinned-memory"
    ];
  };
}
```

Notes from upstream README you must know:

- This module **brings its own packages** — you do NOT need `comfyui-nix.overlays.default` for the service. Add the overlay only if you also want `pkgs.comfy-ui*` CLI elsewhere.
- It auto-disables nixpkgs’ own `services.comfyui` so there’s no option collision.
- If `dataDir` is under `/home/`, `ProtectHome` is auto-disabled — required, don’t fight it.
- `cudaCapabilities` maps to `nixpkgs.config.cudaCapabilities` system-wide. Leave unset unless you know you need `["7.5"]` for TU116 tuning. Pre-built wheels already cover Turing–Blackwell.

For default isolated service instead (`/var/lib/comfyui` + `comfyui` user):

```nix
services.comfyui = {
  enable = true;
  gpuSupport = "cuda";
  enableManager = true;
  dataDir = "/var/lib/comfyui";
  # user/group default to comfyui, createUser defaults true
};
```

**Step 3 — rebuild + check:**

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
systemctl status comfyui
journalctl -u comfyui -f
# UI:
xdg-open http://127.0.0.1:8188
```

### Option C — Overlay packages (CLI without service)

If you want `comfy-ui-cuda` as a normal command plus the service, or instead of it:

```nix
{
  nixpkgs.overlays = [ comfyui-nix.overlays.default ];
  environment.systemPackages = [
    # pkgs.comfy-ui        # CPU / Apple Silicon
    pkgs.comfy-ui-cuda     # <-- your card
    # pkgs.comfy-ui-rocm   # AMD only
    # pkgs.comfy-ui-xpu    # Intel Arc only
  ];
}
```

Or without overlay, referencing the flake directly:

```nix
{ pkgs, inputs, ... }: {
  environment.systemPackages = [
    inputs.comfyui-nix.packages.${pkgs.stdenv.hostPlatform.system}.cuda
  ];
}
```

Run then as `comfy-ui --open --lowvram` (binary name varies by wrapper — check `nix run` first).

### What NOT to do on NixOS

- Don’t `pip install torch` / `uv sync --extra cu126` into system Python (Discourse workaround for non-flake setups). It fights Nix. Use the flake.
- Don’t git-clone ComfyUI + `pip install -r requirements.txt` on NixOS without `nix-ld` + vendored CUDA. The flake already solves this.
- Alternative flakes exist (`nixified-ai`, `aldenparker/comfyui-nix-devshell`, `NexRX/comfyui-nix-rocm` fork) but `utensils/comfyui-nix` is the most maintained (161 stars, 206 commits, Cachix, Docker images, NixOS module). Stick with it.

---

## 4. First run checklist

1. Start (pick one method above) with `--enable-manager --lowvram` the first time.
2. Open UI → left sidebar → `Workflow → Browse Templates`. Load `Basic → Image Generation`. Hit `Queue` (or Ctrl+Enter). If you see a gradient/boxes image, the pipeline works — you just have no real checkpoint yet.
3. Data layout created on first run:

```
<data-directory>/          # ~/.config/comfy-ui  OR  /home/fury/comfyui-data  OR  /var/lib/comfyui
├── models/               # checkpoints, diffusion_models, loras, vae, controlnet, ...
├── output/               # generations
├── input/                # uploads
├── user/                 # workflows, settings, manager config
├── custom_nodes/         # bundled nodes auto-linked here
├── fonts/                # bundled fonts (fixes Comfyroll hardcoded /usr/share/fonts)
├── .venv/                # Manager-installed pip deps (Nix store stays read-only)
├── .cache/               # torch hub, HuggingFace, facexlib redirects
└── temp/
```

4. Enable Manager persistently: either always pass `--enable-manager` or set `enableManager = true` in the NixOS module.
5. **After installing any custom node via Manager that needs patching (e.g. Comfyroll Studio), do a FULL restart.** Manager’s soft-restart does not trigger Nix patching:
   ```bash
   # nix run method:
   # Ctrl+C, then re-run
   # service method:
   sudo systemctl restart comfyui
   ```

---

## 5. Image generation — what to download for 6 GB

### 5.1 Model picker (VRAM reality)

| Model | Params / size | FP16 VRAM | Quantized reality on 6 GB | Verdict for 1660 SUPER |
|-------|---------------|-----------|---------------------------|------------------------|
| SD 1.5 (e.g. Realistic Vision, DreamShaper) | ~860M / ~4 GB | ~2 GB | fits natively | ✅ Best speed, 1–3 s at 512px, tons of LoRAs |
| SDXL Base + Refiner | ~3.5B / ~7 GB | ~7 GB | fits with `--lowvram`, tight | ✅ Good 1024px if you close browsers, use 20–30 steps |
| SDXL Turbo | ~3.5B | ~7 GB | 1–4 steps, fast | ✅ Fast previews |
| Flux Schnell | ~12B / ~23 GB FP16 | ~24 GB | FP8 ~12 GB, GGUF Q4 ~7–10 GB | ⚠️ Usable as `flux1-schnell-fp8` or GGUF Q4 + lowvram, 4 steps, slow but works |
| Flux Dev | ~12B | ~24 GB | FP8/GGUF + NF4 node, 15–40 s | ⚠️ Possible but painful on 6 GB; prefer Schnell |
| Qwen-Image 2.0 | 7B / native 2K | ~8–12 GB FP8 | Apache 2.0, great bilingual text | ⚠️ Try FP8 variant if you need text rendering |
| Chroma / SD 3.5 / HunyuanImage 3.0 | large | 13–80 GB | no | ❌ Skip on 6 GB |

Rule: **start with SD 1.5 + SDXL, add one Flux Schnell quantized only if you need hands/text quality.**

### 5.2 Where files go (ComfyUI layout)

```
models/
├── checkpoints/      # SD1.5, SDXL, Flux FP8 single-file (.safetensors)
├── diffusion_models/ # Flux .safetensors split (flux1-dev/schnell) — also models/unet alias
├── text_encoders/    # clip_l.safetensors, t5xxl_fp16/fp8, umt5 for Wan
├── vae/              # sdxl_vae.safetensors, ae.safetensors (Flux), vae-ft-mse...
├── loras/            # style/character LoRAs
├── controlnet/       # control_v11p_... , Flux Canny/Depth
├── upscale_models/   # RealESRGAN_x4plus.pth
├── clip_vision/      # clip_vision_h.safetensors (Wan I2V)
└── embeddings/       # textual inversions
```

On your service install replace `models/` with `/home/fury/comfyui-data/models/`.

You can share models with other UIs via `extra_model_paths.yaml` (see §9), but simplest is to keep ComfyUI’s own folder.

### 5.3 Downloads (copy-paste)

All are `.safetensors` unless noted. Use Manager’s downloader node (`POST /api/download_model`) or `wget`. Login to HuggingFace for gated ones (Flux Dev).

**SD 1.5 starter (fastest):**

```bash
cd /home/fury/comfyui-data/models/checkpoints
wget https://huggingface.co/SG161222/Realistic_Vision_V6.0_B1_noVAE/resolve/main/Realistic_Vision_V6.0_B1_fp16.safetensors
cd ../vae
wget https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors
```

**SDXL (main workhorse):**

```bash
cd /home/fury/comfyui-data/models/checkpoints
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
# optional refiner:
wget https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors
cd ../vae
wget https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
```

**Flux Schnell quantized (only Flux recommended on 6 GB):**

Option 1 — single-file FP8 (simplest, `Load Checkpoint`):

```bash
cd /home/fury/comfyui-data/models/checkpoints
wget https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors
```

Option 2 — split (better control, official docs pattern):

```bash
cd /home/fury/comfyui-data/models/diffusion_models
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors
cd ../text_encoders
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
wget https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
cd ../vae
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors
```

Workflow difference: single-file uses `Load Checkpoint`; split uses `UNETLoader + DualCLIPLoader + VAE Loader + EmptySD3LatentImage + ModelSamplingFlux`. Templates auto-prompt for missing files.

For Flux Dev GGUF (advanced, lowest VRAM): install `ComfyUI-GGUF` (already bundled) + download `flux1-dev-Q4_0.gguf` from `city96/FLUX.1-dev-gguf` repo into `models/unet/`, plus quantized T5. Expect slow but working 1024px.

**LoRA example:**

```bash
cd /home/fury/comfyui-data/models/loras
# example style LoRA — replace with any Civitai/HF LoRA matching your base:
wget https://huggingface.co/.../blindbox_V1Mix.safetensors
```

Use `Load LoRA` chained after `Load Checkpoint`, strength 0.5–1.0. Chain multiple LoRAs in series.

**ControlNet (SD 1.5 scribble example):**

```bash
cd /home/fury/comfyui-data/models/controlnet
wget https://huggingface.co/lllyasviel/sd-controlnet-scribble/resolve/main/diffusion_pytorch_model.fp16.safetensors -O control_v11p_sd15_scribble_fp16.safetensors
```

Nodes: `Load ControlNet + Apply ControlNet`. Preprocess sketch → control image.

**Upscaler (generate small, upscale — key 6 GB trick):**

```bash
cd /home/fury/comfyui-data/models/upscale_models
wget https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth
```

Workflow: generate at 768px → `Upscale Image` → output 3072px. Saves VRAM vs native 1024+.

### 5.4 Starter workflows

1. **Text-to-image (SDXL):** `Load Checkpoint (sd_xl_base) → CLIP Text Encode x2 → Empty Latent 1024x1024 → KSampler (25 steps, CFG 6, euler, normal) → VAE Decode → Save Image`.
2. **Image-to-image:** replace `Empty Latent` with `Load Image → VAE Encode`, set KSampler denoise 0.5–0.8.
3. **LoRA style:** insert `Load LoRA` between checkpoint and sampler.
4. **Flux Schnell FP8:** load template `Flux → Text to Image`, 4 steps, CFG 1–3, empty negative prompt is fine.
5. **Upscale pass:** `Load Image (your gen) → Upscale Image (RealESRGAN) → Save`.

Prompt tips that matter more than model: be specific (lens, light, composition), use negative (`blurry, deformed hands, watermark`), keep CFG 5–7 for SDXL, 1–3 for Schnell/Turbo, seed `-1` random then lock good seeds.

Sources for ready JSON: `Workflow → Browse Templates` in-app, https://comfy.org/workflows/, Civitai workflow posts (PNGs with embedded JSON).

---

## 6. Video generation — what works on 6 GB

### 6.1 Picker (be honest about VRAM)

| Model | Size / license | VRAM need | 1660 SUPER verdict |
|-------|----------------|-----------|--------------------|
| **LTX-Video (Lightricks)** | ~2–5B / Apache-2.0, **already bundled as ComfyUI-LTXVideo** | ~6–8 GB, fastest | ✅ **Start here.** 480p few-sec clips work. Prompt enhancer node included. |
| **Wan 2.1 T2V 1.3B** | 1.3B / Apache-2.0 | ~8 GB, 5s 480p in ~4 min on 4090 (longer on 1660S) | ✅ Best quality-per-VRAM. Use 480p, 33–81 frames, FP8 text encoder. |
| **Wan 2.2 TI2V 5B** | 5B hybrid T2V+I2V / Apache-2.0 | ~8 GB with offload | ✅ Second step up. Single model does both T2V+I2V. |
| **Wan 2.2 14B T2V/I2V** | 14B MoE / Apache-2.0 | ~40 GB FP16, ~12–16 GB GGUF | ⚠️ Only as GGUF + `lightx2v 4-step LoRA`, 480p, expect 10+ min + swapping. Optional. |
| **HunyuanVideo / Hunyuan 1.5** | 13B+ | 20–80 GB | ❌ Skip on 6 GB. |
| **AnimateDiff (SD1.5 motion)** | LoRA on SD1.5 | ~6 GB | ✅ Retro but works: turn SD1.5 images into 2–4s morphs. Good fallback. |

Recommendation path: **LTX-Video today → Wan 1.3B 480p → Wan 2.2 5B → stop.** Don’t chase 720p/14B on this card.

### 6.2 Files for Wan (the confusing part)

Wan needs 4 files in 4 folders (example for 2.1 1.3B):

```
models/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors   # or .safetensors from Wan-AI/Wan2.1-T2V-1.3B on HF
models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors
models/clip_vision/clip_vision_h.safetensors                # I2V only
models/vae/wan_2.1_vae.safetensors
```

For Wan 2.2 5B:

```
models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors     # from Wan-AI/Wan2.2-TI2V-5B
models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors # reuse
models/vae/wan2.2_vae.safetensors
```

Official template names to search in-app: `Wan2.2 5B`, `Wan 2.2 14B T2V/I2V`, `Wan2.1 T2V 1.3B`. Or web: https://docs.comfy.org/tutorials/video/wan/wan2_2 and https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2

Lightning speedup: `lightx2v 4-step LoRA` (search HuggingFace `Wan2.2-Lightning`) drops sampling from 20 steps CFG 6 → 4 steps CFG 1. Slight quality loss, 4–5x faster — worth it on 1660S.

WanVideoWrapper (Kijai, **already bundled**) gives friendlier nodes (`WanVideo Model Loader, WanVideo Sampler`) vs native nodes. Try native templates first, wrapper if OOM.

### 6.3 Minimal video settings that won’t OOM

- Resolution: 480p (832x480 or 480x832), never 720p initially.
- Frames: 33–49 (≈2s at 16–24fps), then extend with interpolation / Fun-Control.
- Steps: 20 (standard) or 4 (lightning LoRA), CFG 6.0 standard / 1.0 lightning.
- Text encoder: always FP8 (`umt5_xxl_fp8...`), never FP16 on 6 GB.
- Flags: `--lowvram --disable-pinned-memory`.
- Generate image first (SDXL 768px), then image-to-video — much better control than pure T2V.
- Audio: bundled `ComfyUI-MMAudio` can add 44 kHz audio from silent clip (video-to-audio + text-to-audio).

---

## 7. Custom nodes (bundled + Manager)

### 7.1 Already bundled (no install needed)

From comfyui-nix README — auto-linked on first run:

- **Model Downloader** (own node, async + `POST /api/download_model`, `GET /api/download_progress/{id}`)
- **ComfyUI Impact Pack** — SAM/SAM2 segmentation, detection, masking
- **rgthree-comfy** — Reroute, Context, Power LoRA Loader, Bookmarks
- **ComfyUI-KJNodes** — batch, conditioning, image/mask utils
- **ComfyUI-GGUF** — quantized model loading (Flux/Wan on low VRAM)
- **ComfyUI-LTXVideo** — LTX video gen
- **ComfyUI-Florence2** — captioning, detection, OCR, VQA
- **ComfyUI_bitsandbytes_NF4** — NF4 Flux checkpoints
- **x-flux-comfyui** — Flux LoRA/ControlNet/IP-Adaptor, 12 GB optimized
- **ComfyUI-MMAudio** — video-to-audio
- **PuLID_ComfyUI** — face ID preservation (see `docs/pulid-setup.md` upstream)
- **ComfyUI-WanVideoWrapper** — Wan/SkyReels video

Python deps (opencv, diffusers, gguf, librosa, bitsandbytes…) are pre-built in Nix env.

To manage `custom_nodes/` yourself: set `COMFY_SKIP_BUNDLED_NODES=1` or `services.comfyui.bundledCustomNodes = false`. Note: with bundled on, launcher deletes any real dir matching bundled names — don’t manually git-clone over them.

### 7.2 Adding more via Manager (mutable venv trick)

Nix store is read-only, so Manager pip-installs into `<data-dir>/.venv/` (PEP 405 venv). Nix packages take precedence unless `COMFY_VENV_PRECEDENCE=prefer-venv`.

Flow: `Manager → Custom Nodes Manager → search → Install → FULL restart (see §4.5)`.

### 7.3 Declarative nodes (pure Nix, reproducible)

```nix
services.comfyui = {
  enable = true;
  customNodes = {
    comfyui_controlnet_aux = pkgs.fetchFromGitHub {
      owner = "Fannovel16";
      repo = "comfyui_controlnet_aux";
      rev = "v1.0.0";
      hash = "sha256-...";  # nix-prefetch-github Fannovel16 comfyui_controlnet_aux --rev v1.0.0
    };
  };
  # extra deps for nodes:
  extraPythonPackages = ps: with ps; [ bcrypt pyjwt bleach ];
  # do NOT combine extraPythonPackages with custom services.comfyui.package
};
```

Avoid names colliding with bundled nodes unless you also set `bundledCustomNodes = false`.

---

## 8. Performance tuning for 6 GB (1660 SUPER cheat sheet)

```nix
extraArgs = [ "--lowvram" "--disable-pinned-memory" ];
# optional fallbacks if OOM:
# "--use-pytorch-cross-attention"  # instead of xformers
# "--disable-xformers"
# "--force-fp16"  # usually default on NVIDIA, helps vs fp32
```

- **Resolution ladder:** 512 (SD1.5) → 768 → 1024 only for final. For video 480p only.
- **Steps:** SDXL 20–30, Schnell/Turbo 4, Wan standard 20 / lightning 4.
- **Quantization first:** FP8 text encoders, GGUF Q4 diffusion, NF4 for Flux Dev. Quality loss < VRAM crash.
- **Batch 1.** No batching on 6 GB.
- **Close browsers / Electron (Vesktop, Zen) during video gens** — they eat VRAM-adjacent RAM and trigger pinned-memory OOM.
- **Upscale workflow:** gen 768 → Real-ESRGAN x4 → downscale if needed. Looks like 1024 native for half the VRAM.
- **Cache:** first SYCL/CUDA kernel compile is slow; reruns reuse `<data-dir>/.cache/`.
- **Monitor:** `nvidia-smi -l 1`, `journalctl -u comfyui -f`, ComfyUI “VRAM” footer in UI.

---

## 9. Sharing models / multi-UI setup

If you also run A1111/Forge/Fooocus, avoid duplicate 50 GB downloads via `extra_model_paths.yaml` in data dir:

```yaml
my_custom_config:
  base_path: /home/fury/AI-models
  checkpoints: checkpoints/
  loras: loras/
  vae: vae/
  controlnet: controlnet/
  upscale_models: upscale_models/
  embeddings: embeddings/
```

Or per-UI:

```yaml
a111:
  base_path: /home/fury/stable-diffusion-webui
  checkpoints: models/Stable-diffusion
  vae: models/VAE
  loras: |
    models/Lora
    models/LyCORIS
```

Back up before editing. Restart ComfyUI after.

---

## 10. Docker alternative (if Nix service misbehaves)

Images on GHCR (no Nix eval needed, needs `nvidia-container-toolkit` + Docker/Podman):

```bash
# CUDA, Turing–Blackwell, mount ./data:
docker run --gpus all -p 8188:8188 -v "$PWD/data:/data" ghcr.io/utensils/comfyui-nix:latest-cuda --listen 0.0.0.0 --enable-manager --lowvram
podman run --device nvidia.com/gpu=all -p 8188:8188 -v "$PWD/data:/data:Z" ghcr.io/utensils/comfyui-nix:latest-cuda --listen 0.0.0.0 --enable-manager --lowvram
```

Build locally from flake:

```bash
nix build .#dockerImageCuda
docker load < result
```

macOS note: Docker/Podman there is CPU-only; on Apple Silicon use `nix run` for Metal.

---

## 11. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `CUDA 13 no longer supports pre-Turing` | You’re fine (Turing 1660S supported). Pascal/Volta need older comfyui-nix release. |
| Torch builds from source, 30 GB RAM spike | Cachix keys missing (§2.3). Fix substituters/trusted-keys, rebuild. |
| `services.comfyui.enable already declared` | Old nixpkgs module colliding — importing `comfyui-nix.nixosModules.default` auto-disables it. Don’t import both manually. |
| Manager installs node but nodes missing / font error | Need FULL restart (`systemctl restart comfyui`), not Manager soft-restart. Comfyroll `/usr/share/fonts` patched only at launcher start. |
| OOM at 1024px / 720p video | Expected on 6 GB. Drop to 768px/480p, add `--lowvram`, use FP8/GGUF, batch 1. |
| `double precision not supported` | Intel XPU iGPU only — irrelevant to you (NVIDIA). |
| Port 8188 in use | `--port 8189` or `services.comfyui.port = 8189`. |
| LAN can’t reach UI | Need `--listen 0.0.0.0` + `openFirewall = true` + `listenAddress = "0.0.0.0"`. |
| Permission denied on `/var/lib/comfyui` | You overrode `dataDir` to `/home/...` but kept `user=comfyui`. Either use `user=fury group=users createUser=false` or `chown`. |
| Slow first gen | Normal — kernels compiling into `.cache/`. Second run faster. |
| NixOS Discourse “how do you run ComfyUI?” confusion | Old threads suggest `uv + nix-ld`. Ignore — flake + module is current best practice (2025–2026). |

Logs:

```bash
journalctl -u comfyui -f
journalctl -u comfyui --since "10 min ago" | grep -i -E "cuda|vram|error|fail"
nvidia-smi -l 1
```

---

## 12. Update + backup

```bash
# update only comfyui-nix input:
sudo nix flake update comfyui-nix --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# check upstream:
nix run github:utensils/comfyui-nix#update  # inside cloned repo, checks ComfyUI rev
```

Back up: `<data-dir>/user/` (workflows/settings), `custom_nodes/` list, `extra_model_paths.yaml`, outputs you care about. Models can be re-downloaded — workflows cannot.

Upstream changelog: https://github.com/utensils/comfyui-nix/blob/main/CHANGELOG.md, `docs/pulid-setup.md` for PuLID face-ID.

---

## 13. Full resource list

**Nix-specific:**

- https://github.com/utensils/comfyui-nix — main flake (README covers CUDA/ROCm/XPU, module options, Docker, cachix)
- https://github.com/utensils/comfyui-nix/blob/main/flake.nix — overlay packages (`comfy-ui`, `-cuda`, `-rocm`, `-xpu`)
- https://discourse.nixos.org/t/how-do-you-guys-run-comfyui-on-nixos/71471 — why flake beats `uv + nix-ld`
- https://github.com/Lodjuret/nixified-ai — alternative flake with NixOS module
- https://github.com/NexRX/comfyui-nix-rocm — ROCm fork (RX 6000/7000 notes)

**Official ComfyUI:**

- https://docs.comfy.org/ — install, models, LoRA, ControlNet, Flux T2I, Wan 2.2 video, Manager, templates
- https://docs.comfy.org/basic-concepts/models
- https://docs.comfy.org/tutorials/basic/lora
- https://docs.comfy.org/tutorials/controlnet/controlnet.md
- https://docs.comfy.org/tutorials/flux/flux-1-text-to-image
- https://docs.comfy.org/tutorials/video/wan/wan2_2
- https://comfy.org/workflows/ — filter Text-to-Video / Image-to-Video / Flux
- https://comfy.org/workflows/video_wan2_2_14B_t2v-5f8b74d92e62/ and `.../video_wan2_2_14B_i2v-...` — reference JSON graphs
- https://github.com/Comfy-Org/ComfyUI
- https://github.com/Comfy-Org/ComfyUI-Manager
- https://github.com/Comfy-Org/example_workflows — Wan Fun-Control MP4s + JSON

**Wiki / guides:**

- https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2 — Wan 2.2 T2V/I2V/GGUF
- https://comfyui-wiki.com/en/tutorial/advanced/video/wan2.2/wan2-2-fun-control — Canny/Depth/Pose control
- https://comfyui-wiki.com/en/models/flux — Flux 1 / 2 / 3 family
- https://comfyui-wiki.com/en/install/install-custom-nodes
- https://dev.to/jovan_chan_9500711396d4e6/stable-diffusion-vs-sdxl-vs-flux-which-image-generation-model-should-you-use-in-2026-54dk — SD1.5 vs SDXL vs Flux VRAM table
- https://www.earngenix.com/blog/best-local-image-generation-models-2026 — 2026 ranking (Krea 2, Ideogram 4, Flux.2 klein 4B Apache-2.0, Qwen-Image 2.0, Z-Image Turbo)

**Models (HuggingFace / Civitai):**

- SDXL Base/Refiner/VAE: `stabilityai/stable-diffusion-xl-base-1.0`, `-refiner-1.0`, `stabilityai/sdxl-vae`
- Realistic Vision: `SG161222/Realistic_Vision_V6.0_B1_noVAE`
- Flux Schnell/Dev: `black-forest-labs/FLUX.1-schnell`, `FLUX.1-dev`, FP8 via `Comfy-Org/flux1-schnell`, `Comfy-Org/flux1-dev`
- Encoders: `comfyanonymous/flux_text_encoders` (`clip_l`, `t5xxl_fp16`, `t5xxl_fp8_e4m3fn`), `city96/FLUX.1-dev-gguf`
- Wan: `Wan-AI/Wan2.1-T2V-1.3B`, `Wan-AI/Wan2.2-TI2V-5B`, `-I2V-A14B`, `-T2V-A14B`, UMT5 FP8, `wan_2.1_vae`, `clip_vision_h`
- LTX-Video: `Lightricks/LTX-Video` (bundled node `Lightricks/ComfyUI-LTXVideo`)
- ControlNet: `lllyasviel/sd-controlnet-*`, Flux Canny/Depth via `XLabs-AI/x-flux-comfyui`
- Upscaler: `RealESRGAN_x4plus.pth` (xinntao release)
- Browse: https://huggingface.co/models?search=flux / wan / ltxv, https://civitai.com/, https://comfyuiweb.com/zh/resources/flux-models

**Bundled nodes upstream:**

- Impact Pack: https://github.com/ltdrdata/ComfyUI-Impact-Pack
- rgthree: https://github.com/rgthree/rgthree-comfy
- KJNodes / Florence2 / MMAudio / WanVideoWrapper: https://github.com/kijai/ComfyUI-KJNodes etc.
- GGUF: https://github.com/city96/ComfyUI-GGUF
- LTXVideo: https://github.com/Lightricks/ComfyUI-LTXVideo
- NF4: https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4
- PuLID: https://github.com/cubiq/PuLID_ComfyUI

---

## 14. Suggested start order for tonight

1. `nix run github:utensils/comfyui-nix#cuda -- --open --lowvram --enable-manager` → confirm UI boots, VRAM detected.
2. Download SD 1.5 + SDXL (§5.3) → run Basic template at 512/1024 → confirm <10 s/image.
3. Add `RealESRGAN` → test upscale workflow.
4. Add NixOS module (§3B) → `switch` → move data to `/home/fury/comfyui-data`.
5. Video: test LTX template (bundled, no downloads) → then Wan 2.1 1.3B 480p.
6. Only then: Flux Schnell FP8 (4 steps) if you need better hands/text.

Good luck — on 6 GB, resolution + quantization discipline beats model-hopping.
