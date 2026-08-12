pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: settings

    property int barRadius: 15
    property int pillRadius: 15
    property bool notchMode: false
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings"

    function save() {
        saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'barRadius=%s\\npillRadius=%s\\nnotchMode=%s\\n' \"$2\" \"$3\" \"$4\" > \"$1\"", "pill-settings", path, barRadius, pillRadius, notchMode ? "true" : "false"]
        saveProcess.running = true
    }

    FileView {
        id: settingsFile
        path: settings.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            const entries = text().trim().split("\n")
            for (let i = 0; i < entries.length; i++) {
                const pair = entries[i].split("=")
                if (pair[0] === "barRadius") settings.barRadius = Math.max(0, Number(pair[1]) || 15)
                if (pair[0] === "pillRadius") settings.pillRadius = Math.max(0, Number(pair[1]) || 15)
                if (pair[0] === "notchMode") settings.notchMode = pair[1] === "true"
            }
        }
        onFileChanged: reload()
    }

    Process { id: saveProcess }
}
