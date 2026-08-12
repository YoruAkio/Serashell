import QtQuick
import "../Singletons" as Local

Item {
    id: stepper

    property int value: 0
    property int minimum: 0
    property int maximum: 30
    signal changed(int value)

    implicitWidth: controls.width
    implicitHeight: controls.height

    Row {
        id: controls
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 32
            height: 32
            radius: height / 2
            color: Local.Theme.surface
            Text { anchors.centerIn: parent; text: "−"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 17 }
            MouseArea { anchors.fill: parent; onClicked: stepper.changed(Math.max(stepper.minimum, stepper.value - 1)) }
        }

        Text {
            width: 28
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: stepper.value
            color: Local.Theme.highlight
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Rectangle {
            width: 32
            height: 32
            radius: height / 2
            color: Local.Theme.surface
            Text { anchors.centerIn: parent; text: "+"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 17 }
            MouseArea { anchors.fill: parent; onClicked: stepper.changed(Math.min(stepper.maximum, stepper.value + 1)) }
        }
    }
}
