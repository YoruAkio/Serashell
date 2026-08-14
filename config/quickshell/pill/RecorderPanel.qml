import QtQuick
import "Singletons" as Local

Item {
    id: panel

    property var pill
    property real morphCloseness: 0

    anchors.fill: parent
    visible: pill.recorderOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Text {
            text: "Screen recording"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            visible: panel.pill.recordActions.length === 0
            text: "Loading outputs…"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 10
        }

        Repeater {
            model: panel.pill.recordActions

            delegate: Rectangle {
                required property int index
                required property var modelData
                width: parent.width
                height: 38
                radius: 10
                color: index === panel.pill.recordIndex || actionMouse.containsMouse ? Local.Theme.accent : Local.Theme.surface

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.mode === "stop" ? "󰓛" : "󰍹"
                    color: Local.Theme.highlight
                    font.family: Local.Theme.font
                    font.pixelSize: 15
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: modelData.label
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text {
                        text: modelData.description
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 8
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.pill.runRecorderAction(parent.modelData)
                }
            }
        }
    }
}
