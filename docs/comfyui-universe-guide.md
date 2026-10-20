# ComfyUI Universe Guide — The Most Comprehensive Guide
## Image + Video, Nodes + Models + Workflows + API + NixOS, from zero to automation

> Companion files in `/etc/nixos/docs/`: `comfyui-nixos-guide.md` (install for YOUR machine) + `comfyui-usage-guide.md` (hands-on basics).
> This file is the encyclopedia: everything on the internet about ComfyUI, consolidated, with sources.
> Your install: NixOS 26.05, GTX 1660 SUPER 6GB Turing, data at `/home/fury/comfyui-data`, UI at http://127.0.0.1:8188.

**Contents:** 0 What/Why · 1 Install universe · 2 UI complete · 3 Architecture · 4 Model folders · 5 Image models encyclopedia · 6 Video models encyclopedia · 7 Samplers/schedulers bible · 8 Core techniques · 9 Custom nodes encyclopedia · 10 Manager · 11 Quantization bible · 12 Performance/VRAM bible + full CLI flags · 13 Prompting science · 14 Training LoRA · 15 Automation/API/CLI/MCP · 16 Workflow library · 17 Troubleshooting bible · 18 Security/licenses/ethics · 19 Resources/communities/glossary/FAQ · 20 Cheat sheets + your quickstart

---

## 0. What ComfyUI is and why it won

ComfyUI (by comfyanonymous, now Comfy-Org, GPL-3.0, ~135K GitHub stars) is a **node-graph frontend + modular GenAI inference engine** for diffusion models. Instead of a form with a Generate button (A1111/Forge/InvokeAI), you wire loaders → encoders → samplers → decoders → outputs on an infinite canvas. Every tensor transformation is visible, debuggable, versionable as JSON.

Why power users moved here (source: Every Local AI 2026, comfy-ui.net):

| | ComfyUI | A1111 | Forge | InvokeAI |
|---|---|---|---|---|
| UI | node graph | form | form | hybrid |
| Learning curve | high | low | low | medium |
| Memory efficiency | best | OK | better | OK |
| Latest model support | day 1 (Flux, Wan, SD3, HunyuanVideo) | weeks lag | weeks lag | weeks lag |
| Animation/video/batch | native, maintainable | painful | painful | limited |
| API/automation | first-class (REST/WS/SDK) | partial | partial | partial |

Real-world speed (Every Local AI): RTX 4090 SDXL-1024 ~10s, Flux-Dev-1024 ~32s, HunyuanVideo 5s-540p ~210s. RTX 5090 roughly 2x faster. Mac Studio M4 Ultra: SDXL ~25s, Flux ~90s, video not viable.

Product family: **Comfy Desktop** (free, one-click installer + auto-updates + Manager built-in), **Portable** (self-contained folder, needs `--enable-manager` + `manager_requirements.txt`), **Manual** (venv + git clone), **Comfy Cloud** (hosted Blackwell RTX 6000 Pro 96GB, 900+ preloaded models, Standard $20/4.2k credits ~380 5s videos, Creator $35/7.4k, Pro $100/21.1k, 30–60min job limits), **Developer Platform/Serverless** (deploy your env as endpoint, same SDK), **Enterprise** (managed builds, SSO, SLAs). On NixOS you use the **utensils/comfyui-nix flake** (161 stars, Cachix, NixOS module, Docker images) — see install guide + `modules/ai/comfyui.nix`.

---

## 1. Installation universe (all platforms + NixOS deep dive)

### 1.1 Manual (Windows/macOS/Linux) — what the flake replaces
1. `conda create -n comfyenv && conda activate comfyenv` (or `python -m venv`), 2. `git clone https://github.com/Comfy-Org/ComfyUI && cd ComfyUI`, 3. `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu132` (NVIDIA) or `.../rocm7.2` (AMD) or nightly for newest, 4. `pip install -r requirements.txt`, 5. `python main.py --enable-manager`. Manager deps: `pip install -r manager_requirements.txt`. Docs: https://docs.comfy.org/installation/manual_install
### 1.2 Desktop vs Portable
Desktop = installer + auto-updates + Manager pre-enabled. Portable = unzip + `run_nvidia_gpu.bat` (+ edit bat to add flags) + one-time `install-manager-for-portable-version.bat`. Templates auto-prompt for missing models either way.
### 1.3 Docker/Podman (GHCR `utensils/comfyui-nix`)
CPU: `docker run -p 8188:8188 -v "$PWD/data:/data" ghcr.io/utensils/comfyui-nix:latest`; CUDA: `--gpus all ...:latest-cuda --listen 0.0.0.0 --enable-manager --lowvram`; ROCm: `--device /dev/kfd --device /dev/dri`; XPU: `--device /dev/dri`. Podman adds `:Z` + `nvidia.com/gpu=all` CDI. Build locally: `nix build .#dockerImageCuda && docker load < result`. macOS containers = CPU-only.
### 1.4 NixOS via comfyui-nix flake (YOUR path — full detail)
`nix run github:utensils/comfyui-nix -- --open` (CPU), `#cuda` (Turing–Blackwell, CUDA 13 bundled, driver ≥580 — you have 595, good), `#rocm` (gfx1100 tested, ROCm 7.1 in wheels), `#xpu` (Arc A/B + Core Ultra, needs `hardware.graphics.extraPackages = [intel-compute-runtime level-zero]`, `COMFY_ENABLE_XPU_FP64_EMULATION=1` for old iGPUs). Data: Linux `~/.config/comfy-ui`, service `/home/fury/comfyui-data` (yours) or `/var/lib/comfyui`. Binary caches `comfyui.cachix.org` + `nix-community.cachix.org` mandatory (already in `modules/core/nix.nix`). Module brings own packages (no overlay needed for service), auto-disables nixpkgs `services.comfyui`, `ProtectHome` auto-off under `/home/`. Declarative nodes via `customNodes` + `extraPythonPackages`, `bundledCustomNodes=false` to take over. Full restart after Manager installs (Comfyroll `/usr/share/fonts` patch needs launcher restart). Alternatives: `nixified-ai` flake, `uv + nix-ld` Discourse hack (obsolete vs flake), `NexRX/comfyui-nix-rocm` fork.
### 1.5 comfy-cli install path
`pip install comfy-cli` (py3.10+), `comfy install`, `comfy set-default <workspace>`, `comfy update [all|comfy|cli]`, `comfy node install <pack>`, `comfy --install-completion`. Faster: `comfy install --fast-deps` (uv resolver).

---

## 2. UI complete tour + settings

Canvas (pan Space+drag, zoom wheel), nodes (dots in/out, widgets inside; red=error, green=running), links (typed: MODEL/CLIP/VAE/LATENT/IMAGE/MASK/CONDITIONING/SIGMAS/SAMPLER; incompatible = refuse). Top bar: Workflow (Open/Save/Export API/Browse Templates), Queue ▶ (Ctrl+Enter), Manager, Settings. Sidebar: Node Library (Q palette faster), Model Library, Queue/History (seeds + embedded workflows). Previews: click to enlarge; every saved PNG embeds workflow JSON — drag back to restore. Mask Editor (right-click image → Open in Mask Editor, brush/eraser, grow_mask_by). Subgraphs (group nodes → collapse → reuse), Partial Execution (run selected branch), App Mode (simplified form over graph, flip back anytime), Groups/colors (organize base/refine/upscale passes). Settings: theme, keybindings, dev-mode (shows IDs for API), security_level, network_mode, front-end-version. Shortcuts: Ctrl+Enter queue, Ctrl+S/O save/open, Ctrl+M mute, Ctrl+D duplicate, Q search, Del delete, Ctrl+Z undo, R refresh, Ctrl+B bypass toggle, arrows navigate.

---

## 3. Architecture (how it really executes)

Client (JS frontend in `web/`) + Server (Python, diffusion/tensors) + optional API clients. Workflow = Dynamic DAG JSON: nodes = function operators (inputs → `FUNCTION` → outputs), links = typed edges. `PromptExecutor`: validate_prompt → reset per-run cache → ExecutionList (topological sort) → step loop (PENDING for async/subgraph) → progress over WebSocket (binary PREVIEW_IMAGE frames: 4B type + 4B image_type + bytes). Caching: `CacheKeySetInputSignature` hashes inputs+upstream IDs; unchanged = skip (why edits are fast); `IS_CHANGED` forces rerun (random/timestamp); mutating inputs in custom nodes is dangerous. V3 nodes: async, `_async_map_node_over_list` (auto-batches lists unless `INPUT_IS_LIST`), `check_lazy_status` (skip branches, e.g. If nodes), `new_graph` return (dynamic subgraph injection). Save format (titles + x/y/width/colors, for reopening) vs API format (numeric IDs only, no layout, for POST /prompt) — export via File → Export Workflow (API). Custom nodes: server-only (Python class, majority), client-only (JS UI tweak), independent (both, no direct RPC), connected (direct RPC, API-incompatible). Sources: docs.comfy.org development/*, horsten/comfyui-internals-doc, DeepWiki core-architecture.

---

## 4. Model folders — complete map

```
models/
├── checkpoints/      Load Checkpoint — SD1.5/SDXL/SD3/Flux-FP8-single
├── diffusion_models/ UNETLoader/Load Diffusion — Flux-split/Wan/LTX/Hunyuan (alias unet/, gguf/)
├── text_encoders/    DualCLIPLoader/CLIPLoader — clip_l, clip_g, t5xxl_fp16/fp8, umt5_xxl_fp8, qwen_2.5_vl_7b, byt5
├── vae/              VAE Loader — sdxl_vae, ae (Flux), qwen_image_vae, wan_vae, hunyuanvae
├── loras/            Load LoRA — style/character/motion/lightning (chain in series, strengths ±100, use 0–1)
├── controlnet/       SD1.5/SDXL/Flux Canny/Depth/HED/Union
├── clip_vision/      CLIP Vision Encode — clip_vision_h/g (I2V, IPAdapter prep)
├── upscale_models/   RealESRGAN/SwinIR/ULTRA-SHARP — .pth
├── embeddings/       textual inversion — .pt/.safetensors (+ EasyNegative etc.)
├── hypernetworks/    legacy; gligen/ grounding (rare)
├── ipadapter/        IPAdapter Plus weights (some setups); photomaker/ pulid/ insightface/ antelopev2 (face ID)
├── animatediff_models/ motion modules; audio/ (MMAudio checkpoints); sam/ (SAM/SAM2); detection/ (YOLO/RT-DETR)
```
`extra_model_paths.yaml` shares across UIs (a111 `models/Stable-diffusion|VAE|Lora|ControlNet|ESRGAN`, comfy `base_path + loras/checkpoints/vae/...`, `is_default:true` first). Refresh (R) after copy. Safetensors only (no .ckpt pickle from strangers).

---

## 5. Image models encyclopedia (all families, VRAM, license, ComfyUI files)

**How to read:** FP16 VRAM = weights only; add 2–4GB for VAE+encoders+workspace. Quantized = FP8 (~50%), GGUF Q4 (~35–40%), NF4 (~30%). Licenses matter for commercial use.

| Family | Arch/Params/Size | License | FP16 VRAM → Quantized | ComfyUI files → folders | Verdict |
|---|---|---|---|---|---|
| SD 1.5 (860M, 512px, 2022) e.g. Realistic Vision, DreamShaper, Deliberate | UNet | CreativeML OpenRAIL-M (permissive) | 2GB → 1GB | `checkpoints/*.safetensors` + `vae-ft-mse...` in `vae/` | 6GB king: 1–3s, endless LoRAs/ControlNets, best tutorials |
| SD 2.x (768px) | UNet + OpenCLIP | OpenRAIL | 3–4GB | same | skip — worse community than 1.5/XL |
| SDXL Base+Refiner (3.5B, 1024px, 2023) + Turbo (1–4 steps) | UNet 2-stage | Stability Community (free ≤$1M rev) / Apache for Turbo-ish | 7GB → 3.5GB FP8 | `sd_xl_base_1.0` + `refiner` in `checkpoints/`, `sdxl_vae` | workhorse 1024; your daily driver with --lowvram |
| SD 3 / 3.5 Medium 2.5B, Large 8B, Turbo 4-step (MMDiT, 2024) | MMDiT + CLIP-L/G + T5 | Stability Community | 8B≈16GB → FP8 ~8GB | `checkpoints/sd3.5_*.safetensors` or split + encoders | great prompt/text; Medium+FP8 viable on 12GB, tight on 6GB |
| Flux.1 Dev 12B / Schnell 4-step (flow DiT, BFL ex-SD team, 2024) | Rectified-flow transformer | Dev non-commercial / Schnell Apache-2.0 | 24GB → FP8 12GB / GGUF Q4 7–10GB | single `flux1-*-fp8` in `checkpoints/` OR split `diffusion_models/flux1-*.safetensors` + `text_encoders/clip_l+t5xxl_fp8` + `vae/ae.safetensors` + `ModelSamplingFlux` + `EmptySD3Latent` | quality king; Schnell-FP8/GGUF only on 6GB, Dev needs 12GB+ |
| Flux.2 Dev 32B / Klein 4B–9B (dense transformer, 2025–26) | 32B dense | Dev non-commercial / Klein Apache-2.0 | 32GB FP8 → Klein 13GB | same split + `qwen_3_8b` encoder | Klein 4B = sub-second commercial-safe; Dev = 24GB+ rigs |
| Flux 3 multimodal (video+audio+action, 2026) | Self-Flow | BFL | 24GB+ | partner/API nodes mostly | watch, not local-6GB |
| Chroma (Flux-fork uncensored) | Flux-compatible | community | 12GB+ | Flux LoRAs work | Flux quality w/o filter; 12GB+ |
| Qwen-Image 1.0 / 2.0 7B–20B + Edit (Alibaba, 2025–26, native 2K, bilingual text king) | MMDiT + Qwen3-VL encoder | Apache-2.0 | 12GB → FP8 8–12GB | `diffusion_models/qwen_image*_fp8*.safetensors` + `text_encoders/qwen_2.5_vl_7b_fp8` + `vae/qwen_image_vae` | best open text rendering; FP8 on 8–12GB, tight on 6GB |
| Z-Image / Z-Image Turbo 6B (2025) | DiT | Apache-2.0 | 12GB BF16 → Q4 4GB | `.gguf` in `gguf/` + `Qwen3-4B-GGUF` encoder (CPU) | speed champ on weak GPUs; Q4_K_M for your 6GB |
| HunyuanImage 3.0 80B-MoE/13B-active (Tencent 2025) | MoE | Tencent community (free <100M MAU) | 80GB INT8 → NF4 45GB | community nodes + block-swap | 48GB practical; 24GB experimental; skip on 6GB |
| Ideogram 4.0 9.3B / Krea 2 / FLUX.2-klein-class 2026 | DiT | mixed non-commercial/Apache | 13–32GB | partner nodes or NF4/GGUF | top photorealism/text if you have VRAM or use API |
| Pony/Juggernaut/DreamShaper-XL (SDXL finetunes, Civitai) | SDXL | own/Civitai | same as SDXL | `checkpoints/` | easiest quality jump: swap base for finetune |

Model sources: HuggingFace (`black-forest-labs`, `stabilityai`, `Qwen`, `Comfy-Org/*_ComfyUI` repacks, `city96/*-gguf`, `Wan-AI`, `Lightricks`, `Tencent-Hunyuan`), Civitai (finetunes/LoRAs, check license), OpenModelDB (upscalers). 2026 ranking (earngenix, tested): Krea 2 photoreal, Ideogram 4 text, FLUX.2 multi-ref, Qwen-Image-2 bilingual, Z-Turbo speed.

---

## 6. Video models encyclopedia

| Model | Params/License | VRAM → low path | Files → folders | Nodes/template | Notes |
|---|---|---|---|---|---|
| LTX-Video / LTX-2.x (Lightricks, Apache-2.0, bundled) | 2–5B | 6–8GB native | built-in + `checkpoints/ltxv*.safetensors` | `LTXV Loader/Sampler`, Prompt Enhancer; Template LTX-Video | START HERE on 6GB; fastest 480p seconds-long |
| Wan 2.1 T2V-14B/1.3B, I2V-14B/480p/720p (Alibaba, Apache-2.0) | 1.3B–14B | 1.3B ~8GB/15GB; 14B ~40GB → GGUF | `diffusion_models/wan2.1_*` + `text_encoders/umt5_xxl_fp8` + `clip_vision/clip_vision_h` + `vae/wan_2.1_vae` | native or WanVideoWrapper; Template Wan2.1 | 1.3B = your quality/VRAM sweet spot 480p/33f |
| Wan 2.2 TI2V-5B hybrid, T2V/I2V-A14B MoE, Fun-Control-A14B, S2V-audio, Animate/replace (Apache-2.0) | 5B–14B | 5B ~8GB offload; 14B GGUF+lightx2v-4step | `wan2.2_*` + same encoders + `wan2.2_vae` | Templates Wan2.2 5B/T2V/I2V/FLF; Fun-Control Canny/Depth/Pose/MLSD/trajectory | 5B does T2V+I2V in one; lightning LoRA 20→4 steps CFG 1 |
| HunyuanVideo 1.0 13B / 1.5 8.3B distilled (Tencent) | open | 1.5: 24GB → FP8 8.3GB file, Wan2GP 6GB experimental | `Comfy-Org/HunyuanVideo_1.5_repackaged` split + `qwen_2.5_vl_7b_fp8` + `byt5_small` + `hunyuanvideo15_vae` + optional `1080p_sr` | `EmptyHunyuanVideo15Latent`, CustomSampler, `VAEDecodeTiled`, EasyCache/MagCache 1.7x | flagship quality on consumer 24GB; skip real-time on 6GB except Wan2GP toy |
| Mochi-1 / CogVideoX / SVD (svd/svd_xt 14/25f) / AnimateDiff (SD1.5 motion LoRA) | mixed open | SVD/AnimateDiff ~6GB | `checkpoints/svd*.safetensors`, `animatediff_models/` | `SVD_img2vid`, AnimateDiff Evolved, VHS suite | retro but WORKS on 6GB: SD1.5 stills → 2–4s morphs |
| Frame interpolation (RIFE/FILM/IFRNet/AMT/GMFSS/FLAVR/CAIN/M2M/STMFNet via ComfyUI-Frame-Interpolation, 16 nodes) | — | cheap | interpolation models | VFI nodes after Save Video | 24→48/60fps smoothing; essential for short gen clips |
| Audio: MMAudio (44kHz V2A/T2A, bundled), ACE-Step 1.5 music, LTX-2.5 A2V lip-sync, MiniMax H3, Seedance/Kling/Hailuo (partner/API/cloud) | mixed | varies | `audio/` + VAE | `MMAudio Sample`, S2V chunked 77f LatentCut/Concat | silent clip + text → sound; minute-long via chunked latents |

Video settings that won't OOM (6GB): 480p (832×480), 33–49f (2s @16–24fps), steps 20 / lightning 4, CFG 6 / 1, FP8 encoders, `--lowvram --disable-pinned-memory`, `VAEDecodeTiled`, image-first then I2V, EasyCache/MagCache on reruns.

---

## 7. Samplers/schedulers bible (44 samplers × 9 schedulers)

Sampler = denoising algorithm; scheduler = noise-pacing curve. Keep workflow pairs together; change one variable at a time.

| Sampler | Speed/Quality | Pair with | Use |
|---|---|---|---|
| euler | fast/reliable | simple/normal | previews, general default |
| euler_ancestral (+cfg_pp) | textured/chaotic | simple | art, variation |
| heun/heunpp2 | slow/stable | karras | photoreal alt |
| dpm_fast | fastest draft | exponential | thumbnails only |
| dpmpp_2m (+cfg_pp) | balanced BEST DEFAULT | karras | most finals (ComfyLab pick) |
| dpmpp_2m_sde(+gpu) | smooth portraits | karras | faces/gradients (+VRAM) |
| dpmpp_3m_sde(+gpu) | max fidelity slow | karras | hero renders |
| dpmpp_sde(+gpu) | clean gradients | karras | realism |
| ddim/ddpm | legacy deterministic | ddim_uniform | reproducibility/old graphs |
| res_multistep | turbo-only fast | simple | Turbo/distilled only |
| Custom: SamplerCustomAdvanced + KSamplerSelect + BasicScheduler + CFGGuider + SamplerSettings + KSampler Inputs (AUN) | — | — | multi-sampler graphs, one knob for many samplers |

Schedulers: `simple/normal` even/linear (stable, Flux-flow safe), `karras` mid-late detail boost (SD1.5/SDXL default, WRONG for flow-matching Flux/Z/Qwen — causes distortion; use simple/sgm_uniform there), `exponential` aggressive early (sharp, avoid on Z-Turbo), `sgm_uniform` (Flux native), `ddim_uniform/beta/linear_quadratic/kl_optimal` (legacy/special), RES4LYF `beta57` lives in separate pack. Precision: `--fp16-text-enc/--fp32/--bf16`, `--force-upcast-attention` (fix black images) vs `--dont-upcast-attention` (debug).

Recipes: draft 15–20 steps CFG 7 euler/karras denoise 1; standard 25–30 CFG 7–8 dpmpp_2m/karras; HQ 40–50 CFG 7–8 dpmpp_2m_sde/karras; Turbo/Schnell/Lightning 4–8 steps CFG 1–3 euler/simple; I2I denoise 0.5–0.8; hi-res-fix second pass 0.3.

---

## 8. Core techniques (exact chains)

- **T2I:** Checkpoint → CLIP± → EmptyLatent → KSampler → VAE Decode → Save.
- **I2I:** Load Image → VAE Encode → KSampler denoise .65.
- **Inpaint:** mask editor → `VAE Encode (for Inpaint)` (grow_mask_by feather) → dedicated `*-inpainting` checkpoint → KSampler; uses: object removal, face/body fix, texture edit.
- **Outpaint:** `ImagePadForOutpaint` (direction+range → image+mask) → inpaint model, same prompt for style match; uses: widen scene, aspect fix.
- **ControlNet:** image → preprocessor (`comfyui_controlnet_aux`: Canny/Scribble_XDoG/DiffusionEdge/Depth/Metric3D-Normal/UniFormer-SemSeg/LineArt/AnimeLineArt/OpenPose/MediaPipe-FaceMesh/Binary/Luminance) → Load ControlNet → Apply (strength .6–1, start/end %) → sampler. Advanced-ControlNet schedules strength over steps/batches + masks. Flux Canny/Depth via x-flux.
- **IPAdapter Plus:** `IPAdapterUnifiedLoader` (VIT-G) + reference → style inject; weight ≤.9; Triple-ControlNet+IPAdapter+Chibi-LoRA for HD illustration; prep via `PrepImageForClipVision`.
- **UltimateSDUpscale/tiled hi-res:** base 768 → `UltimateSDUpscale(NoUpscale/CustomSample)` tile+ControlNet-Tile → ESRGAN/ULTRA-SHARP/NMKD-Siax; or latent upscale + 0.3 denoise; SUPIR for photo restoration.
- **Detailers:** Impact `FaceDetailer/DetailerForEach` (detect → crop → repaint → paste), iterative upscaler, SEGS filtering, RegionalPrompt.
- **Segment/mask:** SAM/SAM2 + GroundingDINO text-pick, BiRefNet/RMBG/BEN2/Inspyrenet bg remove, `easy imageRemBg`, Mask Editor/Overlay/Enhancer.
- **Identity:** PuLID-Flux (fidelity slider, multi-projection), InstantID, Reactor; training-data prep workflow (SDXL+PuLID+ControlNet+StableSR multi-view).
- **Lighting:** IC-Light relight, IPAdapter+ControlNet+SDXL-Enhance product/bg swap, Flux Fill/Redux inpaint/variation, watermark remove (Florence2/GroundingDINO+SAM → inpaint).
- **Video:** T2V/I2V/FLF (first-last frame)/V2V/Reference-to-Video/Multi-image-to-video (OmniWeaving on Hunyuan1.5), Fun-Control (Canny/Depth/Pose/MLSD/trajectory), S2V audio-driven chunked 77f, RIFE interpolate, VHS helpers (Split/Merge/Select latents+masks), CreateVideo → SaveVideo/GIF/MP4.

---

## 9. Custom nodes encyclopedia (install one at a time, restart, fixed-seed test)

Tier 0 (have via flake, do nothing): Model Downloader (async + `/api/download_model|progress|list`), Impact Pack 197 nodes (v8.28), rgthree (Reroute/Context/PowerLoRA/Bookmark), KJNodes, GGUF 6 nodes (Unet/CLIP/Dual/Triple/Quad GGUF), LTXVideo, Florence2 (caption/detect/OCR/VQA), bitsandbytes-NF4, x-flux (LoRA/ControlNet/IPAdapter 12GB-opt), MMAudio, PuLID (+setup doc), WanVideoWrapper (+SkyReels/Story mode). Deps prebuilt (sam/sam2/opencv/color-matcher/gguf/diffusers/librosa/bitsandbytes).
Tier 1 (install next by objective): Manager (meta) → Efficiency Nodes (batch/KSampler clones) → IPAdapter Plus (6.1K★) → WAS Suite 217 nodes (blur/sharpen/morph) → controlnet_aux 64 nodes (4.1K★) → UltimateSDUpscale 3 nodes → Advanced-ControlNet (timestep/batch scheduling) → Comfyroll (Multi-ControlNet/Aspect/Switches — needs FULL restart for font patch) → essentials/Inspire/Subpack/Use-Everywhere/Custom-Scripts (CheckpointLoader/Math/SystemNotify/Repeater/ShowText/Constrain) → tinyterra → segment_anything (GroundingDINO+SAM) → Fooocus-inpaint/LaMa/MAT → InstantID → AnimateDiff-Evolved → VideoHelperSuite 40 nodes → Frame-Interpolation 16 → ComfyUI-3D/PhotoMaker/CRM-HY3D → SUPIR → RMBG/BiRefNet → MagCache (1.7x video) → LightX2V → hunyuan1.5-plugin → NVFP4-Quantizer (SDXL/Wan/Qwen/Flux) → Realtime-LoRA-Trainer/FL-Kohya/FluxTrainer-Pro → QHNodes/AUN (SamplerSettings/KSamplerInputs central knobs) → RES4LYF (beta57) → pysssss. Registry: https://registry.comfy.org (1400+), Cloud supported list = safe subset. Rule: stage one pack → fixed-seed compare → check logs → snapshot; never update-all blindly.

---

## 10. Manager complete

Built-in core (enable `--enable-manager`; Desktop pre-on; Portable `pip install -r manager_requirements.txt`). New UI: left filters (installed/in-workflow/missing/updatable), top search (Pack vs Node), right detail (desc/enable/version), Install specific version / Update arrow / Uninstall, Missing → Install All / Open Manager. Legacy UI keeps git-URL install (new UI registry-only; git via `git clone` + `requirements.txt` + `install.py` + restart). Publish: git repo + PR editing `custom-node-list.json` (+`node_list.json` if unconventional, `pip_overrides`, `alter-list.json`, channels). Comfy CLI alternative: `comfy node install/update/bisect`. NixOS: installs land in `<dataDir>/.venv` (Nix precedence, `COMFY_VENV_PRECEDENCE=prefer-venv` to flip), default config `security_level=normal network_mode=personal_cloud`; declarative instead via `services.comfyui.customNodes/extraPythonPackages`.

---

## 11. Quantization bible (run big models on small VRAM)

FP16/BF16 baseline → FP8 (per-tensor absmax scale, E4M3/E5M2, ~50% size, <1% loss; FP8-matrix-mult needs SM≥89 Ada+; Qwen/Flux FP8_HQ/mixed/NVFP4 variants) → GGUF (llama.cpp K-quants: Q8_0 8.5b near-lossless, Q6_K 5.2GB sweet, Q4_K_M 4.5b slight loss Pareto winner over NF4 at same size per 2026 Ideogram study, Q3_K_S 3.2b moderate; DiT/transformer-only, conv2D-UNet not feasible) → NF4 (bitsandbytes 4-bit NormalFloat, Flux-Dev path) → NVFP4/MXFP8 (microscaling E8M0 blocks, Blackwell SM≥100 + torch≥2.10 + comfy-kitchen, else silent dequant correct-but-slow) → INT8 W8A8 (Ampere INT8 GEMM path). Practice: text encoders to FP8/GGUF-Q4 on CPU first (biggest free saving), diffusion to Q6_K (8GB) / Q4_K_M (6GB, e.g. Z-Turbo 1024 8 steps 8–15s on 3060), keep VAE FP16, never quantize already-quantized, keep source. Nodes: `UnetLoaderGGUF (+Advanced)`, `Dual/Triple/QuadCLIPLoaderGGUF`, `CheckpointLoaderNF4`, Universal FP8/NVFP4 Quantizer (presets balanced/quality/aggressive/fp8_all, estimate_only first). Comfy-Org `comfy-quants` exports MXFP8 natively loadable.

---

## 12. Performance/VRAM bible + full CLI flags

Eight levers: 1) resolution (1024→768 halves VRAM; 720p→480p for video), 2) batch 1, 3) steps to model norm (don't 30-step a 4-step Turbo), 4) FP8/GGUF encoders+weights, 5) flags below, 6) tiled VAE (`VAEDecodeTiled`), 7) cache (Easy/MagCache, `.cache/` reuse, first-gen slow normal), 8) close VRAM hogs (browsers/Electron) + previews.
Profiles: 4GB → SD1.5-512 + Z-Q3 + LTX-480p-25f; 6GB (YOU) → SD1.5 full, SDXL-768 + ESRGAN, Schnell-FP8/GGUF-Q4 4-step, LTX-480p, Wan-1.3B-480p-33f, lightning-4step; 8GB → SDXL-1024, Schnell-Q6, Qwen-FP8, Wan-5B; 12–16GB → Flux-Dev-FP8, Wan-14B-GGUF, ControlNet+IPAdapter stacks; 24GB → Flux-Dev, Hunyuan1.5-720p, Qwen-2 native; 48–96GB/cloud → HunyuanImage-3-NF4, Flux.2-32B, 1080p-SR.
Full `main.py` flags (from `comfy/cli_args.py` + startup-flags doc): `--listen [IP,] (bare=0.0.0.0,::) --port 8188 --enable-cors-header --max-upload-size 100 --base-directory --extra-model-paths-config --output-directory --temp-directory --front-end-version --list-feature-flags --cache-ram [active inactive] --cache-classic --high-ram --lowvram (encoders→CPU) --novram (more) --disable-async-offload --async-offload [streams] --disable-dynamic-vram --fp16/32/bf16-text-enc --force/dont-upcast-attention (black-image fix) --fast [fp16_accumulation fp8_matrix_mult cublas_ops autotune] --deterministic --default-hashing-function --cuda-device 0|all --oneapi-device-selector --disable-xformers --use-pytorch-cross-attention --force-fp16 (Mac) --windows-standalone-build --enable-manager(--legacy-ui) --disable-api-nodes`. Your service: `--lowvram --disable-pinned-memory --enable-manager`.

---

## 13. Prompting science (image + video)

Image formula: subject+action, environment, light, lens/style, quality tags (“portrait of beekeeper, morning apiary, soft backlight, 85mm f1.8, photoreal, sharp focus”); negative (SD1.5/XL only): “blurry, lowres, deformed hands, extra fingers, watermark, text, oversaturated”; Flux/Schnell/Turbo/Qwen: plain language, empty negative OK, 1K-token instructions supported (Qwen slides/posters/infographics/comics, bilingual EN+ZH). CFG: XL 5–7, 1.5 6–8, distilled 1–3, Wan 6/1-lightning; over-8 = burnt. One idea/prompt; shorten before raising CFG. Video formula: start + motion + camera + light (“still pond dawn, mist drifts left, slow dolly in, volumetric, 24fps”); no motion words = slideshow; LTX Prompt Enhancer + Wan prompt guide for cinematic control (lighting/color/composition). Seed: -1 explore → lock refine. Text rendering: Qwen/Ideogram/Flux.2 > SD3.5 > Flux.1 > XL > 1.5.

---

## 14. Training LoRA (personalize models)

Theory: low-rank matrices on frozen base (rank/dim 32–128 XL, alpha=dim), ~50 quality images ideal, 1024² crops (birme.net bulk), WD14 captions, folder `N_Name` (N×images≈1000 steps), buckets on (256–2048), cache latents+encoder to disk, bf16/fp16, Adafactor/AdamW 1e-5–3e-4, constant_with_warmup, 6–30 epochs save-every-1, dropout .05, min-SNR 5, gradient checkpointing. Test every epoch same-seed no-refiner. Paths: Kohya_ss GUI (40min/person on 4080, needs 24GB for XL recipe), ai-toolkit, ComfyUI-native Realtime-LoRA-Trainer/FL-Kohya-Train (SD1.5/XL, chainable latest-resume, blocks queue, outputs to `output/FL_train_workspaces`), FluxTrainer-Pro (Klein-9B/Dev-32B, none/conservative/aggressive/extreme offload → 8GB possible, dim/alpha/LR/steps + validate/save sched + memory estimator). Flux/SDXL/Z/Wan-2.2 all supported; Flux LR lower than 1.5. Data prep workflow: SDXL+PuLID+ControlNet+StableSR multi-view.

---

## 15. Automation/API/CLI/MCP (run without clicking)

Export File → Export Workflow (API) (numeric IDs, no layout). REST: `POST /prompt {prompt: graph, extra_data:{api_key_comfy_org}}` → prompt_id; `GET /history`, `/view?filename`, `/queue`, `/interrupt`; WS `/ws?clientId=uuid` streams progress + binary previews; `SaveImageWebsocket` returns bytes directly (basic_api_example.py / websocket_api_example.py in `script_examples/`). SDKs: `pip install comfy-sdk` / `npm i @comfyorg/sdk` → `from_file/from_json`, `wf.set_input("3","seed",42)`, `client.run(wf)`, `job.get_outputs("9")`, progress events, API v2 (poll-first, idempotent, UUID assets blake3, SSE enhancement). comfy-cli: `comfy generate <alias> --prompt --image --download` (flux-pro/ideogram-edit/kling/nano-banana/dalle; `list --partner/--category/--query`, `schema <model>`, `refresh`, `upload` 24h-signed GCS), `comfy run/templates/watch`, `comfy setup --where cloud`, `comfy skills install` (5 agent skills for Claude/Codex/Cursor/Gemini/OpenClaw/Hermes), `comfy cloud login` (1h token). MCP: Cloud MCP (hosted) / Local MCP (`COMFY_URL=http://127.0.0.1:8188 comfy-mcp-server`, tools list_embeddings/get_system_stats/load_workflow/list|set|get_node_param/upload_image/run_workflow) + comfy-api-simplified wrapper + comfyui-workflow CI runner. Same SDK targets Cloud/serverless/self-hosted+proxy — only base URL changes.

---

## 16. Workflow library (where to get + what to run)

In-app `Workflow → Browse Templates` (official Core-only, auto-download prompts) + https://comfy.org/workflows (100s: Wan2.2-14B-T2V/I2V/S2V/Animate/Fun-Control, Hunyuan1.5-T2V/I2V-720p+1080pSR, LTX, Flux-T2I, SD3.5, Qwen, IPAdapter/ControlNet/Inpaint/UltimateSD, character-design, bg-replace, V2V-animation, Topaz-upscale, MiniMax-H3, FLUX3-video, Seedance) + comfyui-wiki tutorials (Wan2.2 T2V/I2V/GGUF, Fun-Control, SD3.5-FP16/FP8, Flux family, outpaint) + docs.comfy.org tutorials (ControlNet-scribble, LoRA-blindbox, inpaint-512, outpaint-pad, Flux-dev/schnell, Wan2.2, Hunyuan1.5-T2V/I2V+SR) + Civitai PNGs (drag back = full graph) + `Comfy-Org/example_workflows` (Wan Fun MP4s+JSON) + CastilloworksAi/comfyui-workflows (offline E2E incl. training). Keep 6GB starter set: Basic-T2I, SDXL-LoRA, I2I-denoise, Inpaint-mask, Outpaint-pad, ESRGAN-upscale, FaceDetailer, LTX-T2V/I2V, Wan1.3B-T2V, Wan2.2-5B-I2V, MMAudio, RIFE-interp.

---

## 17. Troubleshooting bible

Boot: torch-from-source (cachix keys), `services.comfyui.enable collision` (flake auto-disables nixpkgs one — don't import both), missing-Python (venv precedence), Comfyroll-fonts (FULL restart), Manager-soft-restart-noop, port-in-use (`--port 8189`), LAN-unreachable (`--listen 0.0.0.0`+firewall), `/var/lib` perms (match user/group), git-untracked-nix-file (git add), dirty-tree warning (normal). Graph: empty dropdown (wrong folder/R), missing-node (Install All + restart), red-type-mismatch (MODEL≠IMAGE), black images (`--force-upcast-attention`), melted faces (lower LoRA, FaceDetailer, 0.3 hi-res), static video (add motion verbs, frames>25), OOM (resolution→batch→FP8→flags→close browsers), slow-first-gen (kernel cache normal), Karras-on-Flux distortion (use simple/sgm_uniform), Turbo-burnt (steps→4–8 CFG→1–3), ControlNet-rigid (strength .85→.6, end% 0.8), IPAdapter-overstyle (weight ≤.9), VAE-mismatch-black/blank (match VAE), xformers-OOM (pytorch-attention fallback), pinned-memory (disable flag), NaN-fp16 (bf16/fp32 encoder), ROCm gfx-unsupported (only 1100 tested), XPU FP64 (emulation env), Docker-GPU-invisible (toolkit/CDI/`/dev/dri`). Logs: `journalctl -u comfyui -f | grep -iE 'cuda|vram|error|fail'`, `nvidia-smi -l 1`, Manager update-one-at-a-time + fixed-seed bisect (`comfy node bisect`).

---

## 18. Security / licenses / ethics

Never put API keys in Nix `settings/environment` (world-readable /nix/store) — use `environmentFiles`/sops/0600 files; `extra_data.api_key` per-request. `--listen 0.0.0.0` + CORS = LAN-exposed queue — firewall + reverse-proxy auth for shared hosts. Safetensors-only from strangers (pickle RCE in .ckpt/.pt/.bin). Civitai licenses vary (no-commercial common) — check before selling; safe commercial: SDXL-permissive, Flux-Schnell/Klein-Apache, Qwen-Apache, Wan-Apache, LTX-Apache, SD3.5/Stability ≤$1M, Hunyuan <100M MAU, Ideogram/Flux-Dev non-commercial (use API/Cloud commercial-cleared instead). Cloud = all-models commercial-cleared via credits. Faces/NSFW: PuLID/InstantID need consent; CHROMA-uncensored exists — you own liability. NDA work → local-first (your setup already), no cloud pixels.

---

## 19. Resources — every link that matters

Official: https://docs.comfy.org (manual/models/LoRA/ControlNet/Flux/Wan/Hunyuan/sampling/cli_args/api-examples/v2/SDK/MCP) + llms.txt index, https://comfy.org (+/workflows /cloud /download /enterprise /cli /pricing), https://github.com/Comfy-Org/ComfyUI (+cli_args.py, nodes_custom_sampler.py, script_examples), https://github.com/Comfy-Org/ComfyUI-Manager (+custom-node-list.json), https://github.com/Comfy-Org/comfy-cli (+cmdline.py), https://github.com/Comfy-Org/comfy-python-sdk, https://registry.comfy.org (1400+ nodes), https://cloud.comfy.org, https://platform.comfy.org (keys). Wiki/guides: https://comfyui-wiki.com (models/flux, sd3.5, wan2.2, fun-control, samplers, templates), https://comfy-ui.net + https://comfy-ui.io (+faq/workflows/error-recovery/production-checklist), https://comfylab.dev (KSampler/VRAM/GGUF guides), https://comfyui.dev (sampler/scheduler tables), https://comfy.icu (node docs: SamplerSettings/KSamplerInputs/FL-Kohya), https://comfyuiweb.com (flux models/extensions dir), https://runcomfy.com (trainer/node guides), https://viewcomfy.com (LoRA guide), https://neurocanvas.net + https://promptzone.com (desktop-vs-portable). Models: HF orgs `black-forest-labs stabilityai Qwen Wan-AI Lightricks Tencent-Hunyuan Comfy-Org Comfy-Org/*_ComfyUI city96 justabigduck DiffSynth-Studio`, Civitai, OpenModelDB, ModelScope mirror. Video: `Tencent-Hunyuan/HunyuanVideo-1.5`, LightX2V, Wan2GP, MagCache, OmniWeaving. Nix: `utensils/comfyui-nix` (+flake.nix/CHANGELOG/docs/pulid-setup), `Lodjuret/nixified-ai`, `NexRX/comfyui-nix-rocm`, Discourse 71471, `horsten/comfyui-internals-doc`, DeepWiki architecture. Papers: Qwen-Image-2.0 arXiv:2605.10730, Ideogram-INT8/GGUF arXiv:2606.12280, SD3 paper, Karras-2022 schedule. Community: Comfy-Org Discord/GitHub-discussions, r/comfyui, Civitai forums, ComfyUI-Wiki comments.
Glossary: checkpoint/diffusion/UNet/DiT/MMDiT/flow-matching/latent/VAE/CLIP/conditioning/LoRA/LyCORIS/embedding/ControlNet/IPAdapter/sampler/scheduler/steps/CFG/denoise/seed/sigmas/quant (FP8/GGUF/NF4)/offload/VRAM/pinned-memory/xformers/T2V/I2V/V2V/FLF/SR/inpaint/outpaint/hi-res-fix/tiles/SAM/pose-Canny-Depth/subgraph/API-format/DAG/PENDING/cache-signature.
FAQ: nodes-vs-forms (auditability), which model on X GB (§5–6 tables), why red nodes (missing pack), why slow first run (kernels), cloud-vs-local (custody/latency/NDA), API-automation (yes: REST/WS/SDK/CLI), commercial (see §18), 6GB-video-possible (yes: LTX/Wan-1.3B/AnimateDiff/SVD).

---

## 20. Cheat sheets + YOUR quickstart

**KSampler:** draft euler/15–20/CFG7/karras/den1 · standard dpmpp_2m/25–30/7–8/karras · HQ dpmpp_2m_sde/40–50/7–8 · distilled 4–8/1–3/euler-simple · I2I denoise .5–.8 · fix .3 · Flux-flow NEVER karras (simple/sgm_uniform).
**Folders→nodes:** checkpoints→LoadCheckpoint · diffusion/unet→UNET · text_encoders→DualCLIP · vae→VAELoader · loras→LoadLoRA(chain) · controlnet→Apply · clip_vision→I2V · upscale→RealESRGAN · embeddings→prompt `embedding:name`.
**Flags:** always `--lowvram --disable-pinned-memory --enable-manager` (you); black→`--force-upcast-attention`; xformers-OOM→`--use-pytorch-cross-attention`.
**API 10s:** Export-API → `POST /prompt` → poll `/history` → `GET /view`; batch via `comfy-cli`/SDK `set_input`.
**YOUR tonight (6GB):** 1) `nix run ...#cuda -- --open --lowvram --enable-manager` smoke-test → 2) SD1.5-512 + SDXL-768 (§5 URLs) → 3) ESRGAN-upscale → 4) `switch` to service (already configured) → 5) LTX-480p-33f from best still → 6) Wan-1.3B same still → 7) Schnell-FP8-4step only if hands/text hurt. Full model URLs + service ops in `comfyui-nixos-guide.md`; hands-on builds in `comfyui-usage-guide.md`; this file = why behind every step.
