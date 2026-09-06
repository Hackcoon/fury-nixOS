# System-wide fonts + fontconfig defaults.
{ config, pkgs, lib, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # JetBrains Mono NF (icons for eza, bat, ...)
      noto-fonts                  # Multilingual (Arabic, Cyrillic, ...)
      noto-fonts-cjk-sans         # Chinese/Japanese/Korean
      noto-fonts-color-emoji      # Emoji
      symbola                     # Full Unicode symbols (squared/enclosed letters)
      freefont_ttf                # GNU FreeFont (math bold script)
      stix-two                    # Math & script coverage
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" "FreeMono" "STIX Two Math" "Symbola" ];
        sansSerif = [ "Noto Sans" "FreeSans" "STIX Two Text" "Symbola" ];
        serif     = [ "Noto Serif" "FreeSerif" "STIX Two Text" "Symbola" ];
        emoji     = [ "Noto Color Emoji" ];
      };
    };
  };
}
