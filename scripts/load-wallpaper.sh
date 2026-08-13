#!/bin/bash

# @note load last wallpaper on hyprland startup

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
DEFAULT_FILE="$WALL_DIR/.current.default"
TARGET_OUTPUTS="eDP-1,HDMI-A-2"

# @note initialize user wallpaper state from the tracked default
if [ ! -s "$CURRENT_FILE" ]; then
    if [ ! -s "$DEFAULT_FILE" ]; then
        echo "No default wallpaper configured" >&2
        exit 1
    fi
    cp "$DEFAULT_FILE" "$CURRENT_FILE"
fi

# @note get screen resolution for transition position
get_screen_center() {
    local resolution=$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)"')

    if [ -z "$resolution" ]; then
        echo "center"
        return
    fi

    local width=$(echo $resolution | cut -d'x' -f1)
    local height=$(echo $resolution | cut -d'x' -f2)
    
    local center_x=$((width / 2))
    local center_y=$((height / 2))
    
    echo "${center_x},${center_y}"
}

# @note wait for swww daemon to be ready
wait_for_swww() {
    local max_attempts=10
    local attempt=0
    
    while ! pgrep -x awww-daemon > /dev/null && [ $attempt -lt $max_attempts ]; do
        sleep 0.5
        attempt=$((attempt + 1))
    done
}

# @note load wallpaper
load_wallpaper() {
    local saved_name=$(cat "$CURRENT_FILE")
    local wallpaper="$WALL_DIR/$saved_name"
    
    if [ ! -f "$wallpaper" ]; then
        echo "Wallpaper not found: $wallpaper" >&2
        exit 1
    fi
    
    local center=$(get_screen_center)
    
    awww img "$wallpaper" \
        --outputs "$TARGET_OUTPUTS" \
        --transition-type grow \
        --transition-duration 1.4 \
        --transition-fps 60 \
        --transition-pos "$center" \
        --transition-bezier .43,1.19,1,.4

}

wait_for_swww
load_wallpaper
