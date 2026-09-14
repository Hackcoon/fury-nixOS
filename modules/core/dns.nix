{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.dns;
in
{
  options.dns.provider = mkOption {
    type = types.enum [ "quad9" "cloudflare" "google" ];
    default = "quad9";
    description = "DNS provider selection.";
  };
  config = mkMerge [
    {
      networking.networkmanager.dns = "systemd-resolved";
      networking.networkmanager.connectionConfig = {
        "ipv4.ignore-auto-dns" = true;
        "ipv6.ignore-auto-dns" = true;
      };
      services.resolved = {
        enable = true;
        settings.Resolve = {
          # When Blocky is on, resolved -> Blocky is plain localhost;
          # Blocky does DoT upstream itself.
          DNSOverTLS = if config.services.blocky.enable then "no" else "true";
          # DNSSEC=no: DoT encryption stays, authenticity validation off.
          # allow-downgrade broke unsigned domains (agentrouter.org -> Alibaba CNAME, no-signature).
          # Re-enable ("allow-downgrade") for stricter validation if you don't need those domains.
          DNSSEC = "no";
        };
      };
    }
    (mkIf (cfg.provider == "quad9" && !config.services.blocky.enable) {
      networking.nameservers = [
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
    })
    (mkIf (cfg.provider == "cloudflare" && !config.services.blocky.enable) {
      networking.nameservers = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "9.9.9.9" "149.112.112.112" ];
    })
    (mkIf (cfg.provider == "google" && !config.services.blocky.enable) {
      networking.nameservers = [
        "8.8.8.8#dns.google"
        "8.8.4.4#dns.google"
      ];
      services.resolved.settings.Resolve.FallbackDNS = [ "1.1.1.1" "9.9.9.9" ];
    })
  ];
}
