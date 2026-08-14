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
    "git"
    "curl"
    
    # application launchers
    "fuzzel"
    "rofi"
    
    # notifications
    "dunst"
    "quickshell"
    
    # system monitoring
    "fastfetch"
    
    # file management and browsers
    "thunar"
    "zen-browser-bin"
    
    # screenshot and color tools
    "hyprshot"
    "hyprpicker"
    "grim"
    "slurp"
    "wf-recorder"
    
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
    "qt6-svg"
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

# @note install oh my zsh without replacing the user's current zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM_DIR/plugins"

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
fi

echo ""
echo "✅ Dependencies installation complete!"
echo ""
echo "Additional setup steps:"
echo "  1. Enable power-profiles-daemon: sudo systemctl enable --now power-profiles-daemon"
echo "  2. Run ./setup-config.sh to install the configuration and wallpapers"
echo "  3. Create screenshots directory: mkdir -p ~/Pictures/screenshots"
