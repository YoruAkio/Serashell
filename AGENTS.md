# Serashell Development Guide

## Scope

This repository contains personal Linux dotfiles. The Quickshell configuration lives in `config/quickshell/` and provides the Serashell bar, island/notch, control centre, settings, selectors, and panels.

Keep changes scoped to the requested feature. Preserve unrelated user changes in the worktree.

## Quickshell structure

- `config/quickshell/shell.qml` is the entry point.
- `config/quickshell/pill/Bar.qml` is the top bar.
- `config/quickshell/pill/Pill.qml` is the center island/notch and on-demand selectors.
- `config/quickshell/pill/ControlCenter.qml` is the control centre.
- `config/quickshell/pill/SettingsWindow.qml` is the Serashell settings window.
- `config/quickshell/pill/Singletons/` contains persistent settings, theme values, and system-monitor state.
- `config/quickshell/pill/components/` contains reusable controls.

## Reusable controls

Use components from `config/quickshell/pill/components/` instead of creating one-off copies:

- `Toggle.qml` for every boolean setting and Wi-Fi/Bluetooth-style switch.
- `Slider.qml` for sound, brightness, and future continuous values.
- `Dropdown.qml` for selecting one value from multiple choices.
- `ValueStepper.qml` for bounded integer values such as roundness. Keep its visual order as `−  value  +`.

Add a reusable component here when a control will be used in more than one place. Import it with:

```qml
import "components" as Components
```

Then use `Components.Toggle`, `Components.Slider`, `Components.Dropdown`, or `Components.ValueStepper`.

## Performance and lifecycle

- Keep `Bar.qml` and the compact `Pill.qml` resident.
- Lazy-load heavyweight or infrequently used views with `Loader`, using `active` only while open.
- Selectors, launcher, clipboard history, calendar, system monitor, control centre, and settings must release their loaded QML tree after closing.
- Start polling processes only while their corresponding visible panel requires them. The system monitor must not poll while its panel is closed.
- Do not add background polling, image preloading, or permanent full-screen panels unless there is a clear UI need.

## Visual language

- Read all colors and font settings from `Singletons/Theme.qml`; do not hardcode a new palette in panels.
- Persist user-facing options through `Singletons/Settings.qml` and `config/quickshell/pill-settings`.
- Use `Theme.background` for the base layer, `Theme.surface` for raised content, `Theme.accent` for borders, and `Theme.highlight` for active selections.
- Keep dark/light support automatic by relying on the theme singleton.
- Match existing rounded rectangles, compact mono typography, and short easing animations.
- The Dynamic Island keeps its border; macOS-notch mode is borderless and uses `NotchShoulder.qml` on both animated edges.
- Ensure new notch content works in compact, hover-expanded, and panel states.

## Input and panels

- `Escape` closes the active selector or panel.
- Keyboard selectors support their documented arrow keys and Enter.
- Click-outside behavior closes panels without blocking the bar or application windows.
- Do not reserve screen space for overlays; use `ExclusionMode.Ignore` for full-screen panel windows.

## Settings

- The settings window is named **Serashell**.
- Keep settings pages in the sidebar; do not turn settings into an island-morph panel.
- Use a `Dropdown` for mutually exclusive styles such as Dynamic Island versus macOS Notch, not a toggle.
- Add settings pages and persistent properties only when they have a working consumer in the shell.

## Validation

Run Quickshell in the foreground after QML changes:

```sh
timeout 12s env QT_QPA_PLATFORM=wayland qs
```

Never start `qs` in the background. Fix new QML load errors before handing off. Existing unrelated desktop-entry or missing-icon warnings can be noted but do not block a change.

## Editing rules

- Use `rg` to locate code and avoid broad search commands.
- Do not delete or overwrite unrelated configuration.
- Keep comments functional, prefixed with `@note` or `@todo`, and written in lowercase.
