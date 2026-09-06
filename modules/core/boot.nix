# Bootloader & kernel.
#
# systemd-boot is disabled with mkForce because Lanzaboote (Secure Boot)
# takes over the boot entries and force-disables it itself; being
# explicit avoids "multiple defined" errors from leftover defaults.
{ config, pkgs, lib, ... }:

{
  # Standard kernel from your nixos-26.05 channel (pkgs.linuxPackages).
  # Alternatives: pkgs.linuxPackages_latest, or an LTS pin.
  boot.kernelPackages = pkgs.linuxPackages;

  # Disable default systemd-boot in favor of Lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # Enable Lanzaboote and define the PKI bundle location
  # (your sbctl keys live in /etc/secureboot)
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Allow EFI variables to be modified
  boot.loader.efi.canTouchEfiVariables = true;

  # PCIe ASPM can cause link renegotiation disconnects on RTL8111
  # boards — same symptom family as the EEE bug handled by
  # modules/hardware/realtek-eee.nix. Kept enabled while the EEE fix
  # alone proves stable. Tradeoff: slightly higher idle power draw.
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Caps the boot menu to the last 20 generations so the ESP doesn't
  # fill up with entries even if you rebuild a lot in a short window.
  # Lanzaboote respects this even though systemd-boot.enable is off.
  boot.loader.systemd-boot.configurationLimit = 20;
}
