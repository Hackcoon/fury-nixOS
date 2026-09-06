{
  # ============================================================
  # FLAKE DESCRIPTION
  # ============================================================
  # This is a human-readable description of what this flake
  # manages. It does not affect the system build.
  description = "Fury's NixOS 26.05 desktop configuration";


  # ============================================================
  # FLAKE INPUTS
  # ============================================================
  # Inputs are external projects that this flake depends on.
  #
  # When you run:
  #
  #     sudo nix flake lock
  #
  # Nix records the exact revision of every input in flake.lock.
  # This makes your system reproducible and prevents a rebuild
  # from silently changing because a GitHub branch moved.
  inputs = {
    # ----------------------------------------------------------
    # Stable NixOS Package Source
    # ----------------------------------------------------------
    # This is the main package collection for your entire system.
    #
    # Your installed system is NixOS 26.05, so this branch keeps
    # the kernel, NVIDIA driver, Plasma, Wayland, PipeWire,
    # system services, and other core components aligned.
    #
    # This is intentionally NOT nixos-unstable because you had
    # NVIDIA driver compilation and compatibility concerns.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";


    # ----------------------------------------------------------
    # Lanzaboote Secure Boot Module
    # ----------------------------------------------------------
    # Lanzaboote provides the NixOS module needed to create and
    # install signed Secure Boot boot entries.
    #
    # This does not create or move your Secure Boot keys.
    # Your existing keys remain at:
    #
    #     /etc/secureboot
    #
    lanzaboote.url = "github:nix-community/lanzaboote";

    # Tell Lanzaboote to use the same stable nixpkgs input as
    # the rest of your system instead of creating a separate
    # nixpkgs revision inside the Lanzaboote dependency tree.
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";


    # ----------------------------------------------------------
    # Optional Unstable Package Source
    # ----------------------------------------------------------
    # This provides access to newer individual applications.
    #
    # It does NOT make the rest of your system unstable.
    # You must explicitly use unstablePkgs.some-package in
    # configuration.nix to select something from this input.
    #
    # Keep your NVIDIA driver, kernel, desktop stack, PipeWire,
    # and other core components on the stable pkgs collection.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ----------------------------------------------------------
    # Qylock SDDM / Quickshell Lockscreen Themes
    # ----------------------------------------------------------
    # Provides SDDM login-screen themes and a Quickshell-based
    # lockscreen, packaged as a NixOS module (programs.qylock).
    #
    # Quickshell isn't in stable nixpkgs yet, so instead of letting
    # qylock pull in its own separate nixpkgs-unstable copy, point
    # it at the nixpkgs-unstable input you already declare above.
    qylock.url = "github:Darkkal44/qylock";
    qylock.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # ----------------------------------------------------------
    # Hermes AI Agent
    # ----------------------------------------------------------
    # Provides the native NixOS module, systemd service, and
    # optional container environment for Hermes Agent.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";



    # ----------------------------------------------------------
    # Home Manager Input
    # ----------------------------------------------------------
    # Home Manager manages user-level ("dotfile") configuration:
    # git config, shell setup, editor settings, user packages.
    #
    # Wired via home.nix. release-26.05 matches this flake's
    # nixos-26.05 nixpkgs: HM and nixpkgs release branches must
    # correspond or HM warns about version skew. inputs.nixpkgs.follows
    # makes user packages and system packages share ONE nixpkgs
    # evaluation (avoids "two nixpkgs" profile mismatches).
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };


  # ============================================================
  # FLAKE OUTPUTS
  # ============================================================
  # Outputs are the configurations and packages produced by
  # this flake.
  #
  # This flake produces one NixOS system called "nixos".
  # That name is used in commands such as:
  #
  #     sudo nixos-rebuild test --flake /etc/nixos#nixos
  #
  outputs =
    {
      # "self" refers to this flake itself.
      self,

      # Stable NixOS package collection.
      nixpkgs,

      # Optional unstable package collection.
      nixpkgs-unstable,

      # Lanzaboote module.
      lanzaboote,

      # Qylock SDDM/Quickshell lockscreen module.
      qylock,

      # Hermes Agent NixOS/Home Manager module.
      hermes-agent,

      # Home Manager — user-level (dotfile) configuration.
      home-manager,

      # The "... " allows future inputs to be added without
      # requiring this function argument list to be rewritten.
      ...
    }:

    let
      # ==========================================================
      # SYSTEM ARCHITECTURE
      # ==========================================================
      # Most normal Intel and AMD desktop computers use this.
      # NVIDIA graphics cards do not change this value.
      system = "x86_64-linux";


      # ==========================================================
      # OPTIONAL UNSTABLE PACKAGE COLLECTION
      # ==========================================================
      # Import nixos-unstable separately.
      #
      # This gives configuration.nix a second package collection
      # called "unstablePkgs".
      #
      # The stable package collection remains named "pkgs".
      unstablePkgs = import nixpkgs-unstable {
        inherit system;

        # Allow unfree packages from unstable only when you
        # explicitly select them with unstablePkgs.some-package.
        config.allowUnfree = true;
      };
    in
    {
      # ==========================================================
      # NIXOS SYSTEM CONFIGURATION
      # ==========================================================
      # "nixos" is the name of your machine's configuration.
      #
      # This uses nixpkgs, which is your stable NixOS 26.05
      # input. Therefore the normal "pkgs" used by your system
      # comes from stable nixpkgs.
      nixosConfigurations.nixos =
        nixpkgs.lib.nixosSystem {
          # Use the architecture defined above.
          inherit system;


          # --------------------------------------------------------
          # Extra Arguments Passed To configuration.nix
          # --------------------------------------------------------
          # specialArgs makes unstablePkgs available inside
          # configuration.nix.
          #
          # This means the first line of configuration.nix should
          # include unstablePkgs:
          #
          # { config, pkgs, lib, unstablePkgs, ... }:
          #
          # You can then use:
          #
          #   pkgs.some-package
          #
          # for stable packages, or:
          #
          #   unstablePkgs.some-package
          #
          # for one intentionally selected unstable package.
          specialArgs = {
            inherit unstablePkgs;
          };


          # --------------------------------------------------------
          # NixOS Modules
          # --------------------------------------------------------
          # These are the configuration files and external modules
          # used to build your system.
          modules = [
            # Your main NixOS configuration.
            #
            # This contains your bootloader, Secure Boot settings,
            # NVIDIA driver, desktop, portals, PipeWire, users,
            # applications, networking, and services.
            ./configuration.nix

            # Lanzaboote Secure Boot support.
            #
            # The key directory is configured separately in
            # configuration.nix with:
            #
            #   pkiBundle = "/etc/secureboot";
            lanzaboote.nixosModules.lanzaboote

            # Qylock SDDM themes / Quickshell lockscreen module.
            #
            # This exposes the `programs.qylock` options used in
            # configuration.nix.
            qylock.nixosModules.default

          
            # Hermes Agent service module.
            #
            # This exposes the `services.hermes-agent` options
            # used in configuration.nix (model choice, secrets,
            # documents, MCP servers, container mode, etc).
            #
            # Adding this line only makes the OPTIONS available.
            # Nothing runs until you also add something like the
            # following to configuration.nix:
            #
            #   services.hermes-agent = {
            #     enable = true;
            #     settings.model.default = "anthropic/claude-sonnet-4";
            #     environmentFiles = [ config.sops.secrets."hermes-env".path ];
            #     addToSystemPackages = true;
            #   };
            #
            # IMPORTANT — secrets: never put API keys directly in
            # `settings` or `environment`; both are written into
            # /nix/store, which is world-readable. Use
            # `environmentFiles` pointed at a sops-nix or agenix
            # secret (or, as a bare-minimum starting point, a
            # manually created 0600 file owned by the hermes user).
            #
            # IMPORTANT — deployment mode: by default this runs as
            # a hardened systemd service directly on the host,
            # where the agent can only use tools already on its
            # Nix-provided PATH. If you want the agent to be able
            # to self-install packages at runtime (apt/pip/npm),
            # set `container.enable = true`, which runs it inside
            # a persistent Ubuntu container instead (needs Docker
            # or Podman).
            hermes-agent.nixosModules.default

            # --------------------------------------------------------
            # Home Manager (NixOS-integration mode)
            # --------------------------------------------------------
            # Manages user-level config for "fury" via ./home.nix.
            # Changes apply with nixos-rebuild — no standalone
            # `home-manager switch` needed.
            #
            #   useGlobalPkgs     -> HM reuses the system's nixpkgs
            #                       config (unfree, cuda, ...), so
            #                       user packages evaluate the same
            #                       as system ones.
            #   useUserPackages   -> user packages install into the
            #                       HM profile (per-user, appears
            #                       in ~/.nix-profile), pairing
            #                       with users.users.fury.packages.
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.fury = import ./home.nix;
            }

          ];
        };


      # ==========================================================
      # FUTURE OUTPUTS
      # ==========================================================
      # You do not need to add anything here right now.
      #
      # Future examples could include:
      #
      # - homeConfigurations for Home Manager
      # - packages for custom software
      # - devShells for development environments
      # - formatter for automatic Nix formatting
      #
      # Keep the flake simple until you actually need one of
      # those features.
    };
}