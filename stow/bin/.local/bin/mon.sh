#!/bin/env bash

hyprctl monitors > /tmp/monitor

var=$(sed -n '1{p;q}' /tmp/monitor | awk '{ print $2 }')

var1=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $1 }')

var2=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $3 }')

var3=$(cat  /tmp/monitor | grep 'scale' | awk '{ print $2 }')

var4="$var, $var1, $var2, $var3"

var5=${var1%%x*}

sed -i "/output   =/c\    output   = \"$var\"," "$HOME/.config/hypr/hyprland.lua"

sed -i "/mode     =/c\    mode     = \"$var1\"," "$HOME/.config/hypr/hyprland.lua"

sed -i "/position =/c\    position = \"$var2\"," "$HOME/.config/hypr/hyprland.lua"

sed -i "/scale    =/c\    scale    = $var3," "$HOME/.config/hypr/hyprland.lua"

sed -i "s/USER/$USER/" .config/waybar/style.css

sed -i 's|hl.exec_cmd(".local/bin/mon.sh")|-- hl.exec_cmd(".local/bin/mon.sh")|' "$HOME/.config/hypr/hyprland.lua"

sed -i 's|hl.exec_cmd("garuda-welcome")|-- hl.exec_cmd("garuda-welcome")|' "$HOME/.config/hypr/hyprland.lua"
