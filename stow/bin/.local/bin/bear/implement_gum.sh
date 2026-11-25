#!/bin/env bash
cat <<"EOF"
  ____       _   _                  _                 _
 / ___|     | | | |_   _ _ __  _ __| | __ _ _ __   __| |
| |  _ _____| |_| | | | | '_ \| '__| |/ _` | '_ \ / _` |
| |_| |_____|  _  | |_| | |_) | |  | | (_| | | | | (_| |
 \____|     |_| |_|\__, | .__/|_|  |_|\__,_|_| |_|\__,_|
                   |___/|_|
EOF
if [[ $1 = "enable" ]]
then
echo
echo
echo "This script will implement G-Hyprland which is an optional feature"
echo "provided by garuda linux hyprland edition"
echo "Through this implementation users would be able to change some "
echo "visual stuffs like window gaps, waybar themes, wallpapers(animated,"
echo "slideshow,session static), etc..etc"
echo
read -rp "Do you want to implement it ? [y/n] " opt1
if [[ $opt1 == "y" || $opt1 == "Y" ]]
then
clear
    cat <<"EOF"
             _________  ________   ___   ___   ________  ___   __    _______      __  __   ______   __  __   ______
            /________/\/_______/\ /___/\/__/\ /_______/\/__/\ /__/\ /______/\    /_/\/_/\ /_____/\ /_/\/_/\ /_____/\
            \__.::.__\/\::: _  \ \\::.\ \\ \ \\__.::._\/\::\_\\  \ \\::::__\/__  \ \ \ \ \\:::_ \ \\:\ \:\ \\:::_ \ \
               \::\ \   \::(_)  \ \\:: \/_) \ \  \::\ \  \:. `-\  \ \\:\ /____/\  \:\_\ \ \\:\ \ \ \\:\ \:\ \\:(_) ) )_
                \::\ \   \:: __  \ \\:. __  ( (  _\::\ \__\:. _    \ \\:\\_  _\/   \::::_\/ \:\ \ \ \\:\ \:\ \\: __ `\ \
                 \::\ \   \:.\ \  \ \\: \ )  \ \/__\::\__/\\. \`-\  \ \\:\_\ \ \     \::\ \  \:\_\ \ \\:\_\:\ \\ \ `\ \ \
                  \__\/    \__\/\__\/ \__\/\__\/\________\/ \__\/ \__\/ \_____\/      \__\/   \_____\/ \_____\/ \_\/ \_\/
 ___   ___   __  __   ______   ______       _________  ______       ___   ___   __  __   ______   ______   ______        __    __    __
/__/\ /__/\ /_/\/_/\ /_____/\ /_____/\     /________/\/_____/\     /__/\ /__/\ /_/\/_/\ /_____/\ /_____/\ /_____/\      /__/\ /__/\ /__/\
\::\ \\  \ \\ \ \ \ \\:::_ \ \\::::_\/_    \__.::.__\/\:::_ \ \    \::\ \\  \ \\ \ \ \ \\:::_ \ \\::::_\/_\:::_ \ \     \.:\ \\.:\ \\.:\ \
 \::\/_\ .\ \\:\_\ \ \\:(_) \ \\:\/___/\      \::\ \   \:\ \ \ \    \::\/_\ .\ \\:\_\ \ \\:(_) \ \\:\/___/\\:(_) ) )_    \::\ \\::\ \\::\ \
  \:: ___::\ \\::::_\/ \: ___\/ \::___\/_      \::\ \   \:\ \ \ \    \:: ___::\ \\::::_\/ \: ___\/ \::___\/_\: __ `\ \    \__\/_\__\/_\__\/_
   \: \ \\::\ \ \::\ \  \ \ \    \:\____/\      \::\ \   \:\_\ \ \    \: \ \\::\ \ \::\ \  \ \ \    \:\____/\\ \ `\ \ \     /__/\ /__/\ /__/\
    \__\/ \::\/  \__\/   \_\/     \_____\/       \__\/    \_____\/     \__\/ \::\/  \__\/   \_\/     \_____\/ \_\/ \_\/     \__\/ \__\/ \__\/

EOF
    echo "Thanks for giving a shot!!"
    if [[ ! -d "$HOME/.config/gum_implementation/" ]]
    then
        mkdir "$HOME/.config/gum_implementation/"
    fi
    echo "Insatalling required packages.. "
    sudo pacman -Sy gum wpaperd awww wlsunset nwg-dock-hyprland
    echo "backing up your old folders"
    mkdir "$HOME/.config/gum_implementation/backups/"
    cp -r "$HOME/.config/hypr/"* "$HOME/.config/gum_implementation/backups/"
    echo "copying files..."
    cp -r "/etc/skel/.config/gum_implementation/gum_files/"* "$HOME/.config/hypr/"

    echo "Adjusting monitor..."
    hyprctl monitors > /tmp/monitor
    var=$(sed -n '1{p;q}' /tmp/monitor | awk '{ print $2 }')
    var1=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $1 }')
    var2=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $3 }')
    var3=$(cat  /tmp/monitor | grep 'scale' | awk '{ print $2 }')
    var4="$var, $var1, $var2, $var3"
    var5=${var1%%x*}
    sed -i "/output   =/c\    output   = \"$var\"," "$HOME/.config/hypr/settings/monitor.lua"
    sed -i "/mode     =/c\    mode     = \"$var1\"," "$HOME/.config/hypr/settings/monitor.lua"
    sed -i "/position =/c\    position = \"$var2\"," "$HOME/.config/hypr/settings/monitor.lua"
    sed -i "/scale    =/c\    scale    = $var3," "$HOME/.config/hypr/settings/monitor.lua"
    sed -i "s/USER/$USER/" .config/waybar/style.css
    sed -i 's|hl.exec_cmd(".local/bin/mon.sh")|-- hl.exec_cmd(".local/bin/mon.sh")|' "$HOME/.config/hypr/hyprland.lua"
    sed -i 's|hl.exec_cmd("garuda-welcome")|-- hl.exec_cmd("garuda-welcome")|' "$HOME/.config/hypr/hyprland.lua"

    echo "Setting keyboard layout"

    target="$HOME/.config/hypr/settings/manual_settings.lua"

    if [[ ! -f "$target" ]]; then
        echo "Error: keyboard configuration file not found: $target" >&2
        exit 1
    fi

    keyboard_status=$(LC_ALL=C localectl --no-pager status 2>/dev/null || true)

    get_keyboard_field() {
        local key=$1

        awk -v key="$key" '
            $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
                sub("^[[:space:]]*" key ":[[:space:]]*", "")
                print
                exit
            }
        ' <<< "$keyboard_status"
    }

    is_missing_keyboard_value() {
        [[ -z "${1:-}" ||
           "$1" == "(unset)" ||
           "$1" == "n/a" ||
           "$1" == "-" ]]
    }

    layout=$(get_keyboard_field "X11 Layout")
    model=$(get_keyboard_field "X11 Model")
    variant=$(get_keyboard_field "X11 Variant")
    options=$(get_keyboard_field "X11 Options")

    # If no XKB layout is configured, convert the virtual-console
    # keymap using systemd's keyboard mapping table.
    if is_missing_keyboard_value "$layout"; then
        vc_keymap=$(get_keyboard_field "VC Keymap")

        if ! is_missing_keyboard_value "$vc_keymap" &&
           [[ -r /usr/share/systemd/kbd-model-map ]]; then

            map_line=$(
                awk -v key="$vc_keymap" '
                    $1 == key {
                        print
                        exit
                    }
                ' /usr/share/systemd/kbd-model-map
            )

            if [[ -n "$map_line" ]]; then
                read -r _ layout model variant options _ <<< "$map_line"
            fi
        fi
    fi

    # Final safe fallback.
    if is_missing_keyboard_value "$layout"; then
        echo "Warning: no usable XKB keyboard layout was detected; using 'us'." >&2
        layout="us"
        model=""
        variant=""
        options=""
    else
        is_missing_keyboard_value "$model"   && model=""
        is_missing_keyboard_value "$variant" && variant=""
        is_missing_keyboard_value "$options" && options=""
    fi

    # Confirm that the expected Lua settings still exist.
    for key in kb_layout kb_variant kb_model kb_options; do
        if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$target"; then
            echo "Error: could not find '$key' in $target" >&2
            exit 1
        fi
    done

    sed -i -E \
        -e "s|^([[:space:]]*)kb_layout[[:space:]]*=.*|\1kb_layout  = \"$layout\",|" \
        -e "s|^([[:space:]]*)kb_variant[[:space:]]*=.*|\1kb_variant = \"$variant\",|" \
        -e "s|^([[:space:]]*)kb_model[[:space:]]*=.*|\1kb_model   = \"$model\",|" \
        -e "s|^([[:space:]]*)kb_options[[:space:]]*=.*|\1kb_options = \"$options\",|" \
        "$target"

    echo "Keyboard configuration selected:"
    printf '  Layout : %s\n' "$layout"
    printf '  Variant: %s\n' "${variant:-<none>}"
    printf '  Model  : %s\n' "${model:-<none>}"
    printf '  Options: %s\n' "${options:-<none>}"

    echo "All done, you can run the script through 'Mod+s' shortcut key"
    echo "you can go back to your older config whenever you like "
    echo "through same keybindings whenever you want ;-) "
    read -rp "please restart you PC" opt2
else
    echo "User selected not to implement"
    sleep 3
fi
elif [[ $1 = "disable" ]]
then
    echo "Are you sure you want to leave G-Hyprland script ?"
    echo "If you did any changes to your G-Hyprland scripts"
    echo "then it won't be backed up !!"
    read -rp "Remove G-Hyprland implementation ? [y/n] : " opt3
    if [[ $opt3 == "y" || $opt3 == "Y" ]]
    then
    echo "backing up..."
    cp -r "$HOME/.config/gum_implementation/backups/"*  "$HOME/.config/hypr/"
    echo "cleaning up"
    rm -r "$HOME/.config/hypr/brain/" "$HOME/.config/hypr/settings" "$HOME/.config/gum_implementation/backups/"
    read -rp "All done, please restart your machine "
    else
        echo "user selected not to backup "
        sleep 3
    fi
fi
