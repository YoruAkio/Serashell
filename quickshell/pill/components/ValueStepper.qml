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

    onValueChanged: {
        if (!valueInput.activeFocus)
            valueInput.text = value
    }

    Row {
        id: controls
        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            width: 26
            height: 26
            radius: height / 2
            color: Local.Theme.surface
            Text { anchors.centerIn: parent; text: "−"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
            MouseArea { anchors.fill: parent; onPressed: stepper.changed(Math.max(stepper.minimum, stepper.value - 1)) }
        }

        TextInput {
            id: valueInput
            width: 32
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: stepper.value
            color: Local.Theme.highlight
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
            selectByMouse: true
            validator: IntValidator { bottom: stepper.minimum; top: stepper.maximum }
            onEditingFinished: {
                const next = Number(text)
                stepper.changed(Math.max(stepper.minimum, Math.min(stepper.maximum, Number.isFinite(next) ? next : stepper.value)))
                text = stepper.value
            }
        }

        Rectangle {
            width: 26
            height: 26
            radius: height / 2
            color: Local.Theme.surface
            Text { anchors.centerIn: parent; text: "+"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
            MouseArea { anchors.fill: parent; onPressed: stepper.changed(Math.min(stepper.maximum, stepper.value + 1)) }
        }
    }
}
