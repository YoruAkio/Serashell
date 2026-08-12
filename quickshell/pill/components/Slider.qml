import QtQuick
import QtQuick.Controls
import "../Singletons" as Local

Slider {
    id: control

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 6
        radius: height / 2
        color: Local.Theme.background

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Local.Theme.highlight
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 22
        height: 12
        radius: height / 2
        color: Local.Theme.text
        border.color: Local.Theme.accent
        border.width: 1
    }
}
