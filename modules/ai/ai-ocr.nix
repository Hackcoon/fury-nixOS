# ============================================================================
# ai-ocr.nix — Optional screenshot-to-text OCR (Nix-native)
#
# OFF by default; flip per host. Self-contained: other machines skip it
# by never importing this file or leaving it disabled.
#
#   ai-ocr.enable = true;  # grim + slurp + tesseract pipeline
#
# Fully offline, no models to fetch. Usage:
#   region=$(slurp) || exit 0
#   grim -g "$region" - | tesseract stdin stdout -l eng 2>/dev/null | wl-copy
# ============================================================================
{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.ai-ocr;
in
{
  # ── Options: master switch ──
  options.ai-ocr = {
    enable = mkEnableOption "screenshot-to-text OCR (grim + slurp + tesseract)";
  };
  # ----------------------------------------------------------------------

  config = mkIf cfg.enable {
    # ── Capture pipeline: shoot, pick, read, notify ──
    # grim screenshots, slurp picks the region, tesseract reads English,
    # wl-copy takes the text, libnotify confirms via notify-send.
    environment.systemPackages = with pkgs; [
      grim         # Wayland screenshotter
      slurp        # region picker
      tesseract    # OCR engine (`tesseract stdin stdout -l eng`)
      wl-clipboard # wl-copy / wl-paste
      libnotify    # notify-send feedback
    ];
    # ----------------------------------------------------------------------
  };
}
