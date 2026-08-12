import QtQuick
import "Singletons" as Local

Item {
    id: selector

    property var pill
    property real morphCloseness: 0

    anchors.fill: parent
    visible: pill.themePickerOpen && !pill.wallpaperPickerOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 5

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Theme"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 42
        spacing: 10

        Repeater {
            model: selector.pill.themeModes

            delegate: Rectangle {
                required property int index
                required property string modelData
                readonly property bool selected: index === selector.pill.themeIndex
                width: 94
                height: 34
                radius: height / 2
                color: selected || themeMouse.containsMouse ? Local.Theme.accent : Local.Theme.surface
                border.color: selected ? Local.Theme.highlight : Local.Theme.accent
                border.width: selected ? 2 : 1

                Text {
                    anchors.centerIn: parent
                    text: modelData === "dark" ? "󰖔  Dark" : "󰖙  Light"
                    color: Local.Theme.secondaryText
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (parent.selected)
                            selector.pill.applyTheme(parent.modelData)
                        else
                            selector.pill.themeIndex = parent.index
                    }
                }
            }
        }
    }
}
