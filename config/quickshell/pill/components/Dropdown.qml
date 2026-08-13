import QtQuick
import "../Singletons" as Local

Item {
    id: dropdown

    property var options: []
    property int currentIndex: 0
    property bool open: false
    signal selected(int index)

    width: 158
    height: 34

    Rectangle {
        id: selector
        anchors.fill: parent
        radius: 10
        color: dropdown.open ? Local.Theme.surface : Local.Theme.background
        border.color: dropdown.open ? Local.Theme.highlight : Local.Theme.accent
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: dropdown.options[dropdown.currentIndex]?.label ?? ""
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: dropdown.open ? "󰅀" : "󰅂"
            color: Local.Theme.secondaryText
            font.family: Local.Theme.font
            font.pixelSize: 13
        }

        MouseArea { anchors.fill: parent; onClicked: dropdown.open = !dropdown.open }
    }

    Rectangle {
        z: 2
        anchors.top: parent.bottom
        anchors.topMargin: 5
        width: parent.width
        height: dropdown.open ? dropdown.options.length * 36 : 0
        opacity: dropdown.open ? 1 : 0
        visible: height > 0
        clip: true
        radius: 11
        color: Local.Theme.background
        border.color: Local.Theme.accent
        border.width: 1

        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

        Repeater {
            model: dropdown.options

            delegate: Item {
                required property int index
                required property var modelData
                width: parent.width
                height: 36
                y: index * height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 7
                    color: optionMouse.containsMouse ? Local.Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    z: 1
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    color: dropdown.currentIndex === parent.index ? Local.Theme.highlight : Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                    font.bold: dropdown.currentIndex === parent.index
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        dropdown.selected(parent.index)
                        dropdown.open = false
                    }
                }
            }
        }
    }
}
