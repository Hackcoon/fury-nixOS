#!/usr/bin/env bash
# WaybarLayouts.sh — rofi menu for waybar config layouts (JaKooLit-style menu)
# Layouts dir: ~/.config/waybar/configs  (no file extension, e.g. "[TOP] Default")
CONF="$HOME/.config/waybar"
LAYOUTS_DIR="$CONF/configs"
ACTIVE="$CONF/config.jsonc"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
rofi_config="$HOME/.config/rofi/config-waybar-layout.rasi"
msg=' 🎌 NOTE: Some waybar LAYOUTS NOT fully compatible with some STYLES'

apply_layout() {
    ln -sf "$LAYOUTS_DIR/$1" "$ACTIVE"
    ln -sf "$LAYOUTS_DIR/$1" "$CONF/config"   # keep both symlinks fresh
    "${SCRIPTSDIR}/Refresh.sh" &
}

main() {
    # resolve current symlink target
    current_target=$(readlink -f "$ACTIVE")
    current_name=$(basename "$current_target")

    # gather all layout names into an array
    mapfile -t options < <(
        find -L "$LAYOUTS_DIR" -maxdepth 1 -type f \
            -exec basename {} \; \
            | sort
    )

    # mark the active layout and record its index
    default_row=0
    MARKER="👉"
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$current_name" ]]; then
            options[i]="$MARKER ${options[i]}"
            default_row=$i
            break
        fi
    done

    # launch rofi with the annotated list and pre-selected row
    choice=$(printf '%s\n' "${options[@]}" \
        | rofi -i -dmenu \
               -config "$rofi_config" \
               -mesg "$msg" \
               -selected-row "$default_row"
    )

    [[ -z "$choice" ]] && { echo "No option selected. Exiting."; exit 0; }

    # remove annotation and apply
    choice=${choice#"$MARKER "}
    apply_layout "$choice"
}

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

main
