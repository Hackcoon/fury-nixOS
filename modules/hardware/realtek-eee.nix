# ============================================================================
# realtek-eee.nix — RTL8111 Energy Efficient Ethernet disconnect workaround.
#
# MACHINE-SPECIFIC: desktop board only (interface enp5s0). Drop on the laptop
# and AMD PC — a failing ethtool unit on boot is the symptom it doesn't apply.
# EEE causes intermittent link renegotiation disconnects; this oneshot runs
# after NetworkManager so the interface has initialized before ethtool
# changes its settings. Same symptom family as the pcie_aspm=off kernel
# param in core/boot.nix.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Oneshot: EEE off on enp5s0, every boot ──
  # Type=oneshot + RemainAfterExit: run once, report complete. Ordered after
  # NetworkManager (wants + after) so the link exists when ethtool runs.
  systemd.services."disable-realtek-eee" = {
    description =
      "Disable Energy Efficient Ethernet on the Realtek Ethernet interface";

    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];

    serviceConfig = {
      Type = "oneshot";            # run once during boot
      RemainAfterExit = true;      # complete after success
      ExecStart =
        "${pkgs.ethtool}/bin/ethtool --set-eee enp5s0 eee off";
    };
  };
  # ----------------------------------------------------------------------
}
