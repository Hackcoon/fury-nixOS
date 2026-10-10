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
