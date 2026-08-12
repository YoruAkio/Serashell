pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: settings

    property int barRadius: 15
    property int pillRadius: 15
    property bool notchMode: false
    property bool showDate: true
    property bool showTime: true
    property bool showSeconds: false
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings"
    readonly property string defaultPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings.default"

    function save() {
        saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'barRadius=%s\\npillRadius=%s\\nnotchMode=%s\\nshowDate=%s\\nshowTime=%s\\nshowSeconds=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" > \"$1\"", "pill-settings", path, barRadius, pillRadius, notchMode ? "true" : "false", showDate ? "true" : "false", showTime ? "true" : "false", showSeconds ? "true" : "false"]
        saveProcess.running = true
    }

    function reset() {
        resetProcess.command = ["sh", "-c", "cp \"$2\" \"$1\"", "pill-settings-reset", path, defaultPath]
        resetProcess.running = true
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
                if (pair[0] === "showDate") settings.showDate = pair[1] !== "false"
                if (pair[0] === "showTime") settings.showTime = pair[1] !== "false"
                if (pair[0] === "showSeconds") settings.showSeconds = pair[1] === "true"
            }
        }
        onFileChanged: reload()
    }

    Process { id: saveProcess }
    Process { id: resetProcess; onExited: settingsFile.reload() }
}
