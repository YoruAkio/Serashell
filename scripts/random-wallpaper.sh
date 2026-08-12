#!/bin/bash

# @note random wallpaper selector for hyprland using swww

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
TARGET_OUTPUTS="eDP-1,HDMI-A-2"

# @note transition types available in swww
TRANSITIONS=("grow" "wave")

# @note get random wallpaper from ~/.wall excluding current one
get_random_wallpaper() {
    local current_wallpaper=""
    
    if [ -f "$CURRENT_FILE" ] && [ -s "$CURRENT_FILE" ]; then
        current_wallpaper=$(cat "$CURRENT_FILE")
    fi
    
    local all_wallpapers=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) ! -name ".*")
    local wallpaper_count=$(echo "$all_wallpapers" | wc -l)
    
    # @note if only one wallpaper exists, return it
    if [ "$wallpaper_count" -eq 1 ]; then
        echo "$all_wallpapers"
        return
    fi
    
    # @note filter out current wallpaper and pick random
    local new_wallpaper=$(echo "$all_wallpapers" | grep -v "$current_wallpaper" | shuf -n 1)
    
    # @note if all filtered out somehow, just pick any random one
    if [ -z "$new_wallpaper" ]; then
        new_wallpaper=$(echo "$all_wallpapers" | shuf -n 1)
    fi
    
    echo "$new_wallpaper"
}

# @note get random position within screen bounds
get_random_position() {
    local resolution=$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)"')

    if [ -z "$resolution" ]; then
        echo "center"
        return
    fi

    local width=$(echo $resolution | cut -d'x' -f1)
    local height=$(echo $resolution | cut -d'x' -f2)
    
    local random_x=$((RANDOM % width))
    local random_y=$((RANDOM % height))
    
    echo "${random_x},${random_y}"
}

# @note apply wallpaper with random transition
apply_wallpaper() {
    local wallpaper="$1"
    local transition="${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}"
    local duration=$(awk -v min=0.8 -v max=2.0 'BEGIN{srand(); print min+rand()*(max-min)}')
    local fps=$((50 + RANDOM % 31))
    local position=$(get_random_position)
    
    awww img "$wallpaper" \
        --outputs "$TARGET_OUTPUTS" \
        --transition-type "$transition" \
        --transition-duration "$duration" \
        --transition-fps "$fps" \
        --transition-pos "$position" \
        --transition-bezier .43,1.19,1,.4
    
    echo "$(basename "$wallpaper")" > "$CURRENT_FILE"
    notify-send -i "$wallpaper" "Wallpaper Changed" "$(basename "$wallpaper")" -t 3000
}

# @note main function
main() {
    if [ ! -d "$WALL_DIR" ]; then
        notify-send -i dialog-error "Error" "Wallpaper directory not found: $WALL_DIR" -t 3000
        exit 1
    fi
    
    local wallpaper="${1:-}"

    if [ -n "$wallpaper" ]; then
        case "$wallpaper" in
            "$WALL_DIR"/*) ;;
            *) wallpaper="$WALL_DIR/$wallpaper" ;;
        esac
    else
        wallpaper=$(get_random_wallpaper)
    fi

    if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
        notify-send -i dialog-error "Error" "No wallpapers found in $WALL_DIR" -t 3000
        exit 1
    fi
    
    apply_wallpaper "$wallpaper"
}

main
