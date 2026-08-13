import QtQuick
import Quickshell.Widgets
import "Singletons" as Local

Item {
    id: selector

    property var pill
    property real morphCloseness: 0
    readonly property real contentScale: Math.min(width / 460, height / 166)

    anchors.fill: parent
    visible: pill.wallpaperPickerOpen

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 106 * selector.contentScale
        clip: true

        Repeater {
            model: selector.pill.wallpapers

            delegate: Item {
                id: thumbnail

                required property int index
                required property string modelData
                readonly property bool selected: index === selector.pill.wallpaperIndex
                x: parent.width / 2 - width / 2 + (index - selector.pill.wallpaperIndex) * 130 * selector.contentScale
                y: parent.height / 2 - height / 2
                width: 120 * selector.contentScale
                height: 100 * selector.contentScale
                opacity: selected ? 1 : 0.65

                Behavior on x {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 12 * selector.contentScale
                    color: Local.Theme.surface

                    Image {
                        anchors.fill: parent
                        source: "file://" + selector.pill.wallDir + "/" + thumbnail.modelData
                        sourceSize.width: 256
                        sourceSize.height: 160
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#22000000"
                        visible: !thumbnail.selected
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12 * selector.contentScale
                    color: "transparent"
                    border.width: thumbnail.selected ? 2 : 1
                    border.color: thumbnail.selected ? Local.Theme.highlight : Local.Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (thumbnail.selected)
                            selector.pill.applyWallpaper(thumbnail.modelData)
                        else
                            selector.pill.wallpaperIndex = thumbnail.index
                    }
                }
            }
        }
    }
}
