# ============================================================================
# network.nix — Networking: hostname, NetworkManager, IPv6 off, SSH.
#
# Hostname "nixos" here is the default every machine starts with — the laptop
# module intentionally does NOT rename it (keep hostnames set here per machine).
# IPv6 is off: this LAN has no v6 route, yet DNS returns AAAA for voice
# services and WebRTC then tries dead v6 candidates (UDP drops, TCP survives).
# Wireshark needs the user in the `wireshark` group (users.nix).
# DNS lives in modules/core/dns.nix — the old block below is rollback only.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Hostname + NetworkManager ──
  # Every machine starts as "nixos"; rename per machine here as needed.
  networking.hostName = "nixos";
  networking.networkmanager.enable = true; # wired + wireless via NM
  # ----------------------------------------------------------------------

  # ── IPv6 off: no v6 route on this LAN ──
  # Only fe80:: link-local exists, no default route — ping6 = unreachable —
  # yet DNS still returns AAAA for discord.media / meet. WebRTC then tries
  # dead v6 candidates and voice (UDP) drops while TCP video survives.
  # Windows skips unreachable v6 faster; Linux/Electron does not. Disabling
  # costs nothing here since v4 is the only working path.
  networking.enableIPv6 = false;
  # ----------------------------------------------------------------------

  # ── UDP conntrack timeouts: HOTS disconnect fix (2026-10-10) ──
  # Heroes of the Storm holds one long-lived UDP association to the game
  # server (TCP :1119 stays ESTAB, UDP is the gameplay path). Defaults
  # (30s / 120s) expire the mapping during quiet phases (draft, loading),
  # and HotS cannot re-punch mid-match — client shows "disconnected" and only
  # a relaunch rejoins. 60s/180s keeps idle halves alive longer locally.
  # NOTE: the home router (192.168.1.1) has its own UDP timeout — if drops
  # persist, raise it there too or set a static port forward for
  # UDP 1119-1120, 3724, 4000, 6113-6114. Revert: delete this block.
  boot.kernel.sysctl = {
    "net.netfilter.nf_conntrack_udp_timeout" = 60;
    "net.netfilter.nf_conntrack_udp_timeout_stream" = 180;
  };
  # Preload conntrack so the sysctl above actually applies at boot.
  # Without this, systemd-sysctl runs before nf_conntrack is loaded and the
  # values are skipped ("No such file or directory", seen 2026-10-12) —
  # leaving the 30s/120s defaults and the HotS draft-phase NAT expiry intact.
  boot.kernelModules = [ "nf_conntrack" ];
  # ----------------------------------------------------------------------

  # ── SSH + packet capture ──
  # Wireshark capture without sudo requires the `wireshark` group
  # (done in modules/users/users.nix; this was a missing piece before).
  services.openssh.enable = true;
  programs.wireshark.enable = true;
  # ----------------------------------------------------------------------

  # ── PARKED: old DNS block (rollback only) ──
  # Moved to modules/core/dns.nix. Kept so the last-known-good DNS can be
  # restored by uncommenting if the new module ever misbehaves. Delete once
  # dns.nix has proven itself across a few rebuilds.
  # OLD DNS BLOCK (moved to modules/core/dns.nix — kept for rollback):
  # networking.networkmanager.dns = "systemd-resolved";
  # networking.networkmanager.connectionConfig = {
  #   "ipv4.ignore-auto-dns" = true;
  #   "ipv6.ignore-auto-dns" = true;
  # };
  # networking.nameservers = [
  #   "9.9.9.9#dns.quad9.net"
  #   "149.112.112.112#dns.quad9.net"
  # ];
  # services.resolved = {
  #   enable = true;
  #   settings.Resolve = {
  #     DNSOverTLS = "true";
  #     DNSSEC = "allow-downgrade";
  #     FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
  #   };
  # };
  # ----------------------------------------------------------------------
}
