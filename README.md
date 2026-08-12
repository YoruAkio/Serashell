<div align="center">

# Serashell

### Personal Linux dotfiles, centered around Quickshell

> [!WARNING]
> **Work in progress.** Configurations, layout, and features may change frequently.

</div>

Serashell is my personal dotfiles collection for a Hyprland desktop. Its name comes from **Seraphim** and **Shell**, with the shell experience built mostly in [Quickshell](https://quickshell.org).

The main interface is a compact, theme-aware Quickshell shell with a top bar, Dynamic Island or macOS-style notch, media controls, launcher, clipboard history, wallpaper picker, control centre, and configurable settings.

## Included configuration

- `quickshell/` — Serashell bar, island/notch, panels, controls, and settings
- `hypr/` — Hyprland configuration and keybinds
- `kitty/` — terminal theme configuration
- `dunst/` and `mako/` — notification daemons and themes
- `fuzzel/` — launcher themes
- `waybar/` — Waybar configuration and themes
- `btop/`, `fastfetch/`, `Kvantum/` — terminal/system/Qt styling
- `scripts/` and `wallpaper/` — helper scripts and wallpaper assets

## Serashell

The active Quickshell configuration lives in `quickshell/`.

- **Dynamic Island / macOS Notch** — switchable presentation styles
- **Control Centre** — Wi-Fi, Bluetooth, media, theme, screenshot, sound, and brightness
- **Panels** — calendar, system monitor, media details, app launcher, clipboard history, wallpaper picker, and theme selection
- **Settings** — persistent appearance and date/time preferences
- **Themes** — wallpaper-rice light and dark themes shared by the shell and companion applications

For local development, validate the shell in the foreground:

```sh
QT_QPA_PLATFORM=wayland qs
```

## Status

Serashell is tuned for my own setup and is not yet a polished installable distribution. Expect rough edges while the UI, performance, and component system continue to evolve.
