# tide-island NixOS module — copied into your flake for pure evaluation.
# Source of truth: ~/Projects/tide-island-nix (keep both in sync when you hack).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.tide-island;
in
{
  options.programs.tide-island = {
    enable = lib.mkEnableOption "Tide Island, the Quickshell Dynamic Island for Hyprland/niri";

    package = lib.mkPackageOption pkgs "tide-island" { };

    withHelpers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install runtime helpers that island features shell out to";
    };

    withSystemdService = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install a systemd user service (tide-island.service) bound to
        graphical-session.target instead of compositor autostart.
      '';
    };
  };

  config =
    with lib;
    mkIf cfg.enable (mkMerge [
      {
        environment.systemPackages =
          [ cfg.package ]
          ++ optionals cfg.withHelpers (
            with pkgs;
            [
              brightnessctl
              cava                       # island audio visualizer (SwipeCavaBars)
              imagemagick                # wallpaper thumbnails
              networkmanager             # wifi control (or iwd)
              python313Packages.pywal    # colors from wallpaper (Tide option)
            ]
          );

        services.upower.enable = mkDefault true;      # battery tile
        hardware.bluetooth.enable = mkDefault true;    # bluetooth page + pairing agent
      }

      (mkIf cfg.withSystemdService {
        systemd.user.services.tide-island = {
          description = "Tide Island Dynamic Island for Hyprland and niri";
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${cfg.package}/bin/tide-island";
            Restart = "on-failure";
            RestartSec = 3;
          };
        };
      })
    ]);
}
