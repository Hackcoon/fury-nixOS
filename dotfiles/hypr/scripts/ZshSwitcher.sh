#!/usr/bin/env bash
# ZshSwitcher.sh — cycle zsh prompt themes
# Your setup: oh-my-zsh via programs.zsh (modules/programs/shell.nix), with
# custom themes registered as ohMyZsh.plugins (powerlevel10k pattern).
# This script switches the ZSH_THEME line in ~/.zshrc — safe with your config.
ZSHRC="$HOME/.zshrc"
THEMES_FILE="$HOME/.config/hypr/scripts/.zsh-themes"

# Available themes: oh-my-zsh built-ins + anything custom you've registered.
# Edit this list to match what you actually keep installed:
if [[ ! -f "$THEMES_FILE" ]]; then
  cat > "$THEMES_FILE" <<'EOF'
af-magic
agnoster
robbyrussell
eastwood
fino
jntrnr
lupin
ys
EOF
fi

mapfile -t themes < "$THEMES_FILE"

# find current
cur=$(grep -m1 '^ZSH_THEME=' "$ZSHRC" 2>/dev/null | sed 's/ZSH_THEME=//; s/"//g')
idx=0
for i in "${!themes[@]}"; do
  [[ "${themes[$i]}" == "$cur" ]] && idx=$i
done
next=$(( (idx + 1) % ${#themes[@]} ))

# write it
if grep -q '^ZSH_THEME=' "$ZSHRC" 2>/dev/null; then
  sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"${themes[$next]}\"|" "$ZSHRC"
else
  echo "ZSH_THEME=\"${themes[$next]}\"" >> "$ZSHRC"
fi

notify-send -t 2000 "Zsh theme" "${themes[$next]} (new terminals)"
