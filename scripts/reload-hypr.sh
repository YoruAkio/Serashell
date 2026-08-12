#!/bin/zsh

# @note this script must be running using supported terminal for wayland like kitty, and might not working on vscode terminal

# @note reload hyprland
hyprctl reload

# @note reload waybar
pkill waybar
# # Wait for Wayland to be ready and start waybar with inherited environment
nohup waybar > /tmp/waybar.log 2>&1 &