import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import "Singletons"
import "components" as Components

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    color: "transparent"

    property int pillHeight: 30
    property date now: new Date()
    property string brightness: "--"
    signal trayMenuRequested(var item, int anchorX)
    readonly property string activeWindowTitle: Hyprland.activeToplevel?.title || "Desktop"
    readonly property bool showMonitorStatus: Settings.showCpu || Settings.showMemory || Settings.showTemperature || Settings.showNetwork
    readonly property bool showSystemStatus: root.showMonitorStatus || Settings.showAiUsage

    Binding {
        target: SystemMonitor
        property: "barActive"
        value: root.showMonitorStatus
    }

    function networkSpeed(value) {
        return value >= 1024 ? (value / 1024).toFixed(1) + " MB/s" : Math.round(value) + " KB/s"
    }

    // @note find the tray item under a global x so the tray menu can switch targets
    function trayItemAt(globalX) {
        for (let i = 0; i < trayRow.children.length; i++) {
            const child = trayRow.children[i]
            const pos = child.mapToItem(null, 0, 0)
            if (globalX >= pos.x && globalX <= pos.x + child.width)
                return child
        }
        return null
    }

    function temperatureIcon(value) {
        if (value < 0) return ""
        return ["", "", "", "", ""][Math.min(4, Math.floor(value / 20))]
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Process {
        id: brightnessProcess
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = this.text.trim().split(",")
                root.brightness = fields.length > 3 ? fields[3] : "--"
            }
        }
    }

    Timer {
        interval: Settings.showSeconds ? 1000 : 10000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: brightnessProcess.running = true
    }

    component Pill: Rectangle {
        radius: Settings.barRadius
        color: Theme.surface
        height: root.pillHeight
    }

    component StatusMetric: Item {
        required property string icon
        required property string value
        implicitWidth: iconText.implicitWidth + 4 + valueText.implicitWidth
        implicitHeight: 20

        Text {
            id: iconText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            color: Theme.secondaryText
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            id: valueText
            anchors.left: iconText.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Theme.secondaryText
            font.family: Theme.font
            font.pixelSize: 12
        }
    }


    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Row {
            id: leftContent
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 8

            Pill {
                visible: Settings.showTray
                width: trayRow.width + 20

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 5

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            width: 16
                            height: 16

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        // @note open the themed tray menu below the icon; fall back to secondary activate
                                        if (modelData.hasMenu) {
                                            const pos = trayItem.mapToItem(null, trayItem.width / 2, 0)
                                            root.trayMenuRequested(modelData, Math.round(pos.x))
                                        } else {
                                            modelData.secondaryActivate()
                                        }
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Pill {
                visible: Settings.showWorkspaces
                width: workspaceRow.width + 12

                Row {
                    id: workspaceRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: 5

                        delegate: Rectangle {
                            id: workspaceButton
                            width: 20
                            height: 20
                            radius: height / 2
                            property int workspace: index + 1
                            property bool focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace
                            color: focused ? Theme.highlight : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.workspace
                                color: parent.focused ? Theme.background : Theme.secondaryText
                                font.family: Theme.font
                                font.pixelSize: 11
                                font.bold: parent.focused
                            }

                            Process {
                                id: workspaceProcess
                                command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + workspaceButton.workspace + " })"]
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: workspaceProcess.running = true
                            }
                        }
                    }
                }
            }

            Pill {
                visible: Settings.showWindowTitle
                width: Math.min(240, windowTitle.implicitWidth + 24)

                Text {
                    id: windowTitle
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: root.activeWindowTitle
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 8

            Pill {
                visible: root.showSystemStatus
                width: monitorRow.width + 22

                Row {
                    id: monitorRow
                    anchors.centerIn: parent
                    spacing: 10

                    StatusMetric {
                        visible: Settings.showCpu
                        icon: "󰻠"
                        value: SystemMonitor.cpu + "%"
                    }

                    StatusMetric {
                        visible: Settings.showMemory
                        icon: "󰍛"
                        value: SystemMonitor.memory + "%"
                    }

                    StatusMetric {
                        visible: Settings.showTemperature
                        icon: root.temperatureIcon(SystemMonitor.temperature)
                        value: {
                            if (SystemMonitor.temperature < 0)
                                return "--"
                            const value = Settings.temperatureUnit === "F" ? Math.round(SystemMonitor.temperature * 9 / 5 + 32) : SystemMonitor.temperature
                            return value + "°" + Settings.temperatureUnit
                        }
                    }

                    Row {
                        visible: Settings.showNetwork
                        spacing: 4
                        StatusMetric { visible: Settings.networkMode !== "upload"; icon: "󰇚"; value: root.networkSpeed(SystemMonitor.download) }
                        StatusMetric { visible: Settings.networkMode !== "download"; icon: "󰕒"; value: root.networkSpeed(SystemMonitor.upload) }
                    }

                    Components.AiUsage {
                        visible: Settings.showAiUsage
                    }
                }
            }

            Pill {
                visible: Settings.showAudio || Settings.showBrightness || (Settings.showBattery && UPower.displayDevice !== null)
                width: systemRow.width + 22

                Row {
                    id: systemRow
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        visible: Settings.showAudio
                        text: {
                            const sink = Pipewire.defaultAudioSink
                            if (!sink || !sink.audio || sink.audio.muted) return "󰝟"
                            const icon = sink.audio.volume > 0.66 ? "󰕾" : sink.audio.volume > 0.33 ? "󰖀" : "󰕿"
                            return icon + " " + Math.round(sink.audio.volume * 100) + "%"
                        }
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const sink = Pipewire.defaultAudioSink
                                if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
                            }
                            onWheel: wheel => {
                                const sink = Pipewire.defaultAudioSink
                                if (!sink || !sink.audio || wheel.angleDelta.y === 0) return
                                const change = wheel.angleDelta.y > 0 ? 0.03 : -0.03
                                sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + change))
                                wheel.accepted = true
                            }
                        }
                    }

                    Text {
                        visible: Settings.showBrightness
                        text: "󰃠 " + root.brightness
                        color: Theme.secondaryText
                        font.family: Theme.font
                        font.pixelSize: 12

                        Process {
                            id: brightnessChange
                            onExited: brightnessProcess.running = true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onWheel: wheel => {
                                if (wheel.angleDelta.y === 0) return
                                brightnessChange.command = ["brightnessctl", "set", wheel.angleDelta.y > 0 ? "+3%" : "3%-"]
                                brightnessChange.running = true
                                wheel.accepted = true
                            }
                        }
                    }

                    Text {
                        visible: Settings.showBattery && UPower.displayDevice !== null
                        text: "󰁹 " + Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }

            Pill {
                visible: Settings.showDate || Settings.showTime
                width: clockRow.width + 22

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        visible: Settings.showDate
                        text: "󰃭 " + Qt.formatDate(root.now, "dd:MM")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        visible: Settings.showTime
                        text: "󰥔 " + Qt.formatTime(root.now, Settings.showSeconds ? "HH:mm:ss" : "HH:mm")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Pill {
                visible: Settings.showControlCenter
                width: 30

                Text {
                    anchors.centerIn: parent
                    text: "󰍜"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: controlCenterProcess.running = true
                }

                Process {
                    id: controlCenterProcess
                    command: ["qs", "ipc", "call", "controlCenter", "toggle"]
                }
            }
        }
    }
}
