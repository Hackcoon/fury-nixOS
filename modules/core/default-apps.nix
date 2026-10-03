# ============================================================================
# default-apps.nix — Default applications (system-level, /etc/xdg).
#
# WHY A SYSTEM MODULE, NOT HOME MANAGER:
# KDE apps periodically rewrite ~/.config/mimeapps.list (KConfig atomic-save
# replaces the file, silently discarding any symlink). HM-managed user-level
# mimeapps therefore breaks on collision or gets de-symlinked. /etc/xdg is
# never touched by user apps — a stable, conflict-free location for defaults.
#
# XDG precedence: a USER-level mimeapps.list OVERRIDES this file.
# ~/.config/mimeapps.list currently exists as a leftover (KDE-replaced copy of
# an old HM generation, no unique content) — it must be deleted so these system
# defaults take effect. Changing a default via KDE's GUI later writes to the
# user file, which simply wins until deleted again — no breakage either way.
#
# Desktop-file names verified against /run/current-system/sw/share/applications
# (2026-09-06): okularApplication_pdf/epub, com.brave.Browser.desktop
# (brave-browser.desktop is a compat alias in the same package), Mailspring.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── XDG mime defaults: what opens what ──
  # "Open with this by default" per file type / URL scheme, plus Open With
  # menu lists and deliberate removals. URL-scheme handlers were migrated from
  # the old hand-managed user file so electron deep-links keep working.
  xdg.mime = {
    enable = true; # enable defaults to true in NixOS; explicit for clarity

    defaultApplications = {
      # PDFs + EPub: okular (changed from sioyek 2026-09-06;
      # sioyek remains in Open With lists below)
      "application/pdf" = "okularApplication_pdf.desktop";
      "application/epub+zip" = "okularApplication_epub.desktop";

      # Browser: brave
      "x-scheme-handler/http" = "com.brave.Browser.desktop";
      "x-scheme-handler/https" = "com.brave.Browser.desktop";
      "text/html" = "com.brave.Browser.desktop";

      # Mail client: mailspring
      "x-scheme-handler/mailto" = "Mailspring.desktop";

      # URL-scheme handlers (migrated from the old hand file)
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

    # "Show in the Open With menu" lists — sioyek stays available for
    # pdf/epub even though okular is the default.
    addedAssociations = {
      "application/pdf" = [
        "okularApplication_pdf.desktop"
        "sioyek.desktop"
      ];
      "application/epub+zip" = [
        "okularApplication_epub.desktop"
        "sioyek.desktop"
        "onlyoffice-desktopeditors.desktop"
      ];
    };

    # Apps deliberately hidden from "Open With" for a type.
    removedAssociations = {
      "application/epub+zip" = [
        "org.kde.ark.desktop"
        "org.prismlauncher.PrismLauncher.desktop"
      ];
    };
  };
  # ----------------------------------------------------------------------

  # ── sioyek: dark mode, pure black (system-level) ──
  # Same rationale as above: /etc/xdg is read via XDG_CONFIG_DIRS and never
  # rewritten by the app — sioyek only READS prefs_user.config paths; runtime
  # changes persist to ~/.local/share/sioyek/auto.config instead (verified in
  # sioyek source main.cpp/config.cpp).
  # How it works: startup_commands fires every launch (per sioyek's own prefs
  # comment, this supersedes the deprecated default_dark_mode). Dark mode
  # renders by inverting the page through a shader: background 0 0 0 = fully
  # black, contrast 1.0 = pure white text with NO grey dimming (stock default
  # 0.8 dims whites to light grey — flip to the grey pair below if pure white
  # is too harsh). Explanations live HERE, not in the string: everything
  # inside '' lands verbatim in the generated file.
  environment.etc."xdg/sioyek/prefs_user.config".text = ''
    startup_commands    toggle_dark_mode
    dark_mode_background_color   0.0 0.0 0.0
    dark_mode_contrast           1.0

    # --- grey option (uncomment both lines to switch) ---
    # dark_mode_background_color   0.1 0.1 0.1
    # dark_mode_contrast           0.8
  '';
  # ----------------------------------------------------------------------
}
