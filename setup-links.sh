#!/bin/bash

# @note script to create symbolic links from dotfiles to ~/.config/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$SCRIPT_DIR/backup/backup-$(date '+%M:%H-%d:%m')"

# @note list of folders to link
FOLDERS=(
    "btop"
    "dunst"
    "fastfetch"
    "fuzzel"
    "hypr"
    "kitty"
    "mako"
    "quickshell"
    "Kvantum"
    "scripts"
    "waybar"
)

backup_target() {
    local source="$1"
    local target="$2"
    local name="$3"

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/$name"
        echo "✓ Backed up $name to $BACKUP_DIR"
    fi
}

echo "Setting up dotfile symlinks..."
echo "Source: $SCRIPT_DIR"
echo "Target: $CONFIG_DIR"
echo ""

# @note create .config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

for folder in "${FOLDERS[@]}"; do
    SOURCE="$SCRIPT_DIR/$folder"
    TARGET="$CONFIG_DIR/$folder"
    
    if [ ! -d "$SOURCE" ]; then
        echo "⚠️  Warning: $SOURCE does not exist, skipping..."
        continue
    fi
    
    backup_target "$SOURCE" "$TARGET" "$folder"
    echo "✓ Linking $folder"
    ln -sfn "$SOURCE" "$TARGET"
done

WALLPAPER_SOURCE="$SCRIPT_DIR/wallpaper"
WALLPAPER_TARGET="$HOME/.wall"

backup_target "$WALLPAPER_SOURCE" "$WALLPAPER_TARGET" "wallpaper"
echo "✓ Linking wallpapers"
ln -sfn "$WALLPAPER_SOURCE" "$WALLPAPER_TARGET"

PILL_SETTINGS="$CONFIG_DIR/quickshell/pill-settings"
if [ ! -s "$PILL_SETTINGS" ]; then
    cp "$CONFIG_DIR/quickshell/pill-settings.default" "$PILL_SETTINGS"
    echo "✓ Initialized pill settings"
fi

echo ""
echo "✅ Done! All symlinks created."
