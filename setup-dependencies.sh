#!/bin/bash

# @note script to install all dependencies for akio-dotfiles on Arch Linux using yay

echo "Installing dotfiles dependencies for Arch Linux..."
echo ""

# @note core window manager and display
PACKAGES=(
    # window manager
    "hyprland"
    "hyprlock"
    "hypridle"
    "xdg-desktop-portal-hyprland"
    
    # terminal and shell
    "kitty"
    "zsh"
    
    # application launchers
    "fuzzel"
    "rofi"
    
    # status bar and notifications
    "waybar"
    "dunst"
    "quickshell"
    
    # system monitoring
    "btop"
    "fastfetch"
    
    # file management and browsers
    "thunar"
    "zen-browser-bin"
    
    # screenshot and color tools
    "hyprshot"
    "hyprpicker"
    "grim"
    
    # clipboard management
    "cliphist"
    "wl-clipboard"
    
    # wallpaper
    "awww"
    
    # audio and media control
    "pipewire"
    "wireplumber"
    "pavucontrol-qt"
    "playerctl"
    
    # brightness control
    "brightnessctl"
    
    # network and bluetooth
    "network-manager-applet"
    "blueman"
    
    # power management
    "power-profiles-daemon"
    
    # system utilities
    "systemd"
    "lm_sensors"
    "jq"
    "polkit"
    
    # pdf viewer
    "zathura"
    "zathura-pdf-mupdf"
    
    # fonts
    "ttf-jetbrains-mono-nerd"
    
    # icon themes
    "adwaita-icon-theme"
    "gnome-icon-theme"
    
    # qt theming
    "kvantum"
    "qt5ct"
    "qt6ct"
)

echo "The following packages will be installed:"
echo ""
for pkg in "${PACKAGES[@]}"; do
    echo "  - $pkg"
done
echo ""

read -p "Continue with installation? [y/N]: " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Installing packages with yay..."
echo ""

yay -S --needed "${PACKAGES[@]}"

echo ""
echo "✅ Dependencies installation complete!"
echo ""
echo "Additional setup steps:"
echo "  1. Enable power-profiles-daemon: sudo systemctl enable --now power-profiles-daemon"
echo "  2. Add wallpaper to ~/Pictures/KasiaKarate.jpg"
echo "  3. Create screenshots directory: mkdir -p ~/Pictures/screenshots"
echo "  4. Run ./setup-links.sh to create config symlinks"
