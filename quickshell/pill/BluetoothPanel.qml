import QtQuick
import "Singletons" as Local

Item {
    id: panel

    property var controlCenter

    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
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

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: toggle.toggled(!toggle.checked)
        }
    }

    anchors.fill: parent
    visible: controlCenter.page === "bluetooth"

    Item {
        height: 24
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅁"
            color: bluetoothBack.containsMouse ? Local.Theme.text : Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 20
            font.bold: true

            MouseArea {
                id: bluetoothBack
                anchors.fill: parent
                anchors.margins: -7
                hoverEnabled: true
                onClicked: controlCenter.page = "home"
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            text: "󰂯  Bluetooth"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Toggle {
            anchors.right: parent.right
            checked: controlCenter.bluetoothEnabled
            onToggled: checked => controlCenter.setBluetooth(checked)
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 18
        anchors.topMargin: 54
        text: controlCenter.bluetoothEnabled ? "Known devices" : "Bluetooth is off"
        color: Local.Theme.muted
        font.family: Local.Theme.font
        font.pixelSize: 10
    }

    ListView {
        id: devices
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: deviceActions.top
        anchors.margins: 14
        anchors.topMargin: 76
        anchors.bottomMargin: 12
        clip: true
        spacing: 6
        visible: controlCenter.bluetoothEnabled
        model: controlCenter.bluetoothDevices

        delegate: Rectangle {
            id: device
            required property var modelData
            readonly property bool selected: controlCenter.selectedBluetooth && controlCenter.selectedBluetooth.mac === modelData.mac
            width: devices.width
            height: 48
            radius: 12
            color: selected ? Local.Theme.accent : Local.Theme.surface
            border.color: selected ? Local.Theme.highlight : Local.Theme.accent
            border.width: selected ? 2 : 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰂯"
                color: Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 16
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.rightMargin: 78
                anchors.verticalCenter: parent.verticalCenter
                text: device.modelData.name
                color: Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: device.modelData.connected ? "Connected" : (device.modelData.paired ? "Paired" : "Known")
                color: Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 9
            }

            MouseArea { anchors.fill: parent; onClicked: controlCenter.selectedBluetooth = device.modelData }
        }
    }

    Row {
        id: deviceActions
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 8
        visible: controlCenter.selectedBluetooth !== null

        Repeater {
            model: [
                { label: controlCenter.selectedBluetooth && controlCenter.selectedBluetooth.connected ? "Disconnect" : "Connect", action: "connect" },
                { label: "Accept", action: "pair" },
                { label: "Trust", action: "trust" },
                { label: "Reject", action: "remove" }
            ]

            delegate: Rectangle {
                required property var modelData
                width: 76
                height: 32
                radius: height / 2
                color: Local.Theme.surface
                border.color: Local.Theme.accent
                border.width: 1

                Text { anchors.centerIn: parent; text: modelData.label; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 9 }
                MouseArea { anchors.fill: parent; onClicked: controlCenter.manageBluetooth(modelData.action) }
            }
        }
    }
}
