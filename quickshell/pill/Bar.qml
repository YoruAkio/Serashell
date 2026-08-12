import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import "Singletons"

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
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date()
            brightnessProcess.running = true
        }
    }

    component Pill: Rectangle {
        radius: height / 2
        color: Theme.surface
        height: root.pillHeight
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
                width: trayRow.width + 20

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 5

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            required property var modelData
                            width: 16
                            height: 16

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }
            }

            Pill {
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
        }

        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 8

            Pill {
                width: systemRow.width + 22

                Row {
                    id: systemRow
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
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
                        text: "󰃠 " + root.brightness
                        color: Theme.secondaryText
                        font.family: Theme.font
                        font.pixelSize: 12

                        Process {
                            id: brightnessChange
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
                }
            }

            Pill {
                visible: UPower.displayDevice !== null
                width: batteryText.width + 22

                Text {
                    id: batteryText
                    anchors.centerIn: parent
                    text: "󰁹 " + Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Pill {
                width: clockRow.width + 22

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "󰃭 " + Qt.formatDate(root.now, "dd:MM")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        text: "󰥔 " + Qt.formatTime(root.now, "HH:mm")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Pill {
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
