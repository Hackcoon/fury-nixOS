# ============================================================================
# ai-services.nix — Local AI stack: Ollama (CUDA) + open-webui + Hermes Agent.
#
# HEAVY: the #1 build-time cost in this repo (CUDA closure). Drop the whole
# AI section in configuration.nix for minimal/fastest builds.
#
# SECRETS NOTE: never put API keys in `settings` or `environment` — both land
# in /nix/store, world-readable. Use `environmentFiles` pointed at a
# sops-nix/agenix secret (or a manually created 0600 file owned by the
# service user as a bare-minimum start).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Ollama: local LLM server (manual start only) ──
  # ollama-cuda offloads inference to NVIDIA; idle it consumes nearly nothing —
  # but it still idles ON the GPU even with no model loaded, so autostart is
  # gated (wantedBy emptied). Start when needed, re-enable autostart by
  # deleting the two wantedBy lines + rebuild.
  systemd.services.ollama.wantedBy = lib.mkForce [];     # start: sudo systemctl start ollama
  systemd.services.open-webui.wantedBy = lib.mkForce []; # start: sudo systemctl start open-webui
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };
  # ----------------------------------------------------------------------

  # ── open-webui: browser chat UI for Ollama ──
  services.open-webui = {
    enable = true;
    port = 8080;
    # package = pkgs.open-webui;  # pin explicitly if needed
  };
  # ----------------------------------------------------------------------

  # ── Hermes Agent: coding agent as a systemd service ──
  # Default model MiniMax M3 via OpenRouter (provider default — no base_url
  # override needed, just the slug): 1M context, tuned for long-horizon
  # agentic/coding work, genuinely free, not a trial quota. Key comes from
  # /var/lib/hermes/env (see SECRETS NOTE above). Host mode = hardened
  # service using only Nix-provided PATH tools; container mode (parked below)
  # runs persistent Ubuntu so the agent can apt/pip/npm at runtime (needs
  # Podman from programs/virtualisation.nix).
  services.hermes-agent = {
    enable = true;
    settings.model = {
      default = "minimax/minimax-m3:free";
    };
    environmentFiles = [ "/var/lib/hermes/env" ]; # OpenRouter key (0600, hermes-owned)
    # container.enable = true; # self-installing agent mode (needs Podman)
    addToSystemPackages = true;
  };
  # ----------------------------------------------------------------------
}
