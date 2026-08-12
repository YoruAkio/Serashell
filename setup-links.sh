#!/bin/bash

# @note script to create symbolic links from dotfiles to ~/.config/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

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
    "zathura"
)

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
    
    if [ -e "$TARGET" ]; then
        echo ""
        echo "📁 $folder already exists at $TARGET"
        
        if [ -L "$TARGET" ]; then
            echo "   (Currently a symlink)"
        else
            echo "   (Currently a directory/file)"
        fi
        
        read -p "   Remove and replace with new dotfiles? [y/N]: " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "   Removing existing $folder..."
            rm -rf "$TARGET"
        else
            echo "   Skipping $folder"
            continue
        fi
    fi
    
    echo "✓ Linking $folder"
    ln -s "$SOURCE" "$TARGET"
done

echo ""
echo "✅ Done! All symlinks created."
