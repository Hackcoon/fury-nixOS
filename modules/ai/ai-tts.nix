# ============================================================================
# ai-tts.nix — Optional local offline TTS (Nix-native)
#
# OFF by default; flip per host. Self-contained: other machines skip it
# by never importing this file or leaving it disabled.
#
#   ai-tts.enable = true;  # piper-tts synthesis (CPU-realtime, offline)
#
# Voices (~60MB each) download once, then fully offline. Piper is CPU by
# design (2500x realtime) — GPU TTS (Kokoro via uv venv) is a different
# setup, not covered here.
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.ai-tts;
in
{
  # ── Options: master switch ──
  options.ai-tts = {
    enable = mkEnableOption "local offline TTS (piper-tts + phonemizer)";
  };
  # ----------------------------------------------------------------------

  config = mkIf cfg.enable {
    # ── Voice stack: synth + phonemes + playback ──
    # piper synthesizes (`piper --model <voice>.onnx`), espeak-ng covers voice
    # data/fallback, mpv plays the resulting wav.
    environment.systemPackages = with pkgs; [
      piper-tts        # synthesizer (`piper --model <voice>.onnx`)
      piper-phonemize  # phonemizer backend
      espeak-ng        # voice data / fallback synth
      mpv              # audio playback for synthesized wav
    ];
    # ----------------------------------------------------------------------
  };
}
