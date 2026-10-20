#!/usr/bin/env bash
# fzf toolbox for the ~/.local/bin micro tools.
# Pick a tool -> type args -> output in pager -> back to picker. Ctrl-C quits.
set -uo pipefail

BIN="$HOME/.local/bin"

pick_tool() {
    # NOTE: {} must stay UNQUOTED here — fzf substitutes it pre-quoted,
    # and wrapping it in "" would make the quotes literal (broken path).
    ls "$BIN"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | \
        fzf --prompt='tool ❯ ' --height=70% --layout=reverse --info=hidden \
            --preview='grep -m1 -i usage '"$BIN"'/{}.sh 2>/dev/null; echo ---; sed -n 2,10p '"$BIN"'/{}.sh' \
            --preview-window=right,55%,wrap --preview-label=' usage '
}

while true; do
    tool=$(pick_tool) || exit 0
    [[ -z "$tool" ]] && exit 0
    read -rp "args for [$tool] (enter = none): " args
    # shellcheck disable=SC2086
    "$BIN/$tool.sh" $args 2>&1 | less -R -F -X
    echo
    read -rp "press enter for toolbox, Ctrl-C to quit..." _
done
