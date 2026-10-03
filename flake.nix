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
  # When run:
  #
  #     sudo nix flake lock
  #
  # Nix records the exact revision of every input in flake.lock.
  # This makes the system reproducible and prevents a rebuild
  # from silently changing because a GitHub branch moved.
  inputs = {
    # ----------------------------------------------------------
    # Stable NixOS Package Source
    # ----------------------------------------------------------
    # This is the main package collection for the entire system.
    #
    # The installed system is NixOS 26.05, so this branch keeps
    # the kernel, NVIDIA driver, Plasma, Wayland, PipeWire,
    # system services, and other core components aligned.
    #
    # This is intentionally NOT nixos-unstable due to NVIDIA driver
    # compilation and compatibility concerns.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";


    # ----------------------------------------------------------
    # Lanzaboote Secure Boot Module
    # ----------------------------------------------------------
    # Lanzaboote provides the NixOS module needed to create and
    # install signed Secure Boot boot entries.
    #
    # This does not create or move Secure Boot keys.
    # Existing keys remain at:
    #
    #     /etc/secureboot
    #
    lanzaboote.url = "github:nix-community/lanzaboote";

    # Tell Lanzaboote to use the same stable nixpkgs input as
    # the rest of the system instead of creating a separate
    # nixpkgs revision inside the Lanzaboote dependency tree.
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";


    # ----------------------------------------------------------
    # Optional Unstable Package Source
    # ----------------------------------------------------------
    # This provides access to newer individual applications.
    #
    # It does NOT make the rest of the system unstable.
    # Select unstable explicitly via unstablePkgs.some-package in
    # configuration.nix.
    #
    # The NVIDIA driver, kernel, desktop stack, PipeWire,
    # and other core components stay on the stable pkgs collection.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ----------------------------------------------------------
    # Qylock SDDM / Quickshell Lockscreen Themes
    # ----------------------------------------------------------
    # Provides SDDM login-screen themes and a Quickshell-based
    # lockscreen, packaged as a NixOS module (programs.qylock).
    #
    # Quickshell isn't in stable nixpkgs yet, so instead of letting
    # qylock pull in its own separate nixpkgs-unstable copy, point
    # it at the nixpkgs-unstable input declared above.
    qylock.url = "github:Darkkal44/qylock";
    qylock.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # ----------------------------------------------------------
    # Dank Material Shell 1.6 (dms)
    # ----------------------------------------------------------
    # Upstream flake — pinned to the v1.6.2 tag. nixpkgs only has
    # 1.5.3 and this machine had 1.4.6. Provides the
    # programs.dank-material-shell NixOS module (replaces the old
    # programs.dms-shell option name from 1.4.x).
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------------------------------
    # Dank Greeter (greetd login screen, standalone as of DMS 1.6)
    # ----------------------------------------------------------
    # A greetd greeter matching the DMS aesthetic. Provides
    # programs.dms-greeter NixOS module. NOTE: this replaces SDDM
    # as the *login* screen when enabled — KDE sessions still work
    # through greetd's session list.
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------------------------------
    # Dank Search (dsearch) — indexed filesystem search
    # ----------------------------------------------------------
    # Home Manager module (programs.dsearch) + dsearch package.
    # Runs a user service that indexes files for fuzzy search.
    dsearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------------------------------
    # Zen Browser (beta)
    # ----------------------------------------------------------
    # Firefox fork. Package used via specialArgs as `zenBrowser`
    # (see outputs let-block). Follows nixpkgs-unstable for
    # Firefox compat, same as qylock/dms.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------------------------------
    # Concat video editor (native Rust build)
    # ----------------------------------------------------------
    # Free open-source CapCut replacement. Upstream maintains its
    # own flake (nix build / nix run) pinned to nixos-unstable.
    #
    # HOW TO UPDATE:
    #   1. Check https://github.com/jub0t/Concat/releases/latest
    #      (e.g. v0.2.4).
    #   2. Change ONLY the tag below: "github:jub0t/Concat/v0.2.3"
    #      → "github:jub0t/Concat/v0.2.4".
    #   3. Run: sudo nix flake update concat
    #      then: sudo nixos-rebuild build --flake /etc/nixos#nixos
    # No hash dance — the flake.lock pins the exact revision.
    concat = {
      url = "github:jub0t/Concat/v0.2.4";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------------------------------
    # Hermes AI Agent
    # ----------------------------------------------------------
    # Provides the native NixOS module, systemd service, and
    # optional container environment for Hermes Agent.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";



    # ----------------------------------------------------------
    # ComfyUI image/video generation (FLAKE module + packages)
    # ----------------------------------------------------------
    # This input is a FLAKE: github:utensils/comfyui-nix.
    # It provides:
    #   - comfyui-nix.nixosModules.default  -> `services.comfyui.*` options
    #     (wired in outputs `modules = [...]` below; config lives in
    #     ./modules/ai/comfyui.nix)
    #   - packages cuda/rocm/xpu/default + overlay `comfy-ui*`
    #   - binary cache comfyui.cachix.org (see modules/core/nix.nix)
    #
    # Do NOT add `inputs.nixpkgs.follows = "nixpkgs"` here: this flake
    # needs its pinned nixos-unstable for pre-built PyTorch CUDA wheels
    # (Turing through Blackwell, driver >= 580). Following stable would
    # break the CUDA closure on this NixOS 26.05 system.
    #
    # HOW TO UPDATE:
    #   sudo nix flake update comfyui-nix
    #   sudo nixos-rebuild switch --flake /etc/nixos#nixos
    comfyui-nix.url = "github:utensils/comfyui-nix";



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

      # Dank Material Shell 1.6 + Dank Greeter + Dank Search.
      dms,
      dank-greeter,
      dsearch,

      # Zen Browser flake (beta package).
      zen-browser,

      # Concat video editor flake (native Rust package).
      concat,

      # Hermes Agent NixOS/Home Manager module.
      hermes-agent,

      # ComfyUI image/video generation FLAKE (utensils/comfyui-nix).
      # Exposes comfyui-nix.nixosModules.default + packages/overlays.
      comfyui-nix,

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
      # ARM boxes (Raspberry Pi, Asahi) are NOT covered by flipping this:
      # aarch64 needs its own nixosSystem entry (different kernel, bootloader,
      # firmware) plus a fresh hardware-configuration.nix — not a module toggle.
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

        # Allow unfree packages from unstable only when explicitly
        # selected via unstablePkgs.some-package.
        config.allowUnfree = true;
      };

      # ==========================================================
      # ZEN BROWSER (beta, via zen-browser-flake input)
      # ==========================================================
      # `packages.${system}.default` tracks Zen beta.
      # Exposed to configuration.nix modules as `zenBrowser`
      # via specialArgs below.
      zenBrowser = zen-browser.packages.${system}.default;

      # ==========================================================
      # CONCAT VIDEO EDITOR (native, via upstream flake)
      # ==========================================================
      # `packages.${system}.concat` is the editor window (bin/concat),
      # built from source with the wgpu renderer + Vulkan runtime libs.
      # Exposed to configuration.nix as `concatPkg` via specialArgs.
      # UPDATE: bump the `concat.url` tag above, then
      #   sudo nix flake update concat
      concatPkg = concat.packages.${system}.concat;
    in
    {
      # ==========================================================
      # NIXOS SYSTEM CONFIGURATION
      # ==========================================================
      # "nixos" is the name of the machine's configuration.
      #
      # This uses nixpkgs, which is the stable NixOS 26.05
      # input. Therefore the normal "pkgs" used by the system
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
          # Usage:
          #
          #   pkgs.some-package
          #
          # for stable packages, or:
          #
          #   unstablePkgs.some-package
          #
          # for one intentionally selected unstable package.
          specialArgs = {
            inherit unstablePkgs zenBrowser concatPkg;
          };


          # --------------------------------------------------------
          # NixOS Modules
          # --------------------------------------------------------
          # These are the configuration files and external modules
          # used to build the system.
          modules = [
            # The main NixOS configuration.
            #
            # This contains the bootloader, Secure Boot settings,
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

            # Dank Material Shell 1.6 — replaces the nixpkgs
            # programs.dms-shell module (mango-dms.nix switched to
            # programs.dank-material-shell).
            dms.nixosModules.dank-material-shell

            # Dank Greeter — greetd login screen matching DMS.
            # programs.dms-greeter options wired in mango-dms.nix.
            dank-greeter.nixosModules.default

          
            # Hermes Agent service module.
            #
            # This exposes the `services.hermes-agent` options
            # used in configuration.nix (model choice, secrets,
            # documents, MCP servers, container mode, etc).
            #
            # Adding this line only makes the OPTIONS available.
            # Nothing runs until something like the following is also added
            # to configuration.nix:
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
            # Nix-provided PATH. For an agent able to self-install
            # packages at runtime (apt/pip/npm),
            # set `container.enable = true`, which runs it inside
            # a persistent Ubuntu container instead (needs Docker
            # or Podman).
            hermes-agent.nixosModules.default

            # ComfyUI service module — from the comfyui-nix FLAKE input above.
            # This only makes the `services.comfyui.*` OPTIONS available;
            # the actual values (cuda, port, dataDir, ...) are set in
            # ./modules/ai/comfyui.nix (imported via configuration.nix).
            # The flake module brings its own packages, so no
            # `nixpkgs.overlays = [ comfyui-nix.overlays.default ]` is needed
            # for the service itself.
            comfyui-nix.nixosModules.default

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
              # When HM takes over an existing hand-made file, move it
              # aside to *.<extension> instead of failing activation.
              # Set once for the whole migration; entries land next to
              # the originals (e.g. ~/.config/mimeapps.list.bak).
              home-manager.backupFileExtension = "bak";
              home-manager.extraSpecialArgs = {
                inherit dsearch zen-browser;
              };
              home-manager.users.fury = import ./home.nix;
            }

          ];
        };


      # ==========================================================
      # FUTURE OUTPUTS
      # ==========================================================
      # Nothing needs adding here right now.
      #
      # Future examples could include:
      #
      # - homeConfigurations for Home Manager
      # - packages for custom software
      # - devShells for development environments
      # - formatter for automatic Nix formatting
      #
      # Keep the flake simple until one of those features is needed.
    };
}