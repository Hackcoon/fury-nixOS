# ============================================================================
# boot.nix — Bootloader, Secure Boot, kernel.
#
# Stack: Lanzaboote (Secure Boot) instead of plain systemd-boot, standard
# 26.05 kernel, EFI writes allowed, PCIe ASPM off (RTL8111 stability),
# boot menu capped so the ESP never fills up.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Kernel: standard 26.05 build ──
  # Alternatives: pkgs.linuxPackages_latest, or an LTS pin.
  boot.kernelPackages = pkgs.linuxPackages;
  # ----------------------------------------------------------------------

  # ── Secure Boot via Lanzaboote (sbctl keys in /etc/secureboot) ──
  # systemd-boot is force-disabled because Lanzaboote takes over the boot
  # entries and force-disables it itself; being explicit avoids
  # "multiple defined" errors from leftover defaults.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };
  boot.loader.efi.canTouchEfiVariables = true; # allow EFI variables to be modified
  # ----------------------------------------------------------------------

  # ── PCIe ASPM off (RTL8111 stability) ──
  # ASPM link renegotiation disconnects on RTL8111 boards — same symptom family
  # as the EEE bug handled by modules/hardware/realtek-eee.nix. Kept off while
  # the EEE fix alone proves stable. Tradeoff: slightly higher idle power draw.
  boot.kernelParams = [ "pcie_aspm=off" ];
  # ----------------------------------------------------------------------

  # ── Boot menu: keep the last 20 generations ──
  # Stops the ESP filling up with entries after many rebuilds in a short
  # window. Lanzaboote respects this even though systemd-boot.enable is off.
  boot.loader.systemd-boot.configurationLimit = 20;
  # ----------------------------------------------------------------------
}
