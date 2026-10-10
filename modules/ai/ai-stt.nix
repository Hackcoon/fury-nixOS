# ============================================================================
# ai-stt.nix — Optional local STT dictation (Nix-native)
#
# OFF by default; flip per host. Self-contained: other machines skip it
# by never importing this file or leaving it disabled.
#
#   ai-stt.enable = true;  # hyprwhspr-rs daemon (parakeet/whisper backends)
#   ai-stt.cuda   = true;  # NVIDIA acceleration (needs CUDA binary cache)
#
# Models download once on first run, then fully offline. No cloud backends.
# ============================================================================
{ config, pkgs, lib, unstablePkgs, ... }:

with lib;
let
  cfg = config.ai-stt;
in
{
  # ── Options: master switch + CUDA ──
  options.ai-stt = {
    enable = mkEnableOption "local STT dictation (hyprwhspr-rs, parakeet/whisper backends, Hyprland binds)";
    cuda = mkEnableOption "CUDA acceleration for STT (NVIDIA; uses CUDA binary cache)";
  };
  # ----------------------------------------------------------------------

  config = mkIf cfg.enable {
    # ── Mic access: input group hears hold-to-talk ──
    # The daemon listens for Hyprland hold-to-talk shortcuts — without the
    # input group it never sees the keypress.
    users.users.fury.extraGroups = [ "input" ];
    # ----------------------------------------------------------------------

    # ── hyprwhspr-rs service (unstable package, CUDA-optional) ──
    # Stable's 0.3.27 has a broken virtual-keyboard injector (claims success,
    # types nothing) + broken sendshortcut Lua on Hyprland 0.55 — revisit
    # when stable catches up. CUDA override rebuilds whisper-cpp + onnxruntime
    # with cudaSupport (needs the CUDA cache in core/nix.nix, else it compiles).
    services.hyprwhspr-rs = {
      enable = true;
      package =
        if cfg.cuda then
          unstablePkgs.hyprwhspr-rs.override {
            "whisper-cpp" = pkgs.whisper-cpp.override { cudaSupport = true; };
            onnxruntime = pkgs.onnxruntime.override { cudaSupport = true; };
          }
        else unstablePkgs.hyprwhspr-rs;
    };
    # ----------------------------------------------------------------------

    # ── CLI twins of the service packages ──
    # Same build the service runs (CUDA override included when enabled) plus
    # the paste path: wtype injects keystrokes on Wayland, wl-clipboard
    # auto-copies each transcription.
    environment.systemPackages = with pkgs; [
      config.services.hyprwhspr-rs.package
      wtype         # Wayland keystroke injector (paste fallback path)
      wl-clipboard  # auto-copy transcription to clipboard
    ];
    # ----------------------------------------------------------------------
  };
}
