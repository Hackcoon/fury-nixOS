# ComfyUI Usage Guide — UI, Models, Nodes, Workflows
## For your install: NixOS service, data in `/home/fury/comfyui-data`, GTX 1660 SUPER 6GB

This is the hands-on companion to `comfyui-nixos-guide.md` (install + drivers + VRAM tuning).
This file answers: *how do I actually use it, where do models go, what does every box do?*

Open the UI: http://127.0.0.1:8188 (after `sudo systemctl start comfyui`).

---

## 1. UI tour (new ComfyUI frontend)

```
+---------------------------------------------------------------+
| Top bar: Workflow | Queue (▶) | Manager | Settings (gear)     |
+--------+------------------------------------------------------+
| Left   |                                                      |
| side   |              INFINITE CANVAS                         |
| bar:   |   [Load Checkpoint]──►[CLIP Text Encode +]──►        |
| Nodes  |   [Empty Latent]───────────────────────►[KSampler]──►|
| Models |   [VAE Decode]──►[Save Image]                         |
| Queue  |                                                      |
| History|   Right-click empty canvas = Add Node menu           |
+--------+------------------------------------------------------+
| Bottom: Queue status, VRAM meter, logs, progress bar          |
+---------------------------------------------------------------+
```

Key areas:

- **Canvas** — infinite zoom/pan (wheel = zoom, drag empty space = pan, `Space+drag` also pans). All work happens here.
- **Nodes** — boxes with inputs (left dots), outputs (right dots), widgets (dropdowns/sliders inside). Drag output dot → input dot to connect. Colors: red = error/missing, grey = idle, green = running.
- **Top bar Queue (▶) / Ctrl+Enter** — runs the current workflow. `Queue` adds one job; auto-queue/Bayesian options are in the queue dropdown — leave on manual.
- **Workflow menu** — `Open (Ctrl+O)`, `Save`, `Browse Templates` (official + custom-node example workflows), `Export (API format)` for scripting.
- **Manager button** (only if `--enable-manager` / `enableManager=true`, which you have) — install custom nodes, models, update all.
- **Left sidebar** — Node Library (search any node by name), Model Library (shows detected checkpoints/LoRAs), Queue/History (past generations + their settings + embedded workflows).
- **Image preview** — click any `Preview Image` / `Save Image` node output to enlarge, compare, and read metadata (seed, steps, CFG, model). **Any PNG you save embeds its full workflow JSON** — drag it back onto the canvas to restore it exactly.
- **Settings (gear)** — theme, keybindings, `security_level`, `network_mode`. Leave defaults.

Keyboard essentials:

| Key | Action |
|-----|--------|
| `Ctrl+Enter` | Queue prompt (run) |
| `Ctrl+S` / `Ctrl+O` | Save / Open workflow JSON |
| `Ctrl+M` | Mute/unmute selected nodes (bypass without deleting) |
| `Delete` / `Backspace` | Delete selection |
| `Ctrl+D` or drag+`Alt` | Duplicate nodes |
| `Q` / double-click empty | Node search palette |
| `Space+drag`, wheel | Pan / zoom |
| `Ctrl+Z` | Undo canvas edit |

Right-click canvas → `Add Node` is the slowest way; use `Q` search instead.

---

## 2. Core mental model: 5 stages

Every image workflow, no matter how fancy, is:

1. **Load weights** — checkpoint / diffusion model + encoders + VAE.
2. **Encode prompt** — text → conditioning vectors (CLIP).
3. **Make latent** — empty noise canvas (`Empty Latent`) or encode an existing image (`VAE Encode`).
4. **Sample** — `KSampler` denoises latent step-by-step (this is where GPU + time goes).
5. **Decode + save** — `VAE Decode` latent → pixels → `Save/Preview Image`.

Video adds: more frames in latent, a video VAE, `Save Video` instead of image, and motion-aware samplers (WanVideo Sampler, LTX Sampler). Audio adds `MMAudio` at the end.

---

## 3. Loading models — where files go and which node reads them

Your models live under:

```
/home/fury/comfyui-data/models/
├── checkpoints/       # SD1.5, SDXL, Flux-FP8 single-file  (.safetensors)
├── diffusion_models/  # Flux-split, Wan, LTX diffusion     (.safetensors) — alias: unet/
├── text_encoders/     # clip_l, t5xxl_fp16/fp8, umt5       (.safetensors)
├── vae/               # sdxl_vae, ae (Flux), wan_vae       (.safetensors)
├── loras/             # style/character add-ons            (.safetensors)
├── controlnet/        # Canny/Depth/Pose guides            (.safetensors/.pth)
├── clip_vision/       # clip_vision_h (Wan image-to-video) (.safetensors)
├── upscale_models/    # RealESRGAN etc.                    (.pth)
├── embeddings/        # textual inversions                 (.pt/.safetensors)
├── hypernetworks/     # legacy (rare now)
└── gligen/            # grounding (rare now)
```

Rules:

1. **Filename = menu entry.** Put `foo.safetensors` in the right subfolder → it appears in that loader's dropdown. Subfolders are also scanned (e.g. `loras/anime/foo.safetensors` works).
2. **Refresh after copying.** Press `R` on canvas or `Manager → Refresh` or restart UI; loaders cache the file list.
3. **Match loader to folder.** `Load Checkpoint` only sees `checkpoints/`. `UNETLoader` / `Load Diffusion Model` only sees `diffusion_models/` + `unet/`. `Load LoRA` only `loras/`. Mismatch = empty dropdown = wrong folder.
4. **Prefer `.safetensors`.** Never download `.ckpt` + `.pkl` from random sources (pickle = arbitrary code). All links in the install guide are safetensors.
5. **Three ways to download:**
   - `wget` into the folder (see install guide §5.3 for exact URLs).
   - Manager → `Model Manager` → search → Install (downloads to correct folder automatically).
   - Bundled **Model Downloader** node/API: `POST /api/download_model` with URL+folder, watch `GET /api/download_progress/{id}` — non-blocking, UI stays responsive.
6. **Gated models (Flux Dev)** need a HuggingFace login + accepted license before `wget` works. Use browser download or `huggingface-cli download` with token, then `mv` into folder.

Quick verification: after adding one checkpoint, add node `Load Checkpoint` (`Q` → type it) — your file must appear in its `ckpt_name` dropdown. If not, wrong folder or needs refresh.

---

## 4. What every important node does

### 4.1 Model loaders

| Node | Reads from | Outputs | When to use |
|------|------------|---------|-------------|
| `Load Checkpoint` | `checkpoints/` | `MODEL` + `CLIP` + `VAE` (all three at once) | SD1.5 / SDXL / Flux-FP8-single-file. Simplest path. |
| `UNETLoader` / `Load Diffusion Model` | `diffusion_models/` | `MODEL` only | Flux-split, Wan, LTX. Pair with `DualCLIPLoader` + `VAE Loader`. |
| `DualCLIPLoader` | `text_encoders/` | `CLIP` | Flux/Wan need two encoders (e.g. `clip_l` + `t5xxl_fp8`). Params: `type: flux/sd3/wan`. |
| `CLIPLoader` (single) | `text_encoders/` or `clip/` | `CLIP` | Legacy / SD1.5 CLIP. Rarely needed now. |
| `VAE Loader` / `Load VAE` | `vae/` | `VAE` | When checkpoint didn't bundle one, or you want `sdxl_vae` / `ae.safetensors` explicitly. |
| `Load LoRA` | `loras/` | `MODEL`+`CLIP` (modified) | Style/character overlay. Chain multiple in series. `strength_model` + `strength_clip` 0–1 (0.6–0.9 typical). Negative values invert. |
| `Load ControlNet` + `Apply ControlNet` | `controlnet/` | conditioning modifier | Pose/edge/depth guidance. `strength` 0.6–1.0, `start/end percent` controls when in sampling it applies. |
| `Load Upscale Model` + `Upscale Image` | `upscale_models/` | `IMAGE` | RealESRGAN x4. Generate small → upscale (key 6GB trick). |
| `Load CLIP Vision` | `clip_vision/` | `CLIP_VISION` | Wan image-to-video only (`clip_vision_h.safetensors`). |

### 4.2 Prompt / conditioning

| Node | What it does |
|------|--------------|
| `CLIP Text Encode (Prompt)` | Text → conditioning. Wire positive to KSampler `positive`, negative to `negative`. Flux: negative optional (leave empty). |
| `Empty Latent Image` | Blank noise canvas for SD1.5/SDXL. Set `width/height` (512 for SD1.5, 1024 for SDXL), `batch_size: 1` on 6GB. |
| `EmptySD3LatentImage` | Blank canvas for Flux/SD3/Wan (different latent channels). Same width/height logic. |
| `Load Image` + `VAE Encode` | Image-to-image / img2vid input. `VAE Encode` converts pixels → latent for KSampler. |
| `VAE Decode` | Latent → pixels after sampling. Needs `VAE` input. |

### 4.3 The sampler (where quality/time comes from)

`KSampler` inputs: `model`, `positive`, `negative`, `latent_image`. Outputs: `LATENT`.

Widgets that matter:

- **`seed`** — `-1` = random each run. Lock a good number to reproduce. `Ctrl+click` dice = randomize. History panel shows past seeds.
- **`steps`** — denoising iterations. SDXL 20–30, SD1.5 20–25, Flux Schnell/Turbo 4, Flux Dev 25–30, Wan standard 20 / lightning 4. More steps ≠ always better; diminishing returns past ~30.
- **`cfg`** — how hard to follow the prompt. SDXL 5–7, SD1.5 6–8, Schnell/Turbo 1–3, Wan standard 6 / lightning 1. Too high = oversaturated/burnt.
- **`sampler_name`** — `euler` (safe default), `euler_ancestral` (more varied), `dpmpp_2m` (detailed, slower), `dpmpp_sde` (best faces, slowest). Stick to `euler` until you have a reason.
- **`scheduler`** — `normal` (default), `karras` (sharper, popular with SDXL), `exponential`, `sgm_uniform` (Flux). `karras` is the common SDXL upgrade.
- **`denoise`** — 1.0 = pure text-to-image (ignore input image). 0.5–0.8 = image-to-image (keep composition, restyle). Below 0.4 = near-copy.
- **`ModelSamplingFlux`** — extra node only for Flux-split workflows; sets shift/sigma schedule. Leave default.

On 6GB: `steps` and resolution move VRAM/time most. Halve resolution before cutting steps.

### 4.4 Output

| Node | Purpose |
|------|---------|
| `Save Image` | Writes to `output/` + shows preview. `filename_prefix` organizes (e.g. `sdxl/portrait`). Metadata embeds workflow. |
| `Preview Image` | Preview only, no disk write. Use while iterating, swap to Save for keepers. |
| `Save Video` / `Preview Video` | Same for video (`output/` as mp4/gif). Needs video latent chain, not image. |
| `Load Video` | Video-to-video / frame edit input. |

### 4.5 Bundled custom nodes (already installed by the flake)

| Pack | Key nodes to search (`Q`) | Use |
|------|---------------------------|-----|
| Impact Pack | `FaceDetailer`, `SAMLoader`, `Detector` | Auto-face fix (generate → detect face → repaint at higher res), segmentation masks. The #1 quality jump on 6GB. |
| rgthree | `Reroute`, `Power Lora Loader`, `Context` | `Reroute` cleans spaghetti wiring; `Power Lora Loader` manages many LoRAs with strengths in one box. |
| KJNodes | `Batch Process`, `Conditioning Combine`, `Image Resize` | Prompt tricks, batch handling, mask ops. |
| GGUF | `UNETLoader (GGUF)` | Load `Q4/Q5 .gguf` Flux/Wan on low VRAM. Points at `diffusion_models/` or `unet/`. |
| LTXVideo | `LTXV Model Loader`, `LTXV Sampler` | Fast low-VRAM video. `Prompt Enhancer` node rewrites prompts for LTX. |
| Florence2 | `Florence2 Run` | Caption / detect / OCR / VQA: drop in image → get text description (great for auto-tagging). |
| bitsandbytes NF4 | `CheckpointLoaderNF4` | Flux Dev NF4 quantized checkpoints. |
| x-flux | `XFlux LoRA`, `XFlux ControlNet` | Flux LoRA/ControlNet (Canny/Depth/HED) + IP-Adapter. |
| MMAudio | `MMAudio Sample` | Silent video + text → 44kHz audio track. |
| PuLID | `PuLID Apply` | Face-ID preservation: reference face + prompt → same identity new scene. See upstream `docs/pulid-setup.md`. |
| WanVideoWrapper | `WanVideo Model Loader`, `WanVideo Sampler` | Friendlier Wan alternative to native nodes. Try native templates first, wrapper if OOM. |

---

## 5. Image workflows — build them in order

Do these in sequence; each reuses the last.

### 5.1 Text-to-image (SDXL, 5 min)

1. `Workflow → Browse Templates → Basic → Image Generation` (or press `Q` and add manually).
2. Nodes: `Load Checkpoint (sd_xl_base_1.0.safetensors)` → `CLIP Text Encode+` (`beautiful portrait, soft window light, 85mm`) → `CLIP Text Encode-` (`blurry, deformed, watermark`) → `Empty Latent 1024x1024` → `KSampler (25 steps, CFG 6, euler, karras, seed -1)` → `VAE Decode` → `Save Image`.
3. `Queue`. First run compiles kernels (slow); second is representative (~8s on your card at 1024, ~4s at 768).
4. Iterate: lock seed, vary prompt/CFG ±1, then steps ±5. Change one thing at a time.

### 5.2 Image-to-image (restyle a photo)

Replace `Empty Latent` with `Load Image (upload)` → `VAE Encode` → KSampler. Set `denoise 0.65`. Same prompt path. Lower denoise = closer to original.

### 5.3 LoRA style pass

Insert `Load LoRA` between `Load Checkpoint` and `KSampler`: checkpoint `MODEL`→LoRA `model`, checkpoint `CLIP`→LoRA `clip`, LoRA outputs → sampler/encoders. Start `strength 0.8/0.8`. Chain two LoRAs in series for style+character. If face melts, lower to 0.5.

### 5.4 ControlNet (pose/edge control)

Chain: `Load Image (pose sketch)` → preprocessor (if using `comfyui_controlnet_aux`, e.g. `OpenPose Preprocessor`) → `Load ControlNet` + `Apply ControlNet (strength 0.9)` between prompt and sampler. Keep text prompt describing *content*, ControlNet handles *composition*.

### 5.5 Upscale (the 6GB quality trick)

Generate at 768px → `Upscale Image (RealESRGAN_x4plus)` → optional second `KSampler` pass at `denoise 0.3` (hi-res fix) → `Save Image`. Looks near-native-1024 for half the VRAM.

### 5.6 Face fix with Impact Pack

After base gen: `FaceDetailer (bbox detector + inpaint model)` wired after `VAE Decode`. It crops faces, repaints at higher res, pastes back. Fixes the classic "melted hands/faces at distance" without regenerating.

---

## 6. Video workflows

All video: keep 480p, 33–49 frames, batch 1, `--lowvram`. Generate the *start image* with SDXL first — image-to-video beats text-to-video for control.

### 6.1 LTX-Video (fastest, bundled — do this first)

Template: `Workflow → Browse Templates → LTX-Video → Text-to-Video` (or I2V). Nodes handle text encoder internally. 480p, ~2–6s clips in a couple minutes on 1660S. Use the `Prompt Enhancer` node — LTX likes long cinematic prompts.

### 6.2 Wan 2.1 1.3B (best quality/VRAM)

Needs 4 files (§6.2 in install guide): diffusion in `diffusion_models/`, `umt5_xxl_fp8` in `text_encoders/`, `clip_vision_h` in `clip_vision/` (I2V only), `wan_2.1_vae` in `vae/`. Template `Wan2.1 T2V 1.3B`. 480p, 33 frames, 20 steps CFG 6. Expect several minutes — normal.

### 6.3 Wan 2.2 5B hybrid (one model, T2V+I2V)

Template `Wan2.2 5B`. Same encoders/VAE as above, diffusion from `Wan2.2-TI2V-5B`. Try I2V: your SDXL still → motion prompt (`slow dolly in, hair moves`) → 49 frames.

### 6.4 Audio with MMAudio

`Load Video (your silent mp4)` + text (`rain on windows, distant traffic`) → `MMAudio Sample` → output muxed clip. 44kHz, surprisingly good for ambience.

Lightning shortcut: `lightx2v 4-step LoRA` drops Wan sampling 20→4 steps (CFG 1). Slight detail loss, 4–5x faster — worth it while iterating.

---

## 7. Prompting that actually works

Image positive pattern:

```
subject + action, environment, light, lens/style, quality tags
e.g. "portrait of a beekeeper, morning apiary, soft backlight, 85mm f1.8, shallow depth, photorealistic, sharp focus"
```

Negative pattern (SD1.5/SDXL; skip for Flux/LTX):

```
"blurry, lowres, deformed hands, extra fingers, watermark, text, oversaturated"
```

Video motion pattern:

```
start-state + motion + camera + light
e.g. "still pond at dawn, mist drifts left, slow dolly in, soft volumetric light, 24fps cinematic"
```

- One idea per prompt. If it ignores you, shorten — don't raise CFG past 8.
- Flux/Schnell/Turbo: plain language, no quality-tag soup, empty negative is fine.
- Wan/LTX: describe *motion*, not just scene. No motion words = slideshow.
- Seed discipline: randomize to explore, lock to refine.

---

## 8. Manager + custom nodes + updates

- `Manager → Custom Nodes Manager` → search pack → `Install` → **full restart** (`sudo systemctl restart comfyui`). Soft-restart misses Nix patches.
- `Manager → Model Manager` → search checkpoint/LoRA → Install (auto-places in correct folder).
- `Manager → Update All` weekly; then full restart.
- Deps go to `<dataDir>/.venv/` (Nix store stays read-only). If a node needs system libs that fail, prefer the flake's declarative `customNodes` + `extraPythonPackages` in `modules/ai/comfyui.nix` instead.
- Missing-node prompt when opening a foreign workflow: `Install All` → full restart.

---

## 9. Troubleshooting (usage-side)

| Symptom | Fix |
|---------|-----|
| Loader dropdown empty | Wrong folder (§3) or press `R` to refresh; check extension is `.safetensors`. |
| Red node `Missing model` on template load | Template embeds download links — click it, or `wget` manually to shown folder. |
| OOM / CUDA out of memory | Drop resolution (1024→768, 720p→480p), batch 1, FP8/GGUF encoders, `--lowvram` (already set), close Zen/Vesktop. |
| Black/blank output | VAE mismatch (SDXL checkpoint + SD1.5 VAE). Use matching VAE or checkpoint-bundled VAE. |
| Faces/hands melted | Lower LoRA strength, add `FaceDetailer`, or hi-res-fix pass at denoise 0.3. |
| Video is static slideshow | Prompt lacks motion verbs; add camera + movement, check frames > 25. |
| Manager install did nothing | Full `systemctl restart comfyui` required (see §8). |
| `Port 8188 in use` | Another instance running: `systemctl status comfyui`, or `--port 8189` for manual runs. |
| Slow first generation | Normal kernel compile into `.cache/`; second run is the real speed. |

Logs: `journalctl -u comfyui -f` + `nvidia-smi -l 1`.

---

## 10. Suggested practice ladder (tonight → this week)

1. **Tonight (30 min):** SDXL T2I template at 768px, 5 seeds, lock best, vary CFG 5/6/7. Learn Queue/History/seed.
2. **Upscale:** add RealESRGAN node, compare 768-upscaled vs native-1024.
3. **LoRA:** one style LoRA at 0.8 → 0.5 → 1.0, note effect. Chain two.
4. **I2I:** photo → denoise 0.65 restyle.
5. **Video:** LTX I2V from your best still (33 frames 480p). Then Wan 1.3B same still.
6. **Polish:** Impact `FaceDetailer` on a portrait, MMAudio on a video.

Further reading: https://docs.comfy.org/ (LoRA, ControlNet, Flux, Wan2.2 pages), https://comfy.org/workflows/ (filter Image/Video), https://comfyui-wiki.com/ (Wan2.2 + Flux family), Civitai workflow posts (drag PNGs back into canvas).
