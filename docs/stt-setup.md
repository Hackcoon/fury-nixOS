# STT setup (new machine)

Dictation is `hyprwhspr-rs` (Parakeet backend), toggled with `SUPER+M`.
The NixOS side is done by `ai-stt.nix` (`ai-stt.enable = true` — daemon +
CUDA-optional package). This doc covers the parts that live outside the
flake: user config + model downloads.

## What travels in git

`dotfiles/stt/config.jsonc` (8KB) — provider `parakeet`, model dir,
whisper-cpp/silero/groq/gemini stanzas, prompts.

**Verified secret-free at commit time** (2026-10-11): no API keys in the
file — provider sections carry only model names, public endpoints and
prompts. If you ever paste a provider key in here, move it to env
(`systemd` `EnvironmentFile`, never git) instead.

## What does NOT travel (downloaded / runtime)

- `~/.local/share/hyprwhspr-rs/models/` — **~2.4GB**: Parakeet
  `parakeet-tdt-0.6b-v3-onnx` (encoder + decoder_joint + vocab), fetched
  automatically by the daemon on first run. Whisper/silero companions pull
  the same way if those stanzas are enabled.
- `~/.local/share/hyprwhspr-rs/transcriptions.json` — your dictation
  history. Personal data, never commit.
- `~/.cache/hyprwhspr-rs/` — throwaway cache.

## New-machine steps

```bash
# 0. Enable the module + rebuild
#    configuration.nix: ai-stt.enable = true  (imports modules/ai/ai-stt.nix)
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# 1. Drop in the config
mkdir -p ~/.config/hyprwhspr-rs
cp /etc/nixos/dotfiles/stt/config.jsonc ~/.config/hyprwhspr-rs/

# 2. First run pulls the models (~2.4GB, once, then fully offline).
#    Toggle dictation and speak; the daemon fetches what the config names.
#    Binds (already in dms/binds.lua, mirrored to dotfiles/hypr):
#      SUPER+M  record toggle — Parakeet
```

CPU-only machine? `ai-stt.nix` builds the CUDA override only when enabled;
the daemon falls back to CPU/whisper backends per the same config — slower,
no extra steps.
