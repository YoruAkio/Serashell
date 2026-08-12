#!/bin/bash

set -euo pipefail

wallpaper="${1:?Usage: set-wallpaper.sh /path/to/wallpaper}"
wall_dir="$HOME/.wall"
current_file="$wall_dir/.current"
target_outputs="eDP-1,HDMI-A-2"

if [ ! -f "$wallpaper" ]; then
    printf 'Wallpaper not found: %s\n' "$wallpaper" >&2
    exit 1
fi

resolution=$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)"' 2>/dev/null || true)
case "$resolution" in
    *x*)
        width=${resolution%x*}
        height=${resolution#*x}
        position="$((width / 2)),$((height / 2))"
        ;;
    *) position="0,0" ;;
esac

awww img "$wallpaper" \
    --outputs "$target_outputs" \
    --transition-type grow \
    --transition-duration 1.4 \
    --transition-fps 60 \
    --transition-pos "$position" \
    --transition-bezier .43,1.19,1,.4

printf '%s\n' "$(basename "$wallpaper")" > "$current_file"
notify-send -i "$wallpaper" "Wallpaper Changed" "$(basename "$wallpaper")" -t 3000
