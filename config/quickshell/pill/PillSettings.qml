import QtQuick
import "Singletons" as Local

Item {
    id: panel

    property var pill
    property real morphCloseness: 0

    component Stepper: Item {
        id: stepper
        required property string label
        required property int value
        signal changed(int value)

        width: parent.width
        height: 46

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Rectangle {
                width: 26; height: 26; radius: height / 2; color: Local.Theme.surface
                Text { anchors.centerIn: parent; text: "−"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
                MouseArea { anchors.fill: parent; onClicked: stepper.changed(Math.max(0, stepper.value - 1)) }
            }
            Text { width: 24; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: stepper.value; color: Local.Theme.highlight; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
            Rectangle {
                width: 26; height: 26; radius: height / 2; color: Local.Theme.surface
                Text { anchors.centerIn: parent; text: "+"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15 }
                MouseArea { anchors.fill: parent; onClicked: stepper.changed(Math.min(30, stepper.value + 1)) }
            }
        }
    }

    anchors.fill: parent
    visible: pill.settingsOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 5

        Text { text: "󰒓  Pill settings"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 13; font.bold: true }
        Text { text: "shape and layout"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 9 }

        Stepper {
            label: "Bar roundness"
            value: Local.Settings.barRadius
            onChanged: value => { Local.Settings.barRadius = value; Local.Settings.save() }
        }

        Stepper {
            label: "Pill roundness"
            value: Local.Settings.pillRadius
            onChanged: value => { Local.Settings.pillRadius = value; Local.Settings.save() }
        }

        Rectangle {
            width: parent.width
            height: 46
            radius: 12
            color: Local.Settings.notchMode ? Local.Theme.highlight : Local.Theme.surface
            border.color: Local.Theme.accent
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰘔  " + (Local.Settings.notchMode ? "macOS notch" : "Dynamic Island")
                color: Local.Settings.notchMode ? Local.Theme.background : Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: { Local.Settings.notchMode = !Local.Settings.notchMode; Local.Settings.save() }
            }
        }
    }
}
