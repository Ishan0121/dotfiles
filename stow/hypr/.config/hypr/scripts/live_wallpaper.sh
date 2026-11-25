#!/bin/bash
DIR="$HOME/Pictures/live wallpapers"
killall mpvpaper
mpvpaper -p -a FULL -o 'loop no-audio' '*' "$(find "$DIR" -type f \( -iname \*.mp4 -o -iname \*.webm -o -iname \*.gif -o -iname \*.mkv \) | shuf -n 1)" &
