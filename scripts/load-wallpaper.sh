#!/bin/bash

# @note load last wallpaper on hyprland startup

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
DEFAULT_WALLPAPER="$WALL_DIR/KasiaKarate.jpg"
TARGET_OUTPUTS="eDP-1,HDMI-A-2"

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
    local wallpaper=""
    
    if [ -f "$CURRENT_FILE" ] && [ -s "$CURRENT_FILE" ]; then
        local saved_name=$(cat "$CURRENT_FILE")
        wallpaper="$WALL_DIR/$saved_name"
        
        if [ ! -f "$wallpaper" ]; then
            wallpaper="$DEFAULT_WALLPAPER"
        fi
    else
        wallpaper="$DEFAULT_WALLPAPER"
    fi
    
    if [ ! -f "$wallpaper" ]; then
        echo "No wallpaper found"
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
