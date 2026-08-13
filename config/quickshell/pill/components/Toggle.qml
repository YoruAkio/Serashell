import QtQuick
import "../Singletons" as Local

Rectangle {
    id: toggle

    property bool checked: false
    property bool interactive: true
    signal toggled(bool checked)

    width: 48
    height: 20
    radius: height / 2
    color: checked ? Local.Theme.highlight : Local.Theme.surface
    border.color: Local.Theme.accent
    border.width: 1

    Rectangle {
        width: 24
        height: 14
        radius: height / 2
        x: toggle.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        color: toggle.checked ? Local.Theme.background : Local.Theme.muted

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: toggle.interactive
        onClicked: toggle.toggled(!toggle.checked)
    }
}
