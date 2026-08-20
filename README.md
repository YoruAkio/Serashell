<div align="center">

# Serashell [WIP]

### Personal Linux dotfiles, centered around Quickshell

</div>

Serashell is my personal dotfiles collection for a Hyprland desktop. Its name comes from **Seraphim** and **Shell**, with the shell experience built mostly in [Quickshell](https://quickshell.org).

The main interface is a compact, theme-aware Quickshell shell with a top bar, Dynamic Island or macOS-style notch, media controls, launcher, clipboard history, wallpaper picker, control centre, and configurable settings.

> [!WARNING]
> Serashell is tuned for my own setup and is not yet a polished installable distribution. Expect rough edges while the UI, performance, and component system continue to evolve.

## Serashell

The active Quickshell configuration lives in `config/quickshell/`.

- **Dynamic Island / macOS Notch** — switchable presentation styles
- **Top bar** — system tray, workspaces, active window title, system status, AI usage, sound, brightness, battery, and clock
- **Control Centre** — Wi-Fi, Bluetooth, media, theme, screenshot, sound, and brightness
- **Panels** — calendar, system monitor, media details, frequently used app launcher, clipboard history, wallpaper picker, theme selection, and AI usage
- **App launcher** — fuzzy search with persistent most-used application ranking
- **AI usage** — provider usage, token, and estimated cost summaries in the bar and a dedicated panel
- **Keystroke Visualizer** — theme-aware full-width key display for typing and shortcuts, with animated keybind icons and optional left/right mouse-click indicators
- **Settings** — persistent appearance, bar, pill, panel sizing, date/time, system status, AI usage, and keystroke visualizer preferences
- **Themes** — wallpaper-rice light and dark themes shared by the shell and companion applications

### Keystroke Visualizer

Enable it from **Settings → Keystroke**. The overlay records typing and modifier combinations in Full mode, follows the active light/dark theme, and can optionally show left and right mouse clicks. Function keys and navigation keys are intentionally hidden to keep the display focused.

For local development, validate the shell in the foreground:

```sh
QT_QPA_PLATFORM=wayland qs
```

## Credits

- [Ricelin](https://github.com/Gakuseei/Ricelin) — inspired Serashell, the pill-as-panel launcher concept, and provided the basis for the wallpaper selector
- [OpenUsage](https://github.com/robinebers/openusage) — inspired the AI usage feature
- [Dynamic Island for Arch](https://github.com/patheonsceo/Dynamic-island-for-arch) — provided the basis for the macOS notch QML pill implementation

## Support

If you enjoy Serashell, consider [starring the repository](https://github.com/YoruAkio/Serashell). It helps others discover the project.

## License

Serashell is available under the [MIT License](LICENSE).
