#!/bin/bash

# @note script to install dotfiles into the user configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$SCRIPT_DIR/backup/backup-$(date '+%M:%H-%d:%m')"

if [ -e "$BACKUP_DIR" ]; then
    BACKUP_DIR="$BACKUP_DIR-$(date '+%s')"
fi

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

    if [ "$INSTALL_MODE" = "symlink" ] && [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/$name"
        echo "✓ Backed up $name to $BACKUP_DIR"
    fi
}

install_target() {
    local source="$1"
    local target="$2"

    if [ "$INSTALL_MODE" = "symlink" ]; then
        ln -sfn "$source" "$target"
    else
        cp -a "$source" "$target"
        if [ "$(basename "$source")" = "quickshell" ]; then
            rm -f "$target/pill-settings"
        fi
    fi
}

echo "Setting up dotfiles..."
echo "Source: $SCRIPT_DIR"
echo "Target: $CONFIG_DIR"
echo ""
read -p "Install mode: [s]ymlink or [c]opy? [s]: " -n 1 -r
echo

case "${REPLY:-s}" in
    s|S) INSTALL_MODE="symlink" ;;
    c|C) INSTALL_MODE="copy" ;;
    *)
        echo "Invalid install mode" >&2
        exit 1
        ;;
esac

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
    echo "✓ Installing $folder"
    install_target "$SOURCE" "$TARGET"
done

WALLPAPER_SOURCE="$SCRIPT_DIR/wallpaper"
WALLPAPER_TARGET="$HOME/.wall"

backup_target "$WALLPAPER_SOURCE" "$WALLPAPER_TARGET" "wallpaper"
echo "✓ Installing wallpapers"
install_target "$WALLPAPER_SOURCE" "$WALLPAPER_TARGET"

PILL_SETTINGS="$CONFIG_DIR/quickshell/pill-settings"
if [ ! -s "$PILL_SETTINGS" ]; then
    cp "$CONFIG_DIR/quickshell/pill-settings.default" "$PILL_SETTINGS"
    echo "✓ Initialized pill settings"
fi

echo ""
echo "✅ Done! Configuration installed with $INSTALL_MODE mode."
