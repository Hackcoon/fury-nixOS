# Networking: NetworkManager, encrypted DNS (Quad9 DoT), SSH, Wireshark.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "nixos";

  # Enable NetworkManager for wired and wireless connections
  networking.networkmanager.enable = true;

  # Hand DNS duties to systemd-resolved instead of NetworkManager
  # managing it independently — prevents the two from fighting over
  # /etc/resolv.conf
  networking.networkmanager.dns = "systemd-resolved";

  # Prevent NetworkManager from injecting router DHCP DNS servers.
  # connectionConfig writes to the correct [connection] section,
  # applying to every connection profile (wired + wireless) at once.
  # Without this, your router's DNS (192.168.1.1) leaks in alongside
  # Quad9. Verify with `resolvectl status`.
  networking.networkmanager.connectionConfig = {
    "ipv4.ignore-auto-dns" = true;
    "ipv6.ignore-auto-dns" = true;
  };

  # Quad9 with DNS-over-TLS — encrypts DNS queries so your ISP/network
  # can't see plaintext lookups. Runs at the OS level via
  # systemd-resolved, transparent to every app with zero per-app config.
  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"          # Quad9 primary, TLS hostname for DoT verification
    "149.112.112.112#dns.quad9.net"   # Quad9 secondary
  ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        # Encrypts all DNS traffic between your machine and Quad9
        DNSOverTLS = "true";

        # "allow-downgrade" validates DNSSEC when possible but won't
        # hard-fail on networks/domains with broken DNSSEC records.
        # Strict "true" causes random unexplained connection failures
        # on some networks — avoid unless you want strict enforcement.
        DNSSEC = "allow-downgrade";

        # Used only if Quad9 itself is unreachable/down
        FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
      };
    };
  };

  # Enable the OpenSSH daemon
  services.openssh.enable = true;

  # Packet capture without sudo — requires the user to be in the
  # `wireshark` group (done in modules/users/users.nix; this was a
  # missing piece in the old config).
  programs.wireshark.enable = true;
}
