import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import "Singletons" as Local

Item {
    id: selector

    property var pill
    property real morphCloseness: 0

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    anchors.fill: parent
    visible: pill.clipboardPickerOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: 34
        radius: height / 2
        color: Local.Theme.surface
        border.color: Local.Theme.accent
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 14
        }

        TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: selector.pill.clipboardQuery
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
            selectByMouse: true
            clip: true
            onTextEdited: selector.pill.clipboardQuery = text

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    selector.pill.clipboardPickerOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    selector.pill.moveClipboard(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    selector.pill.moveClipboard(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    selector.pill.copyClipboard(selector.pill.selectedClipboard)
                    event.accepted = true
                }
            }
        }

        Text {
            anchors.left: searchInput.left
            anchors.verticalCenter: searchInput.verticalCenter
            visible: searchInput.text.length === 0
            text: "Search clipboard"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 11
        }
    }

    ListView {
        id: history
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.topMargin: 10
        clip: true
        spacing: 6
        model: selector.pill.filteredClipboard

        ScrollBar.vertical: ScrollBar { }

        delegate: Rectangle {
            id: entry

            required property int index
            required property var modelData
            readonly property bool selected: index === selector.pill.clipboardIndex
            width: history.width
            height: entry.modelData.image ? 64 : 48
            radius: 10
            color: selected ? Local.Theme.accent : Local.Theme.surface
            border.color: selected ? Local.Theme.highlight : Local.Theme.accent
            border.width: selected ? 2 : 1

            ClippingRectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46
                radius: 7
                color: Local.Theme.accent
                visible: entry.modelData.image

                Image {
                    anchors.fill: parent
                    source: "file://" + entry.modelData.preview + "?v=" + selector.pill.clipboardPreviewVersion
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: entry.modelData.image ? 70 : 12
                anchors.verticalCenter: parent.verticalCenter
                visible: !entry.modelData.image
                text: "󰈙"
                color: Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 16
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: entry.modelData.image ? 70 : 40
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.label
                color: Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: selector.pill.clipboardIndex = entry.index
                onClicked: {
                    selector.pill.clipboardIndex = entry.index
                    selector.pill.copyClipboard(entry.modelData)
                }
            }
        }

        onCountChanged: {
            if (selector.pill.clipboardIndex >= count)
                selector.pill.clipboardIndex = Math.max(0, count - 1)
        }
    }

    Connections {
        target: selector.pill

        function onClipboardIndexChanged() {
            history.positionViewAtIndex(selector.pill.clipboardIndex, ListView.Contain)
        }
    }
}
