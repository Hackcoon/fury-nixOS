# Kokoro TTS setup (new machine)

`ai-tts.nix` covers **Piper** (CPU TTS) only. GPU Kokoro (the `SUPER+T`
speak-clipboard flow) is a `uv` venv + downloaded models — set up by hand,
once per machine. Total download ~200MB models + venv packages.

## What travels in git

`dotfiles/kokoro/` (208KB, all plain text):

| File | Role |
|---|---|
| `dusky_main.py` | engine: speak/stop/pause/status/doctor/voices/reload/unload/shutdown (stdlib client surface; synth via kokoro-onnx) |
| `trigger.sh` | entry point, symlinked as `~/.local/bin/dusky-kokoro`; picks the venv Python, sets `LD_LIBRARY_PATH` for CUDA driver libs |
| `tui_kokoro.py` | terminal UI for voices/status |
| `pyproject.toml` + `uv.lock` | pinned env: `kokoro-onnx==0.6.1`, `onnxruntime-gpu[cuda,cudnn]`, nvidia mode |

## What does NOT travel (rebuild / re-download)

- `.venv/` — rebuilt via `uv sync` (uv fetches its own CPython ≥3.14; system Python version irrelevant)
- `models/kokoro-v1.0.fp16-gpu.onnx` (170MB) + `models/voices-v1.0.bin` (27MB) — downloaded once

## New-machine steps

```bash
# 0. System deps (most already in the flake): uv, espeak-ng (ai-tts module),
#    nix-ld + opengl driver libs for libcuda/libstdc++ at runtime.
mkdir -p ~/contained_apps/uv/dusky_kokoro ~/contained_apps/dusky_kokoro
cp /etc/nixos/dotfiles/kokoro/{dusky_main.py,pyproject.toml,uv.lock} \
   ~/contained_apps/uv/dusky_kokoro/
cp /etc/nixos/dotfiles/kokoro/{trigger.sh,tui_kokoro.py} \
   ~/contained_apps/dusky_kokoro/
chmod +x ~/contained_apps/dusky_kokoro/trigger.sh

# 1. Environment (uv gets its own Python 3.14; ~minutes, CUDA wheels are big)
cd ~/contained_apps/uv/dusky_kokoro && uv sync

# 2. Models (197MB, once)
mkdir -p ~/contained_apps/uv/dusky_kokoro/models
cd ~/contained_apps/uv/dusky_kokoro/models
curl -fL --retry 5 -O \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.fp16-gpu.onnx
curl -fL --retry 5 -O \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/voices-v1.0.bin

# 3. Wire the commands
ln -sf ~/contained_apps/dusky_kokoro/trigger.sh ~/.local/bin/dusky-kokoro
ln -sf ~/contained_apps/dusky_kokoro/tui_kokoro.py ~/.local/bin/dusky-kokoro-tui

# 4. Verify (GPU synthesis; Heart/Bella default voices)
dusky-kokoro speak --stdin --mode interrupt <<< "fresh install talking"
dusky-kokoro doctor
```

CPU-only machine? Regenerate the env instead of `uv sync`: the Dusky
`kokoro_installer.sh` (`user_scripts/tts_stt/dusky_kokoro/`) builds int8/CPU
and ROCm variants — re-run it there and copy the resulting
`pyproject.toml`/`uv.lock` back into `dotfiles/kokoro/`.

## Deliberately NOT in git

- `.venv/` (GBs, rebuildable), `models/*.onnx|*.bin` (197MB, downloadable)
- Voice choice / daemon state — runtime, per machine.
