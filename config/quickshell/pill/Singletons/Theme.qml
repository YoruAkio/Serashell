pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: theme

    property string mode: "dark"
    readonly property bool light: mode === "light"
    readonly property color background: light ? "#F1DBC2" : "#352B2D"
    readonly property color surface: light ? "#DFC8B1" : "#44373A"
    readonly property color accent: light ? "#CCB7A0" : "#4B3D43"
    readonly property color text: light ? "#352B2D" : "#F1DBC2"
    readonly property color secondaryText: light ? "#44373A" : "#DFC8B1"
    readonly property color muted: light ? "#625458" : "#AA9D8A"
    readonly property color subtleMuted: light ? "#857974" : "#908A7B"
    readonly property color highlight: light ? "#4B3D43" : "#CCB7A0"
    readonly property color danger: light ? "#B5443C" : "#E06C5F"
    readonly property color success: light ? "#5F7D4A" : "#86A96F"
    readonly property string font: "JetBrains Mono Nerd Font"

    FileView {
        id: modeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/theme-mode"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: theme.mode = text().trim() === "light" ? "light" : "dark"
        onFileChanged: reload()
    }
}
