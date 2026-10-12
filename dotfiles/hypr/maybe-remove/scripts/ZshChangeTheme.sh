#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Oh my ZSH theme ( CTRL SHIFT O)

# preview of theme can be view here: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# after choosing theme, TTY need to be closed and re-open

# Variables
iDIR="$HOME/.config/swaync/images"
rofi_theme="$HOME/.config/rofi/config-zsh-theme.rasi"

# NIXOS: oh-my-zsh is system-managed (/etc/zshrc, ZSH=store path).
# We read themes from the store and persist choice in ~/.zshrc-theme
# (sourced by /etc/zshrc user hook if present, else exported as ZSH_THEME
# via a snippet appended to ~/.zshrc which oh-my-zsh sees too late —
# so instead we use ZSH_THEME_OVERRIDE file sourced at the end).
themes_dir="${ZSH:-$(grep -oP '(?<=^export ZSH=).*' /etc/zshrc 2>/dev/null | tr -d '"' || echo $HOME/.oh-my-zsh)}/themes"
[[ -d "$themes_dir" ]] || themes_dir="/nix/store/7s8k6aj3w7hsb3lxcp1zr59r5dhk870i-oh-my-zsh-2026-02-19/share/oh-my-zsh/themes"
file_extension=".zsh-theme"


themes_array=($(find -L "$themes_dir" -type f -name "*$file_extension" -exec basename {} \; | sed -e "s/$file_extension//"))

# Add "Random" option to the beginning of the array
themes_array=("Random" "${themes_array[@]}")

rofi_command="rofi -i -dmenu -config $rofi_theme"

menu() {
    for theme in "${themes_array[@]}"; do
        echo "$theme"
    done
}

main() {
    choice=$(menu | ${rofi_command})

    # if nothing selected, script won't change anything
    if [ -z "$choice" ]; then
        exit 0
    fi

    zsh_path="$HOME/.zshrc-theme"
    var_name="ZSH_THEME"

    if [[ "$choice" == "Random" ]]; then
        # Pick a random theme from the original themes_array (excluding "Random")
        random_theme=${themes_array[$((RANDOM % (${#themes_array[@]} - 1) + 1))]}
        theme_to_set="$random_theme"
        notify-send -i "$iDIR/ja.png" "Random theme:" "selected: $random_theme"
    else
        # Set theme to the selected choice
        theme_to_set="$choice"
        notify-send -i "$iDIR/ja.png" "Theme selected:" "$choice"
    fi

    echo "$var_name=\"$theme_to_set\"" > "$zsh_path"
    notify-send -i "$iDIR/ja.png" "OMZ theme" "saved to ~/.zshrc-theme — run: source ~/.zshrc-theme"
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
