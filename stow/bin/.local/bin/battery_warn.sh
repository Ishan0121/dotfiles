#!/bin/bash
BAT_PATH="$(upower -e 2>/dev/null | grep -m1 battery || true)"

if [[ -z "$BAT_PATH" ]]; then
  echo "No battery found via upower (AC-powered device). Exiting."
  exit 0
fi

get_percent() {
  upower -i "$BAT_PATH" | awk -F': *' '/percentage/ {gsub(/%/,"",$2); print $2}'
}

get_state() {
  upower -i "$BAT_PATH" | awk -F': *' '/state/ {print $2}'
}

while true; do
  x="$(get_percent)"

  # Safety: if parsing fails, skip this cycle
  [[ "$x" =~ ^[0-9]+$ ]] || { sleep 5; continue; }


  if [[ "$x" -lt 30 ]]; then
    notify-send "Battery Alert!!" "Battery $x%"

    yad --width=400 --height=200 \
        --center \
        --fixed \
        --title="Power Alert!" \
        --no-buttons \
        --text-align=center \
        --timeout=100 --timeout-indicator=bottom \
        --text "Battery is $x\nIf it is not charging then please Charge it!!"

    while [[ "$x" -lt 30 ]]; do
      y="$(get_state)"
      x="$(get_percent)"
      [[ "$x" =~ ^[0-9]+$ ]] || { sleep 30; continue; }

      notify-send "Battery Alert!!" "Battery $x%"
      sleep 30

      if [[ "$y" == "charging" ]]; then
        break
      fi
    done

    sleep 300
  fi

  sleep 1
done
