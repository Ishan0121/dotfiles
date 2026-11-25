#!/usr/bin/env bash

# Kitty Theme Picker using fzf
# Allows live previewing and applying themes from the kitty-themes repository.

THEME_DIR="$HOME/.config/kitty/kitty-themes/themes"
CONF_FILE="$HOME/.config/kitty/current-theme.conf"

if [[ ! -d "$THEME_DIR" ]]; then
    echo "Error: Kitty themes directory not found at $THEME_DIR"
    exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required. Please install it."
    exit 1
fi

# Read current theme to revert if user cancels
CURRENT_THEME=""
if [[ -f "$CONF_FILE" ]]; then
    CURRENT_THEME=$(cat "$CONF_FILE")
fi

export THEME_DIR
export CONF_FILE

# The preview command function
preview_theme() {
    local theme="$1"
    echo "include ./kitty-themes/themes/${theme}" > "$CONF_FILE"
    # Send SIGUSR1 to Kitty instances belonging to the user to reload the config live
    pkill -u "$USER" -USR1 kitty 2>/dev/null
    echo -e "\e[1;34mPreviewing Theme:\e[0m ${theme}\n"
    # Display the file content in the preview window
    cat "$THEME_DIR/$theme"
}
export -f preview_theme

# Execute fzf
selected_theme=$(ls -1 "$THEME_DIR" | grep '\.conf$' | fzf \
    --preview "bash -c 'preview_theme {}'" \
    --preview-window="right:60%:wrap" \
    --prompt="Kitty Theme > " \
    --header=$'Use Up/Down to preview.\nPress Enter to apply, ESC/Ctrl-C to cancel.\n')

if [[ -n "$selected_theme" ]]; then
    # Apply selected
    echo "include ./kitty-themes/themes/${selected_theme}" > "$CONF_FILE"
    pkill -u "$USER" -USR1 kitty 2>/dev/null
    echo -e "\e[1;32mSuccessfully applied theme: ${selected_theme%.conf}\e[0m"
else
    # Restore original upon cancellation
    if [[ -n "$CURRENT_THEME" ]]; then
        echo "$CURRENT_THEME" > "$CONF_FILE"
    else
        > "$CONF_FILE"
    fi
    pkill -u "$USER" -USR1 kitty 2>/dev/null
    echo "Canceled. Original theme restored."
fi
