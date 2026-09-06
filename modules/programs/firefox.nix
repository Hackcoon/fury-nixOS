# Firefox — system-wide installation via the NixOS module
# (wraps the unwrapped package with policies/wrapping support).
{ config, pkgs, lib, ... }:

{
  programs.firefox.enable = true;
}
