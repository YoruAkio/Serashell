import QtQuick
import "Singletons" as Local

Item {
    id: selector

    property var pill
    property real morphCloseness: 0

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    anchors.fill: parent
    opacity: pill.emojiPickerOpen ? morphCloseness : 0

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: 30
        radius: height / 2
        color: Local.Theme.surface
        border.color: Local.Theme.accent
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 13
        }

        TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: selector.pill.emojiQuery
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
            selectByMouse: true
            onTextEdited: selector.pill.emojiQuery = text

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    selector.pill.emojiPickerOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Left) {
                    selector.pill.moveEmoji(-1, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    selector.pill.moveEmoji(1, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    selector.pill.moveEmoji(0, -1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    selector.pill.moveEmoji(0, 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    selector.pill.copyEmoji(selector.pill.filteredEmojis[selector.pill.emojiIndex])
                    event.accepted = true
                }
            }
        }

        Text {
            anchors.left: searchInput.left
            anchors.verticalCenter: searchInput.verticalCenter
            visible: searchInput.text.length === 0
            text: "Search emoji"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 11
        }
    }

    GridView {
        id: emojiGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 54
        clip: true
        cellWidth: width / 6
        cellHeight: 52
        model: selector.pill.filteredEmojis

        delegate: Rectangle {
            required property int index
            required property var modelData
            readonly property bool selected: index === selector.pill.emojiIndex

            width: emojiGrid.cellWidth - 6
            height: emojiGrid.cellHeight - 6
            x: 3
            y: 3
            radius: 10
            color: selected || emojiMouse.containsMouse ? Local.Theme.surface : "transparent"
            border.color: selected ? Local.Theme.highlight : "transparent"
            border.width: selected ? 1 : 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 5
                text: parent.modelData.emoji
                color: Local.Theme.text
                font.pixelSize: 18
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                width: parent.width - 6
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: parent.modelData.name
                color: Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 8
            }

            MouseArea {
                id: emojiMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: selector.pill.emojiIndex = parent.index
                onClicked: selector.pill.copyEmoji(parent.modelData)
            }
        }

        Connections {
            target: selector.pill
            function onEmojiIndexChanged() {
                emojiGrid.positionViewAtIndex(selector.pill.emojiIndex, GridView.Contain)
            }
        }
    }
}
