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
    property bool showTray: true
    property bool showWorkspaces: true
    property bool showAudio: true
    property bool showBrightness: true
    property bool showBattery: true
    property bool showControlCenter: true
    property bool showCpu: true
    property bool showMemory: true
    property bool showTemperature: true
    property bool showNetwork: true
    property string temperatureUnit: "C"
    property string networkMode: "download"
    property int mediaPanelSize: 100
    property int clipboardPanelSize: 100
    property int launcherPanelSize: 100
    property int wallpaperPanelSize: 100
    property int themePanelSize: 100
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings"
    readonly property string defaultPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings.default"

    function save() {
        saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'barRadius=%s\\npillRadius=%s\\nnotchMode=%s\\nshowDate=%s\\nshowTime=%s\\nshowSeconds=%s\\nshowTray=%s\\nshowWorkspaces=%s\\nshowAudio=%s\\nshowBrightness=%s\\nshowBattery=%s\\nshowControlCenter=%s\\nshowCpu=%s\\nshowMemory=%s\\nshowTemperature=%s\\nshowNetwork=%s\\ntemperatureUnit=%s\\nnetworkMode=%s\\nmediaPanelSize=%s\\nclipboardPanelSize=%s\\nlauncherPanelSize=%s\\nwallpaperPanelSize=%s\\nthemePanelSize=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\" \"${11}\" \"${12}\" \"${13}\" \"${14}\" \"${15}\" \"${16}\" \"${17}\" \"${18}\" \"${19}\" \"${20}\" \"${21}\" \"${22}\" \"${23}\" \"${24}\" > \"$1\"", "pill-settings", path, barRadius, pillRadius, notchMode ? "true" : "false", showDate ? "true" : "false", showTime ? "true" : "false", showSeconds ? "true" : "false", showTray ? "true" : "false", showWorkspaces ? "true" : "false", showAudio ? "true" : "false", showBrightness ? "true" : "false", showBattery ? "true" : "false", showControlCenter ? "true" : "false", showCpu ? "true" : "false", showMemory ? "true" : "false", showTemperature ? "true" : "false", showNetwork ? "true" : "false", temperatureUnit, networkMode, mediaPanelSize, clipboardPanelSize, launcherPanelSize, wallpaperPanelSize, themePanelSize]
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
            let percentRoundness = false
            for (let i = 0; i < entries.length; i++) {
                const pair = entries[i].split("=")
                if (pair[0] === "roundnessUnit") percentRoundness = pair[1] === "percent"
                if (pair[0] === "barRadius") settings.barRadius = Math.max(0, Math.min(100, Number(pair[1]) || 15))
                if (pair[0] === "pillRadius") settings.pillRadius = Math.max(0, Math.min(100, Number(pair[1]) || 15))
                if (pair[0] === "notchMode") settings.notchMode = pair[1] === "true"
                if (pair[0] === "showDate") settings.showDate = pair[1] !== "false"
                if (pair[0] === "showTime") settings.showTime = pair[1] !== "false"
                if (pair[0] === "showSeconds") settings.showSeconds = pair[1] === "true"
                if (pair[0] === "showTray") settings.showTray = pair[1] !== "false"
                if (pair[0] === "showWorkspaces") settings.showWorkspaces = pair[1] !== "false"
                if (pair[0] === "showAudio") settings.showAudio = pair[1] !== "false"
                if (pair[0] === "showBrightness") settings.showBrightness = pair[1] !== "false"
                if (pair[0] === "showBattery") settings.showBattery = pair[1] !== "false"
                if (pair[0] === "showControlCenter") settings.showControlCenter = pair[1] !== "false"
                if (pair[0] === "showCpu") settings.showCpu = pair[1] !== "false"
                if (pair[0] === "showMemory") settings.showMemory = pair[1] !== "false"
                if (pair[0] === "showTemperature") settings.showTemperature = pair[1] !== "false"
                if (pair[0] === "showNetwork") settings.showNetwork = pair[1] !== "false"
                if (pair[0] === "temperatureUnit") settings.temperatureUnit = pair[1] === "F" ? "F" : "C"
                if (pair[0] === "networkMode") settings.networkMode = ["download", "upload", "both"].includes(pair[1]) ? pair[1] : "download"
                if (pair[0] === "mediaPanelSize") settings.mediaPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "clipboardPanelSize") settings.clipboardPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "launcherPanelSize") settings.launcherPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "wallpaperPanelSize") settings.wallpaperPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "themePanelSize") settings.themePanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
            }
            if (percentRoundness) {
                settings.barRadius = Math.round(settings.barRadius * 15 / 100)
                settings.pillRadius = Math.round(settings.pillRadius * 15 / 100)
            } else {
                settings.barRadius = Math.min(15, settings.barRadius)
                settings.pillRadius = Math.min(15, settings.pillRadius)
            }
        }
        onFileChanged: reload()
    }

    Process { id: saveProcess }
    Process { id: resetProcess; onExited: settingsFile.reload() }
}
