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

    property bool open: false
    function close() { open = false }

    IpcHandler {
        target: "pillSettings"
        function toggle(): void { root.open = !root.open }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 340
            height: 230
            radius: 18
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            scale: root.open ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }

            Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.top: parent.top; anchors.topMargin: 17; text: "󰒓  Pill settings"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 13; font.bold: true }

            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 12
                width: 28; height: 28; radius: height / 2; color: Local.Theme.highlight
                Text { anchors.centerIn: parent; text: "󰅖"; color: Local.Theme.background; font.family: Local.Theme.font; font.pixelSize: 14; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }

            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 18; anchors.topMargin: 52; spacing: 8

                Repeater {
                    model: ["Bar roundness", "Pill roundness"]
                    delegate: Item {
                        id: settingRow
                        required property int index
                        required property string modelData
                        width: parent.width; height: 42
                        readonly property int currentValue: index === 0 ? Local.Settings.barRadius : Local.Settings.pillRadius
                        function setValue(value) {
                            if (index === 0) Local.Settings.barRadius = value
                            else Local.Settings.pillRadius = value
                            Local.Settings.save()
                        }
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 11 }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                            Rectangle {
                                width: 26; height: 26; radius: height / 2; color: Local.Theme.surface
                                Text { anchors.centerIn: parent; text: "−"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
                                MouseArea { anchors.fill: parent; onClicked: settingRow.setValue(Math.max(0, settingRow.currentValue - 1)) }
                            }
                            Text { width: 24; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: settingRow.currentValue; color: Local.Theme.highlight; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                            Rectangle {
                                width: 26; height: 26; radius: height / 2; color: Local.Theme.surface
                                Text { anchors.centerIn: parent; text: "+"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
                                MouseArea { anchors.fill: parent; onClicked: settingRow.setValue(Math.min(30, settingRow.currentValue + 1)) }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 46; radius: 12
                    color: Local.Settings.notchMode ? Local.Theme.highlight : Local.Theme.surface
                    border.color: Local.Theme.accent; border.width: 1
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "󰘔  " + (Local.Settings.notchMode ? "macOS notch" : "Dynamic Island"); color: Local.Settings.notchMode ? Local.Theme.background : Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: { Local.Settings.notchMode = !Local.Settings.notchMode; Local.Settings.save() } }
                }
            }
        }
    }
}
