import QtQuick
import "Singletons" as Local
import "components" as Components

Item {
    id: panel

    property var controlCenter

    anchors.fill: parent
    visible: controlCenter.page === "wifi"

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
            color: wifiBack.containsMouse ? Local.Theme.text : Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 20
            font.bold: true

            MouseArea {
                id: wifiBack
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
            text: "󰖩  Wi-Fi"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Components.Toggle {
            anchors.right: parent.right
            checked: controlCenter.wifiEnabled
            onToggled: checked => controlCenter.setWifi(checked)
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 18
        anchors.topMargin: 54
        text: controlCenter.wifiEnabled ? "Available networks" : "Wi-Fi is off"
        color: Local.Theme.muted
        font.family: Local.Theme.font
        font.pixelSize: 10
    }

    ListView {
        id: networks
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.topMargin: 76
        anchors.bottomMargin: 14
        clip: true
        spacing: 6
        visible: controlCenter.wifiEnabled
        model: controlCenter.wifiNetworks

        delegate: Rectangle {
            id: network
            required property var modelData
            readonly property bool selected: controlCenter.selectedWifi && controlCenter.selectedWifi.ssid === modelData.ssid
            width: networks.width
            height: selected && modelData.secure && !modelData.saved && !modelData.connected ? 84 : 46
            radius: 12
            color: selected ? Local.Theme.accent : Local.Theme.surface
            border.color: selected ? Local.Theme.highlight : Local.Theme.accent
            border.width: selected ? 2 : 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 14
                text: "󰖩"
                color: Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 16
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.rightMargin: 52
                anchors.top: parent.top
                anchors.topMargin: 16
                text: network.modelData.ssid
                color: Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 17
                text: network.modelData.connected ? "Connected" : (network.modelData.connecting ? "Connecting" : (network.modelData.saved ? "Saved" : (network.modelData.secure ? "󰌾" : network.modelData.signal + "%")))
                color: Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 10
            }

            MouseArea {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 46
                onClicked: {
                    controlCenter.selectedWifi = network.modelData
                    if (network.modelData.connected || network.modelData.saved || !network.modelData.secure)
                        controlCenter.connectWifi()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 42
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 36
                radius: height / 2
                color: Local.Theme.background
                visible: network.selected && network.modelData.secure && !network.modelData.saved && !network.modelData.connected

                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: enterButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: controlCenter.wifiPassword
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 10
                    echoMode: TextInput.Password
                    onTextEdited: controlCenter.wifiPassword = text
                    Keys.onReturnPressed: controlCenter.connectWifi()
                }

                Text {
                    anchors.left: passwordInput.left
                    anchors.verticalCenter: passwordInput.verticalCenter
                    visible: passwordInput.text.length === 0
                    text: "Network password"
                    color: Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 10
                }

                Text {
                    id: enterButton
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌑"
                    color: Local.Theme.highlight
                    font.family: Local.Theme.font
                    font.pixelSize: 16

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: controlCenter.connectWifi()
                    }
                }
            }
        }
    }
}
