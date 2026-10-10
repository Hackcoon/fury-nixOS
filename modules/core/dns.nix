# ============================================================================
# dns.nix — systemd-resolved + DoT provider presets.
#
# One switch (dns.provider) picks the whole DNS behavior. Forced providers
# ignore DHCP DNS and pin strict DoT nameservers; native accepts whatever
# DHCP hands out (captive portals, work VPNs, DoT-blocking networks).
# When Blocky is on, resolved points at localhost and Blocky does DoT
# upstream itself — every provider block below stands down automatically.
# ============================================================================
{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.dns;
in
{
  # ── Options: the provider switch + Blocky override ──
  # Five choices, one default. configuration.nix flips this per network.
  options.dns.provider = mkOption {
    type = types.enum [ "quad9" "cloudflare" "google" "opendns" "native" ];
    default = "quad9";
    description = ''
      DNS provider selection.
      quad9/cloudflare/google/opendns = forced DoT nameservers (ignore DHCP DNS).
      native = DHCP-provided DNS as-is (no DoT, no forced nameservers) —
        use on captive portals, work VPNs, or networks where DoT is blocked.
    '';
  };
  # ----------------------------------------------------------------------

  # ── Option: manual Blocky upstream (for native / DoT-blocked networks) ──
  # null (default) = Blocky auto-follows dns.provider. Set this and Blocky
  # uses the configured list verbatim instead — for networks where DoT port 853 is
  # blocked (hotels, cafes, some work nets): plain-protocol upstreams or the
  # local router, which need no TLS handshake:
  #   dns.upstreamOverride = [ "192.168.1.1" ];       # local router (plain)
  #   dns.upstreamOverride = [ "8.8.8.8" "8.8.4.4" ]; # plain google, no DoT
  # NOTE: plain upstreams are visible to the local network — the price of
  # working DNS where DoT is blocked. Set back to null afterwards.
  options.dns.upstreamOverride = mkOption {
    type = types.nullOr (types.listOf types.str);
    default = null;
    description = "Manual Blocky upstream list (verbatim). null = auto-follow dns.provider.";
  };
  # ----------------------------------------------------------------------

  config = mkMerge [
    # ── Base: resolved via NetworkManager + DoT policy ──
    # All providers share this. ignore-auto-dns is the native escape hatch:
    # forced providers drop DHCP DNS, native keeps it. DoT is strict everywhere
    # except native (random DHCP servers have no TLS hostname to verify) and
    # Blocky mode (resolved talks plain localhost; Blocky encrypts upstream).
    {
      networking.networkmanager.dns = "systemd-resolved";
      networking.networkmanager.connectionConfig = {
        # native = accept DHCP DNS (captive portals/VPNs); anything else =
        # ignore DHCP and use the forced DoT nameservers below.
        "ipv4.ignore-auto-dns" = cfg.provider != "native";
        "ipv6.ignore-auto-dns" = cfg.provider != "native";
      };
      services.resolved = {
        enable = true;
        settings.Resolve = {
          # When Blocky is on, resolved -> Blocky is plain localhost;
          # Blocky does DoT upstream itself.
          # native = plain DHCP servers (no TLS hostname to verify against).
          DNSOverTLS = if config.services.blocky.enable then "no"
            else if cfg.provider == "native" then "no"
            else "true";
          # ── DNSSEC: are answers AUTHENTIC (separate axis from DoT) ──
          # DoT encrypts the channel (nobody eavesdrops); DNSSEC signs the data
          # (answer really came from the domain owner, untampered). Values:
          #   "no"             = skip validation entirely (what we run).
          #   "allow-downgrade"= validate, but fall back for unsigned domains.
          #   "yes"            = hard-require signatures (breaks most of the web).
          # We run "no" because allow-downgrade broke real unsigned domains
          # (agentrouter.org -> Alibaba CNAME with no signature). DoT encryption
          # still holds — only signature-checking is off. Flip to
          # "allow-downgrade" for max-privacy posture where those domains are unneeded
          # domains (see MAX PRIVACY note in configuration.nix).
          DNSSEC = "no";
        };
      };
    }
    # ----------------------------------------------------------------------

    # ── Quad9 (default): filtered + fast anycast ──
    # Malware-blocking resolver. Cloudflare IPs as fallback so a Quad9
    # outage doesn't take DNS with it.
    (mkIf (cfg.provider == "quad9" && !config.services.blocky.enable) {
      networking.nameservers = [
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
    })
    # ----------------------------------------------------------------------

    # ── Cloudflare: raw speed, no filtering ──
    # Lowest-latency pick most places. Quad9 IPs as fallback.
    (mkIf (cfg.provider == "cloudflare" && !config.services.blocky.enable) {
      networking.nameservers = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "9.9.9.9" "149.112.112.112" ];
    })
    # ----------------------------------------------------------------------

    # ── Google: last-resort compatibility ──
    # Some networks only behave with 8.8.8.8. No filtering, Google sees queries.
    (mkIf (cfg.provider == "google" && !config.services.blocky.enable) {
      networking.nameservers = [
        "8.8.8.8#dns.google"
        "8.8.4.4#dns.google"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "1.1.1.1" "9.9.9.9" ];
    })
    # ----------------------------------------------------------------------

    # ── OpenDNS (Cisco): optional family filtering ──
    # Standard resolver below; swap in the 208.67.222.123 FamilyShield IPs
    # to block adult content network-wide (no per-device setup needed).
    (mkIf (cfg.provider == "opendns" && !config.services.blocky.enable) {
      # Cisco OpenDNS (DoT via dns.opendns.com:853). FamilyShield variant
      # (blocks adult content) uses 208.67.222.123#dns.opendns.com instead.
      networking.nameservers = [
        "208.67.222.222#dns.opendns.com"
        "208.67.220.220#dns.opendns.com"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "9.9.9.9" "1.1.1.1" ];
    })
    # ----------------------------------------------------------------------

    # ── native: deliberately empty ──
    # No block here on purpose: nameservers come from DHCP
    # (ignore-auto-dns=false above), DoT off. Nothing to force.
  ];
}
