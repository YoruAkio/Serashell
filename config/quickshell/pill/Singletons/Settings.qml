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
    property bool showWindowTitle: true
    property bool showAudio: true
    property bool showBrightness: true
    property bool showBattery: true
    property bool showControlCenter: true
    property bool showCpu: true
    property bool showMemory: true
    property bool showTemperature: true
    property bool showNetwork: true
    property bool showAiUsage: true
    property string aiUsageProviders: "claude,codex,cursor,antigravity,copilot,grok,opencode"
    property string aiUsageBarProviders: aiUsageProviders
    property string aiUsagePanelProviders: aiUsageProviders
    property int aiUsageRefreshMinutes: 5
    readonly property string activeAiUsageProviders: {
        const providers = []
        const enabled = (aiUsageBarProviders + "," + aiUsagePanelProviders).split(",")
        for (let i = 0; i < enabled.length; i++)
            if (enabled[i] && !providers.includes(enabled[i])) providers.push(enabled[i])
        return providers.join(",")
    }
    property string temperatureUnit: "C"
    property string networkMode: "download"
    property int mediaPanelSize: 100
    property int clipboardPanelSize: 100
    property int launcherPanelSize: 100
    property int wallpaperPanelSize: 100
    property int themePanelSize: 100
    property bool keystrokeEnabled: false
    property string keystrokePosition: "bottom-center"
    property int keystrokeSize: 100
    property int keystrokeFadeTime: 2
    property string keystrokeMode: "separate"
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings"
    readonly property string defaultPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/pill-settings.default"

    function save() {
        saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'barRadius=%s\\npillRadius=%s\\nnotchMode=%s\\nshowDate=%s\\nshowTime=%s\\nshowSeconds=%s\\nshowTray=%s\\nshowWorkspaces=%s\\nshowAudio=%s\\nshowBrightness=%s\\nshowBattery=%s\\nshowControlCenter=%s\\nshowCpu=%s\\nshowMemory=%s\\nshowTemperature=%s\\nshowNetwork=%s\\ntemperatureUnit=%s\\nnetworkMode=%s\\nmediaPanelSize=%s\\nclipboardPanelSize=%s\\nlauncherPanelSize=%s\\nwallpaperPanelSize=%s\\nthemePanelSize=%s\\nshowWindowTitle=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\" \"${11}\" \"${12}\" \"${13}\" \"${14}\" \"${15}\" \"${16}\" \"${17}\" \"${18}\" \"${19}\" \"${20}\" \"${21}\" \"${22}\" \"${23}\" \"${24}\" \"${25}\" > \"$1\"", "pill-settings", path, barRadius, pillRadius, notchMode ? "true" : "false", showDate ? "true" : "false", showTime ? "true" : "false", showSeconds ? "true" : "false", showTray ? "true" : "false", showWorkspaces ? "true" : "false", showAudio ? "true" : "false", showBrightness ? "true" : "false", showBattery ? "true" : "false", showControlCenter ? "true" : "false", showCpu ? "true" : "false", showMemory ? "true" : "false", showTemperature ? "true" : "false", showNetwork ? "true" : "false", temperatureUnit, networkMode, mediaPanelSize, clipboardPanelSize, launcherPanelSize, wallpaperPanelSize, themePanelSize, showWindowTitle ? "true" : "false"]
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
                if (pair[0] === "showWindowTitle") settings.showWindowTitle = pair[1] !== "false"
                if (pair[0] === "showAudio") settings.showAudio = pair[1] !== "false"
                if (pair[0] === "showBrightness") settings.showBrightness = pair[1] !== "false"
                if (pair[0] === "showBattery") settings.showBattery = pair[1] !== "false"
                if (pair[0] === "showControlCenter") settings.showControlCenter = pair[1] !== "false"
                if (pair[0] === "showCpu") settings.showCpu = pair[1] !== "false"
                if (pair[0] === "showMemory") settings.showMemory = pair[1] !== "false"
                if (pair[0] === "showTemperature") settings.showTemperature = pair[1] !== "false"
                if (pair[0] === "showNetwork") settings.showNetwork = pair[1] !== "false"
                if (pair[0] === "showAiUsage") settings.showAiUsage = pair[1] !== "false"
                if (pair[0] === "aiUsageProviders") settings.aiUsageProviders = pair[1]
                if (pair[0] === "aiUsageBarProviders") settings.aiUsageBarProviders = pair[1]
                if (pair[0] === "aiUsagePanelProviders") settings.aiUsagePanelProviders = pair[1]
                if (pair[0] === "aiUsageRefreshMinutes") settings.aiUsageRefreshMinutes = Math.max(1, Math.min(60, Number(pair[1]) || 5))
                if (pair[0] === "temperatureUnit") settings.temperatureUnit = pair[1] === "F" ? "F" : "C"
                if (pair[0] === "networkMode") settings.networkMode = ["download", "upload", "both"].includes(pair[1]) ? pair[1] : "download"
                if (pair[0] === "mediaPanelSize") settings.mediaPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "clipboardPanelSize") settings.clipboardPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "launcherPanelSize") settings.launcherPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "wallpaperPanelSize") settings.wallpaperPanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "themePanelSize") settings.themePanelSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "keystrokeEnabled") settings.keystrokeEnabled = pair[1] === "true"
                if (pair[0] === "keystrokePosition") { const valid = ["top-left","top-center","top-right","bottom-left","bottom-center","bottom-right"]; settings.keystrokePosition = valid.includes(pair[1]) ? pair[1] : "bottom-center" }
                if (pair[0] === "keystrokeSize") settings.keystrokeSize = Math.max(50, Math.min(200, Number(pair[1]) || 100))
                if (pair[0] === "keystrokeFadeTime") settings.keystrokeFadeTime = Math.max(1, Math.min(10, Number(pair[1]) || 2))
                if (pair[0] === "keystrokeMode") { const valid = ["full", "separate"]; settings.keystrokeMode = valid.includes(pair[1]) ? pair[1] : "separate" }
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

    Process {
        id: saveProcess
        onExited: {
            aiSaveProcess.command = ["sh", "-c", "tmp=$(mktemp); awk '!/^showAiUsage=|^aiUsageProviders=|^aiUsageBarProviders=|^aiUsagePanelProviders=|^aiUsageRefreshMinutes=/' \"$1\" > \"$tmp\" && printf 'showAiUsage=%s\\naiUsageProviders=%s\\naiUsageBarProviders=%s\\naiUsagePanelProviders=%s\\naiUsageRefreshMinutes=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" >> \"$tmp\" && mv \"$tmp\" \"$1\"", "ai-usage-settings", settings.path, settings.showAiUsage ? "true" : "false", settings.activeAiUsageProviders, settings.aiUsageBarProviders, settings.aiUsagePanelProviders, settings.aiUsageRefreshMinutes]
            aiSaveProcess.running = true
        }
    }
    Process { id: aiSaveProcess; onExited: { keystrokeSaveProcess.command = ["sh", "-c", "tmp=$(mktemp); awk '!/^keystrokeEnabled=|^keystrokePosition=|^keystrokeSize=|^keystrokeFadeTime=|^keystrokeMode=/' \"$1\" > \"$tmp\" && printf 'keystrokeEnabled=%s\\nkeystrokePosition=%s\\nkeystrokeSize=%s\\nkeystrokeFadeTime=%s\\nkeystrokeMode=%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" >> \"$tmp\" && mv \"$tmp\" \"$1\"", "keystroke-settings", settings.path, settings.keystrokeEnabled ? "true" : "false", settings.keystrokePosition, settings.keystrokeSize, settings.keystrokeFadeTime, settings.keystrokeMode]; keystrokeSaveProcess.running = true } }
    Process { id: keystrokeSaveProcess }
    Process { id: resetProcess; onExited: settingsFile.reload() }
}
