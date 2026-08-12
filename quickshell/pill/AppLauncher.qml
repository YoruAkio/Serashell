import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "Singletons" as Local

Item {
    id: launcher

    property var pill
    property real morphCloseness: 0

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    anchors.fill: parent
    visible: pill.launcherOpen
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
            text: launcher.pill.launcherQuery
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
            selectByMouse: true
            clip: true
            onTextEdited: launcher.pill.launcherQuery = text

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    launcher.pill.launcherOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    launcher.pill.moveLauncher(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    launcher.pill.moveLauncher(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    launcher.pill.launchApplication(launcher.pill.selectedApplication)
                    event.accepted = true
                }
            }
        }

        Text {
            anchors.left: searchInput.left
            anchors.verticalCenter: searchInput.verticalCenter
            visible: searchInput.text.length === 0
            text: "Search applications"
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 11
        }
    }

    Text {
        anchors.centerIn: results
        visible: launcher.pill.filteredApplications.length === 0
        text: "No applications found"
        color: Local.Theme.muted
        font.family: Local.Theme.font
        font.pixelSize: 11
    }

    ListView {
        id: results
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.topMargin: 10
        clip: true
        spacing: 6
        model: launcher.pill.filteredApplications

        ScrollBar.vertical: ScrollBar { }

        delegate: Rectangle {
            id: entry

            required property int index
            required property var modelData
            readonly property bool selected: index === launcher.pill.launcherIndex
            width: results.width
            height: 54
            radius: 10
            color: selected ? Local.Theme.accent : Local.Theme.surface
            border.color: selected ? Local.Theme.highlight : Local.Theme.accent
            border.width: selected ? 2 : 1

            ClippingRectangle {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 8
                color: Local.Theme.background

                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: entry.modelData.icon ? Quickshell.iconPath(entry.modelData.icon) : ""
                    sourceSize.width: 34
                    sourceSize.height: 34
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    text: "󰣆"
                    color: Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 16
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 56
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: entry.modelData.name
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: (entry.modelData.genericName || entry.modelData.comment).length > 0
                    text: entry.modelData.genericName || entry.modelData.comment
                    color: Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: launcher.pill.launcherIndex = entry.index
                onClicked: {
                    launcher.pill.launcherIndex = entry.index
                    launcher.pill.launchApplication(entry.modelData)
                }
            }
        }

        onCountChanged: {
            if (launcher.pill.launcherIndex >= count)
                launcher.pill.launcherIndex = Math.max(0, count - 1)
        }
    }

    Connections {
        target: launcher.pill

        function onLauncherIndexChanged() {
            results.positionViewAtIndex(launcher.pill.launcherIndex, ListView.Contain)
        }
    }
}
