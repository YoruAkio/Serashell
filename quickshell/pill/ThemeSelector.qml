import QtQuick
import "Singletons" as Local

Item {
    id: selector

    property var pill
    property real morphCloseness: 0
    readonly property real contentScale: Math.min(width / 300, height / 88)

    anchors.fill: parent
    visible: pill.themePickerOpen && !pill.wallpaperPickerOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16 * selector.contentScale
        spacing: 5 * selector.contentScale

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Theme"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13 * selector.contentScale
            font.bold: true
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 42 * selector.contentScale
        spacing: 10 * selector.contentScale

        Repeater {
            model: selector.pill.themeModes

            delegate: Rectangle {
                required property int index
                required property string modelData
                readonly property bool selected: index === selector.pill.themeIndex
                width: 94 * selector.contentScale
                height: 34 * selector.contentScale
                radius: height / 2
                color: selected || themeMouse.containsMouse ? Local.Theme.accent : Local.Theme.surface
                border.color: selected ? Local.Theme.highlight : Local.Theme.accent
                border.width: (selected ? 2 : 1) * selector.contentScale

                Text {
                    anchors.centerIn: parent
                    text: modelData === "dark" ? "󰖔  Dark" : "󰖙  Light"
                    color: Local.Theme.secondaryText
                    font.family: Local.Theme.font
                    font.pixelSize: 11 * selector.contentScale
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
