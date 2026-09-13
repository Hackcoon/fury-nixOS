# Razer peripherals via OpenRazer + Polychromatic frontend.
{ config, pkgs, lib, ... }:

{
  hardware.openrazer = {
    enable = true;
    users = [ "fury" ];
  };

  environment.systemPackages = with pkgs; [
    polychromatic
  ];
}
