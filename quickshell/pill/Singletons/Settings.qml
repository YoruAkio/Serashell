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
    property bool showCpu: true
    property bool showMemory: true
    property bool showTemperature: true
    property bool showNetwork: true
    property string temperatureUnit: "C"
    property string networkMode: "download"
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings"
    readonly property string defaultPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings.default"

    function save() {
        saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'barRadius=%s\\npillRadius=%s\\nnotchMode=%s\\nshowDate=%s\\nshowTime=%s\\nshowSeconds=%s\\nshowCpu=%s\\nshowMemory=%s\\nshowTemperature=%s\\nshowNetwork=%s\\ntemperatureUnit=%s\\nnetworkMode=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\" \"${11}\" \"${12}\" \"${13}\" > \"$1\"", "pill-settings", path, barRadius, pillRadius, notchMode ? "true" : "false", showDate ? "true" : "false", showTime ? "true" : "false", showSeconds ? "true" : "false", showCpu ? "true" : "false", showMemory ? "true" : "false", showTemperature ? "true" : "false", showNetwork ? "true" : "false", temperatureUnit, networkMode]
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
                if (pair[0] === "showCpu") settings.showCpu = pair[1] !== "false"
                if (pair[0] === "showMemory") settings.showMemory = pair[1] !== "false"
                if (pair[0] === "showTemperature") settings.showTemperature = pair[1] !== "false"
                if (pair[0] === "showNetwork") settings.showNetwork = pair[1] !== "false"
                if (pair[0] === "temperatureUnit") settings.temperatureUnit = pair[1] === "F" ? "F" : "C"
                if (pair[0] === "networkMode") settings.networkMode = ["download", "upload", "both"].includes(pair[1]) ? pair[1] : "download"
            }
        }
        onFileChanged: reload()
    }

    Process { id: saveProcess }
    Process { id: resetProcess; onExited: settingsFile.reload() }
}
