# ============================================================================
# razer.nix — Razer peripherals via OpenRazer + Polychromatic frontend.
#
# Driver grants user "fury" device access; Polychromatic is the GUI for
# lighting/DPI/macros. OPTIONAL+MACHINE-SPECIFIC: drop on machines without
# Razer gear (laptop, AMD PC).
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── OpenRazer driver + access ──
  # users = who may talk to the devices (udev ACLs).
  hardware.openrazer = {
    enable = true;
    users = [ "fury" ];
  };
  # ----------------------------------------------------------------------

  # ── Polychromatic: lighting/DPI GUI ──
  environment.systemPackages = with pkgs; [
    polychromatic
  ];
  # ----------------------------------------------------------------------
}
