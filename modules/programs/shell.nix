# Zsh + Oh My Zsh + aliases + direnv. The whole terminal experience.
{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;

    # Links /share/zsh (all package completions) into fpath and
    # installs nix-zsh-completions. Setting false breaks completions.
    enableCompletion = true;

    # Removes ONLY the duplicate compinit call from /etc/zshrc —
    # Oh My Zsh runs its own compinit anyway.
    enableGlobalCompInit = false;

    # Flat option (NOT history = { ... }) — sets both HISTSIZE and
    # SAVEHIST. histFile already defaults to ~/.zsh_history.
    histSize = 10000;

    autosuggestions.enable = true;      # gray suggestions from history
    syntaxHighlighting.enable = true;   # red invalid, green valid

    ohMyZsh = {
      enable = true;
      theme = "af-magic";
      plugins = [
        # "git"     # git aliases (gst, gco, gcmsg, gp, ...)
        "sudo"
        # "docker"  # tab-completion for docker commands
      ];
    };

    # Custom (non-bundled) themes like powerlevel10k go here instead
    # of theme = "...". Remember to comment out `theme` above:
    # ohMyZsh.plugins = [
    #   {
    #     name = "powerlevel10k";
    #     src = pkgs.zsh-powerlevel10k;
    #     file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    #   }
    # ];

    shellAliases = {
      # ---------- Everyday commands ----------
      ls   = "eza --icons";                 # modern ls with icons
      ll   = "eza -lah --icons";            # detailed + hidden + readable sizes
      lsd  = "eza -l --icons --only-dirs";  # directories only
      cat  = "bat";                         # syntax-highlighted cat
      man  = "batman";                      # colourized manpages
      ".." = "cd ..";                       # up one directory
      duh  = "du -sh ./*";                  # size of every item in cwd
      c    = "clear";                       # clear the screen
      restart-gui = "sudo systemctl restart display-manager";

      # ---------- NixOS rebuild commands ----------
      # nix-test: temporarily activate WITHOUT making it the permanent
      # boot generation — use first after editing config files.
      nix-test = "sudo nixos-rebuild test --flake /etc/nixos#nixos";
      # nix-switch: activate permanently — use once nix-test looks good.
      nix-switch = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      # Short alias for a normal permanent rebuild (same as nix-switch).
      nix-rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      # Build the system without activating it.
      nix-build-system = "sudo nixos-rebuild build --flake /etc/nixos#nixos";
      # Check the system can build — changes nothing on the running system.
      nix-build-dry = "sudo nixos-rebuild dry-build --flake /etc/nixos#nixos";

      # ---------- Flake update commands ----------
      # nix-upgrade: intentionally update flake inputs and rebuild —
      # this changes /etc/nixos/flake.lock.
      nix-upgrade = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      # Update flake.lock without rebuilding or activating yet.
      flake-update = "cd /etc/nixos && sudo nix flake update";
      # Rebuild using the exact versions already recorded in flake.lock.
      nix-upgrade-locked = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      # Check whether the flake structure and outputs are valid.
      nix-check = "sudo nix flake check /etc/nixos";
      # Show the exact versions of your flake inputs.
      nix-inputs = "nix flake metadata /etc/nixos";

      # ---------- Generations & rollback ----------
      # See older system versions available for rollback.
      nix-generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      # nix-keep-10: trim the profile to the last 10 generations, GC
      # anything now-unreachable, regenerate the boot menu to match.
      nix-keep-10 = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +10 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      # Same as nix-keep-10 but keeps 20 — more rollback headroom.
      nix-keep-20 = "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +20 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      # nix-rollback: return to the previous generation when the
      # current one causes a problem.
      nix-rollback = "sudo nixos-rebuild switch --rollback";
      # Show the system generation currently in use.
      nix-current = "readlink /nix/var/nix/profiles/system";

      # ---------- Nix store cleanup ----------
      # nixdelete: normal cleanup — removes generations older than 30
      # days while preserving recent rollback options.
      nixdelete = "sudo nix-collect-garbage --delete-older-than 30d";
      # Shorter alias for the same normal garbage collection.
      nix-gc = "sudo nix-collect-garbage --delete-older-than 30d";
      # WARNING: removes ALL old generations — only when you're certain
      # you no longer need any rollback.
      nix-delete-all-old = "sudo nix-collect-garbage --delete-old";
      # Show how much space the Nix store is using.
      nix-store-size = "sudo du -sh /nix/store";
      # Manually deduplicate identical files in the Nix store.
      nix-optimize = "sudo nix-store --optimise";

      # ---------- Nix file commands ----------
      # Keep formatting consistent after editing configuration.nix or
      # flake.nix. Requires nixfmt in systemPackages.
      nix-format = "sudo nixfmt /etc/nixos/configuration.nix /etc/nixos/flake.nix";

      # ---------- Configuration Git commands ----------
      # Review changes to your configuration.
      config-diff = "cd /etc/nixos && sudo git diff";
      # Show changed and untracked files.
      config-status = "cd /etc/nixos && sudo git status";
      # Show your ten most recent configuration commits.
      config-log = "cd /etc/nixos && sudo git log --oneline --decorate -10";
      # Save the current configuration in a Git commit (prompts for message).
      config-save = "cd /etc/nixos && sudo git add . && sudo git commit";

      # ---------- System information ----------
      # Show system, CPU, GPU, memory, and kernel information.
      ff = "fastfetch";
      # Open an interactive resource monitor.
      bt = "btop";
      # Open the dank interactive resource monitor.
      dg = "dgop";
      # Show disk space usage.
      disks = "df -h";
      # Show memory and swap usage.
      memory = "free -h";
      # Show network interfaces and IP addresses.
      myip = "ip -brief address";
      # Show failed systemd services.
      boot-status = "systemctl --failed";
      # Show Secure Boot status.
      sb-status = "sbctl status";
      # Verify Secure Boot.
      sb-verify = "sbctl verify";
    };

    # Initialize Zsh tools when an interactive shell opens.
    interactiveShellInit = ''
      eval "$(zoxide init zsh)"
      eval "$(fzf --zsh)"
    '';
  };

  # Automatically load per-project development environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
