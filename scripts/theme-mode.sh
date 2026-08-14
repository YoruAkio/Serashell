#!/bin/bash

set -euo pipefail

MODE="${1:-}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

if [ -z "$MODE" ]; then
    MODE="$(printf 'dark\nlight\n' | fuzzel --dmenu --prompt='theme mode: ')"
fi

case "$MODE" in
    dark|light)
        mkdir -p "$CONFIG_DIR/dunst/dunstrc.d"
        ln -sfn "$CONFIG_DIR/dunst/themes/$MODE.conf" "$CONFIG_DIR/dunst/dunstrc.d/99-theme.conf"
        ln -sfn "$CONFIG_DIR/fuzzel/themes/$MODE.ini" "$CONFIG_DIR/fuzzel/theme.ini"
        ln -sfn "$CONFIG_DIR/kitty/themes/$MODE.conf" "$CONFIG_DIR/kitty/theme.conf"
        ln -sfn "$CONFIG_DIR/waybar/themes/$MODE.css" "$CONFIG_DIR/waybar/theme.css"
        ln -sfn "$CONFIG_DIR/mako/themes/$MODE.conf" "$CONFIG_DIR/mako/config"
        mkdir -p "$CONFIG_DIR/quickshell"
        printf '%s\n' "$MODE" > "$CONFIG_DIR/quickshell/theme-mode"
        tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true
        dunstctl reload >/dev/null 2>&1 || true
        makoctl reload >/dev/null 2>&1 || true
        pkill -SIGUSR2 waybar 2>/dev/null || true
        pkill -SIGUSR1 -x kitty 2>/dev/null || true
        notify-send "Theme changed" "$MODE mode"
        ;;
    "")
        exit 0
        ;;
    *)
        echo "Usage: $0 [dark|light]" >&2
        exit 1
        ;;
esac
