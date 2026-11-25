#!/usr/bin/env bash
# Configure Kitty's font size once from monitor pixel density and Hyprland scale.

set -euo pipefail


# Formula:
#
#   physical diagonal (inches)
#       = sqrt(width_mm² + height_mm²) / 25.4
#
#   PPI
#       = sqrt(width_px² + height_px²) / diagonal_inches
#
#   effective PPI
#       = PPI / Hyprland scale
#
#   Kitty font size
#       = 16 × effective_PPI / 147.3945

REFERENCE_FONT_SIZE=16.0
REFERENCE_EFFECTIVE_PPI=147.3945

# Safety limits for automatically selected sizes.
MIN_FONT_SIZE=9.0
MAX_FONT_SIZE=24.0

# Used when the monitor has missing or invalid EDID dimensions.
FALLBACK_FONT_SIZE=14.0

force=false
dry_run=false
requested_monitor=""

usage() {
    cat <<'USAGE'
Usage: kitty-font-autosize.sh [OPTIONS]

Options:
  --force
      Recalculate even if the first-run marker already exists.

  --dry-run
      Show the detected values and calculated font size without changing files.

  --monitor NAME
      Use a specific Hyprland monitor instead of the focused monitor.

  -h, --help
      Show this help message.

Examples:
  kitty-font-autosize.sh --dry-run
  kitty-font-autosize.sh --force
  kitty-font-autosize.sh --force --monitor DP-1
USAGE
}

while (($# > 0)); do
    case "$1" in
        --force)
            force=true
            ;;

        --dry-run)
            dry_run=true
            ;;

        --monitor)
            if (($# < 2)); then
                echo "Error: --monitor requires a monitor name." >&2
                exit 2
            fi

            requested_monitor=$2
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac

    shift
done

# Respect Kitty and XDG configuration locations.
config_root="${KITTY_CONFIG_DIRECTORY:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
kitty_config="$config_root/kitty.conf"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/garuda-hyprland"
done_file="$state_dir/kitty-font-autosize.done"

# Normal startup should run this only once.
# Dry-run is still allowed even after the marker exists.
if [[ -e "$done_file" &&
      "$force" == false &&
      "$dry_run" == false ]]; then

    exit 0
fi

for command in hyprctl jq awk; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: required command not found: $command" >&2
        exit 1
    fi
done

# Hyprland may still be initializing during the first login.
monitor_json=""

for _ in {1..20}; do
    monitor_json=$(LC_ALL=C hyprctl -j monitors 2>/dev/null || true)

    if jq -e \
        'type == "array" and length > 0' \
        >/dev/null 2>&1 <<< "$monitor_json"; then

        break
    fi

    monitor_json=""
    sleep 0.25
done

if [[ -z "$monitor_json" ]]; then
    echo "Error: could not read active monitor information from Hyprland." >&2
    exit 1
fi

# Selection order:
#
# 1. Monitor explicitly provided through --monitor.
# 2. Currently focused monitor.
# 3. First active monitor.
monitor_data=$(
    jq -r --arg requested "$requested_monitor" '
        def selected_monitor:
            if $requested != "" then
                ([.[] | select(.name == $requested)][0])
            else
                (([.[] | select(.focused == true)][0]) // .[0])
            end;

        selected_monitor
        | if . == null then
              empty
          else
              [
                  (.name // "unknown"),
                  (.width // 0),
                  (.height // 0),
                  (.physicalWidth // 0),
                  (.physicalHeight // 0),
                  (.scale // 1)
              ]
              | @tsv
          end
    ' <<< "$monitor_json"
)

if [[ -z "$monitor_data" ]]; then
    if [[ -n "$requested_monitor" ]]; then
        echo "Error: Hyprland monitor not found: $requested_monitor" >&2
    else
        echo "Error: no usable Hyprland monitor was found." >&2
    fi

    exit 1
fi

IFS=$'\t' read -r \
    monitor_name \
    width_px \
    height_px \
    width_mm \
    height_mm \
    scale <<< "$monitor_data"

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 > 0))
}

is_positive_number() {
    [[ "$1" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] &&
        awk -v value="$1" 'BEGIN { exit !(value > 0) }'
}

if ! is_positive_integer "$width_px" ||
   ! is_positive_integer "$height_px"; then

    echo "Error: monitor '$monitor_name' reported an invalid resolution." >&2
    exit 1
fi

if ! is_positive_number "$scale"; then
    echo "Warning: monitor '$monitor_name' reported an invalid scale; using 1.0." >&2
    scale=1.0
fi

calculation=$(
    awk \
        -v width_px="$width_px" \
        -v height_px="$height_px" \
        -v width_mm="$width_mm" \
        -v height_mm="$height_mm" \
        -v scale="$scale" \
        -v reference_font="$REFERENCE_FONT_SIZE" \
        -v reference_effective_ppi="$REFERENCE_EFFECTIVE_PPI" \
        -v min_font="$MIN_FONT_SIZE" \
        -v max_font="$MAX_FONT_SIZE" \
        -v fallback_font="$FALLBACK_FONT_SIZE" '
        function round_half(value) {
            return int(value * 2 + 0.5) / 2
        }

        BEGIN {
            valid_physical_size = (width_mm ~ /^[0-9]+([.][0-9]+)?$/ && height_mm ~ /^[0-9]+([.][0-9]+)?$/ && width_mm >= 50 && width_mm <= 3000 && height_mm >= 30 && height_mm <= 3000)

            if (!valid_physical_size) {
                printf "fallback\t%.1f\t0.0\t0.0\t0.0\n", fallback_font
                exit
            }

            diagonal_pixels = sqrt(width_px^2 + height_px^2)
            diagonal_inches = sqrt(width_mm^2 + height_mm^2) / 25.4
            ppi = diagonal_pixels / diagonal_inches
            effective_ppi = ppi / scale

            if (ppi < 40 || ppi > 500 || effective_ppi <= 0) {
                printf "fallback\t%.1f\t%.1f\t%.1f\t%.1f\n", fallback_font, diagonal_inches, ppi, effective_ppi
                exit
            }

            font_size = reference_font * effective_ppi / reference_effective_ppi
            font_size = round_half(font_size)

            if (font_size < min_font)
                font_size = min_font

            if (font_size > max_font)
                font_size = max_font

            printf "physical\t%.1f\t%.1f\t%.1f\t%.1f\n", font_size, diagonal_inches, ppi, effective_ppi
        }
    '
)

IFS=$'\t' read -r \
    calculation_mode \
    font_size \
    diagonal_inches \
    ppi \
    effective_ppi <<< "$calculation"

printf 'Kitty font auto-size result:\n'
printf '  Monitor       : %s\n' "$monitor_name"
printf '  Resolution    : %sx%s\n' "$width_px" "$height_px"
printf '  Physical size : %sx%s mm\n' "$width_mm" "$height_mm"
printf '  Hyprland scale: %s\n' "$scale"

if [[ "$calculation_mode" == "physical" ]]; then
    printf '  Diagonal      : %s inches\n' "$diagonal_inches"
    printf '  PPI           : %s\n' "$ppi"
    printf '  Effective PPI : %s\n' "$effective_ppi"
else
    printf '  Detection     : invalid/missing physical dimensions\n'
    printf '  Fallback      : used\n'
fi

printf '  Kitty font    : %s\n' "$font_size"

if [[ "$dry_run" == true ]]; then
    exit 0
fi

mkdir -p "$config_root" "$state_dir"
touch "$kitty_config"

# Replace existing active font_size declarations.
# If none exists, append one.
if grep -Eq \
    '^[[:space:]]*font_size[[:space:]]+' \
    "$kitty_config"; then

    sed -i -E \
        "s|^([[:space:]]*)font_size[[:space:]]+.*|\1font_size ${font_size}|" \
        "$kitty_config"
else
    printf \
        '\n# Selected automatically from monitor size, resolution, and scale.\nfont_size %s\n' \
        "$font_size" >> "$kitty_config"
fi

# Create the completion marker only after kitty.conf was updated.
cat > "$done_file" <<EOF_STATE
monitor=$monitor_name
resolution=${width_px}x${height_px}
physical_size_mm=${width_mm}x${height_mm}
scale=$scale
calculation=$calculation_mode
diagonal_inches=$diagonal_inches
ppi=$ppi
effective_ppi=$effective_ppi
font_size=$font_size
EOF_STATE

# Kitty normally detects configuration changes automatically.
# SIGUSR1 explicitly requests a reload for currently running instances.
pkill -USR1 -x kitty 2>/dev/null || true
