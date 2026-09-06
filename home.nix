# Home Manager configuration for user "fury".
#
# This is the NixOS-integrated variant (no standalone `home-manager`
# switch needed — changes apply via nixos-rebuild). The flake wires
# this file in via:
#
#     home-manager.users.fury = import ./home.nix;
#
# MANAGED HERE (user-level things):
#   - git identity + delta pager
#   - EDITOR/VISUAL (vscodium)
#   - default applications (xdg.mimeApps): browser=brave, mail=
#     mailspring, pdf=sioyek, epub=okular + all URL-scheme handlers
#   - kitty terminal (font, pure black bg, scrollback)
#   - btop (imported from the previous hand-managed btop.conf)
#
# DELIBERATELY STILL SYSTEM-LEVEL (see modules/programs/shell.nix):
#   - zsh itself, aliases, oh-my-zsh, zoxide/fzf init — single-user
#     machine; moving them gains nothing and couples recovery of
#     admin aliases to HM working.
#
# DELIBERATELY NOT MANAGED:
#   - user apps in home.packages (single user — no benefit yet)
#   - vscodium settings.json (app rewrites it at runtime)
#   - app data dirs (obsidian/anytype/opencode own their state)
#   - secrets of any kind (see modules/programs/ai-services.nix
#     header for the sops-nix/agenix pattern)
#
# NOTE: xdg.mimeApps takes over ~/.config/mimeapps.list with a
# read-only symlink. KDE's "default applications" GUI can no longer
# write it — change defaults HERE, rebuild. The previous hand file
# was backed up to mimeapps.list~<hash> on first activation.
{ config, pkgs, lib, ... }:

{
  home.username = "fury";
  home.homeDirectory = "/home/fury";
  # Matches system.stateVersion — do not change.
  home.stateVersion = "26.05";

  # Let HM manage itself inside your user profile.
  programs.home-manager.enable = true;

  # ----------------------------------------------------------------
  # Editor (vscodium)
  # ----------------------------------------------------------------
  # --wait: CLI integrations (git commit, sudoedit, gh) block until
  # you close the editor window, instead of committing immediately.
  home.sessionVariables = {
    EDITOR = "codium --wait";
    VISUAL = "codium --wait";
  };

  # ----------------------------------------------------------------
  # git (identity + settings) and delta (nicer diffs)
  # ----------------------------------------------------------------
  programs.git = {
    enable = true;

    settings = {
      user.name  = "furynix";
      user.email = "235014707+Hackcoon@users.noreply.github.com";

      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      diff.colorMoved = "default";
    };
  };

  # On HM 26.05 this is a top-level option (not programs.git.delta).
  # It wires itself into git automatically (interactive diff/pager).
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # ----------------------------------------------------------------
  # Default applications (xdg.mimeApps)
  # ----------------------------------------------------------------
  # Takes over ~/.config/mimeapps.list (read-only). All previous
  # hand-made associations were migrated here 2026-09-06 — nothing
  # dropped. Desktop-file names verified against the installed
  # packages in /run/current-system/sw/share/applications/.
  xdg.mimeApps = {
    enable = true;

    # "Open with this by default" per file type / URL scheme.
    defaultApplications = {
      # --- requested defaults ---
      # PDFs: sioyek (research-paper viewer; the working wrapper
      # lives in modules/packages/apps-fixed.nix)
      "application/pdf" = "sioyek.desktop";
      # EPub: okular — sioyek is PDF-ONLY (upstream: "a PDF viewer
      # for technical books and research papers"); the old hand
      # config pointed epub at sioyek, which failed to open.
      "application/epub+zip" = "okularApplication_epub.desktop";
      # Browser: brave (com.brave.Browser.desktop is the canonical
      # name; brave-browser.desktop is a compat alias)
      "x-scheme-handler/http" = "com.brave.Browser.desktop";
      "x-scheme-handler/https" = "com.brave.Browser.desktop";
      "text/html" = "com.brave.Browser.desktop";
      # Mail client: mailspring
      "x-scheme-handler/mailto" = "Mailspring.desktop";

      # --- migrated from the previous hand-managed file ---
      "x-scheme-handler/cherrystudio" = "cherry-studio.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/notion" = "notion-app-enhanced.desktop";
      "x-scheme-handler/obsidian" = "obsidian.desktop";
      "x-scheme-handler/opencode" = "opencode-desktop.desktop";
      "x-scheme-handler/heroic" = "com.heroicgameslauncher.hgl.desktop";
      "x-scheme-handler/lmstudio" = "lm-studio.desktop";
      "x-scheme-handler/logseq" = "Logseq.desktop";
      "x-scheme-handler/mailspring" = "Mailspring.desktop";
    };

    # "Show in the Open With menu" lists (migrated as-is).
    associations.added = {
      "application/epub+zip" = [
        "sioyek.desktop"
        "okularApplication_epub.desktop"
        "onlyoffice-desktopeditors.desktop"
      ];
      "application/pdf" = "sioyek.desktop";
      "x-scheme-handler/cherrystudio" = [ "cherry-studio.desktop" "CherryStudio.desktop" ];
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/notion" = "notion-app-enhanced.desktop";
      "x-scheme-handler/obsidian" = [ "obsidian.desktop" "md.Obsidian.desktop" ];
      "x-scheme-handler/opencode" = [ "opencode-desktop.desktop" "opencode-ai-desktop.desktop" ];
      "x-scheme-handler/heroic" = "com.heroicgameslauncher.hgl.desktop";
      "x-scheme-handler/lmstudio" = [ "lm-studio.desktop" "LM-Studio.desktop" ];
      "x-scheme-handler/logseq" = "Logseq.desktop";
    };

    # Apps deliberately hidden from "Open With" for a type
    # (migrated as-is).
    associations.removed = {
      "application/epub+zip" = [
        "org.kde.ark.desktop"
        "org.prismlauncher.PrismLauncher.desktop"
      ];
    };
  };

  # ----------------------------------------------------------------
  # kitty terminal
  # ----------------------------------------------------------------
  # Previously ~/.config/kitty/ was EMPTY (100% defaults), so this
  # is a pure upgrade, not a takeover. Font matches the system
  # default monospace (fonts.nix); background forced pure black.
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11.0;
    };

    # Dark theme as the color base; individual settings below
    # override its background to pure black. (Valid themeFile names:
    # `ls $(nix build --print-out-paths --no-link nixpkgs#kitty-themes)/share/kitty-themes/themes/`)
    themeFile = "Catppuccin-Mocha";

    settings = {
      background = "#000000";          # pure black (your requirement)
      scrollback_lines = 100000;        # generous history
      confirm_os_window_close = 0;      # don't nag on close
      enable_audio_bell = false;        # no beeps
      copy_on_select = "clipboard";     # selection → clipboard
      strip_trailing_space = "smart";  # clean copy/paste
    };

    # shell integration gives cwd-following + jump marks in zsh
    shellIntegration.enableZshIntegration = true;
  };

  # ----------------------------------------------------------------
  # btop (imported as-is from the previous hand-managed btop.conf)
  # ----------------------------------------------------------------
  # Every non-default value from ~/.config/btop/btop.conf on
  # 2026-09-06. Your custom ~/.config/btop/themes/ directory is NOT
  # managed by HM and stays untouched. btop normally rewrites its
  # conf on exit (save_config_on_exit) — under HM the file is a
  # read-only store symlink, so runtime tweaks live in memory for
  # the session only. Make tweaks permanent by editing here.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "Default";
      theme_background = true;
      truecolor = true;
      force_tty = false;

      # Layout & drawing
      rounded_corners = true;
      graph_symbol = "braille";
      shown_boxes = "cpu mem net proc";
      update_ms = 2000;

      # Process list
      proc_sorting = "cpu lazy";
      proc_reversed = false;
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = false;
      proc_mem_bytes = true;
      proc_cpu_graphs = true;
      proc_info_smaps = false;
      proc_left = false;
      proc_filter_kernel = false;
      proc_follow_detailed = true;
      proc_aggregate = false;
      keep_dead_proc_usage = false;

      # CPU box
      cpu_graph_upper = "Auto";
      cpu_graph_lower = "Auto";
      show_gpu_info = "Auto";
      cpu_invert_lower = true;
      cpu_single_graph = false;
      cpu_bottom = false;
      show_cpu_watts = true;
      check_temp = true;
      cpu_sensor = "Auto";
      show_coretemp = true;
      temp_scale = "celsius";
      show_cpu_freq = true;
      freq_mode = "first";

      # Memory / disks
      mem_graphs = true;
      mem_below_net = false;
      zfs_arc_cached = true;
      show_swap = true;
      swap_disk = true;
      show_disks = true;
      only_physical = true;
      use_fstab = true;
      show_io_stat = true;
      io_mode = false;
      io_graph_combined = false;

      # Network
      net_download = 100;
      net_upload = 100;
      net_auto = true;
      net_sync = true;
      base_10_bitrate = "Auto";

      # Misc
      show_battery = true;
      show_battery_watts = true;
      selected_battery = "Auto";
      clock_format = "%X";
      show_uptime = true;
      background_update = true;
      vim_keys = false;
      disable_mouse = false;
      terminal_sync = true;
      log_level = "WARNING";
      save_config_on_exit = true;
      gpu_mirror_graph = true;
      nvml_measure_pcie_speeds = true;
      rsmi_measure_pcie_speeds = true;
      shown_gpus = "nvidia amd intel apple";
    };
  };
}
