import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons" as Local

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "power-menu"

    property bool open: false
    property int powerIndex: 0
    readonly property var powerActions: [
        { icon: "󰐥", label: "Shutdown", command: ["systemctl", "poweroff"] },
        { icon: "󰜉", label: "Reboot", command: ["systemctl", "reboot"] },
        { icon: "󰍃", label: "Logout", command: ["hyprctl", "dispatch", "exit"] },
        { icon: "󰌾", label: "Lock", command: ["hyprlock"] },
        { icon: "󰤄", label: "Sleep", command: ["systemctl", "suspend"] }
    ]
    signal dismissed()

    function toggle() {
        if (open)
            close()
        else {
            powerIndex = 0
            open = true
        }
    }

    function close() {
        open = false
        dismissed()
    }

    function runAction(action) {
        open = false
        actionProcess.command = action.command
        actionProcess.running = true
    }

    Process { id: actionProcess }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.powerIndex = Math.max(0, root.powerIndex - 1)
        Keys.onRightPressed: root.powerIndex = Math.min(root.powerActions.length - 1, root.powerIndex + 1)
        Keys.onReturnPressed: root.runAction(root.powerActions[root.powerIndex])
        Keys.onEnterPressed: root.runAction(root.powerActions[root.powerIndex])

        Rectangle {
            anchors.centerIn: parent
            width: 552
            height: 124
            radius: 18
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1

            MouseArea { anchors.fill: parent }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Repeater {
                    model: root.powerActions

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: 96
                        height: 100
                        radius: 12
                        color: Local.Theme.surface
                        border.color: index === root.powerIndex || tileMouse.containsMouse ? Local.Theme.highlight : "transparent"
                        border.width: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            text: modelData.icon
                            color: index === root.powerIndex ? Local.Theme.highlight : Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 26
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            text: modelData.label
                            color: index === root.powerIndex ? Local.Theme.text : Local.Theme.muted
                            font.family: Local.Theme.font
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.runAction(parent.modelData)
                        }
                    }
                }
            }
        }
    }
}
