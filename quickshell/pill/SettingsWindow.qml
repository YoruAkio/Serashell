import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons" as Local
import "components" as Components

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool open: true
    property string page: "appearance"
    property bool islandStyleMenuOpen: false
    signal dismissed()

    function close() {
        open = false
        dismissed()
    }

    component SidebarItem: Rectangle {
        id: sidebarItem

        required property string icon
        required property string label
        required property bool selected
        signal activated()

        width: parent.width
        height: 34
        radius: 9
        color: selected ? Local.Theme.highlight : sidebarMouse.containsMouse ? Local.Theme.surface : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: sidebarItem.icon
            color: sidebarItem.selected ? Local.Theme.background : Local.Theme.secondaryText
            font.family: Local.Theme.font
            font.pixelSize: 14
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.verticalCenter: parent.verticalCenter
            text: sidebarItem.label
            color: sidebarItem.selected ? Local.Theme.background : Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: sidebarItem.selected
        }

        MouseArea {
            id: sidebarMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sidebarItem.activated()
        }
    }

    component SettingRow: Item {
        required property string label
        required property string description
        required property bool enabled
        required property bool checked
        signal toggled(bool value)

        width: parent.width
        height: 54
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: parent.label
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: parent.description
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 10
        }

        Components.Toggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            interactive: parent.enabled
            checked: parent.checked
            onToggled: value => parent.toggled(value)
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: 680
            height: 410
            radius: 26
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            scale: root.open ? 1 : 0.94

            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: islandStyleDropdown.open = false
            }

            Rectangle {
                z: 1
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                width: 32
                height: 32
                radius: height / 2
                color: Local.Theme.highlight

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: Local.Theme.background
                    font.family: Local.Theme.font
                    font.pixelSize: 15
                    font.bold: true
                }

                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }

            Rectangle {
                id: sidebar

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                anchors.leftMargin: 8
                width: 160
                radius: 20
                color: Local.Theme.background

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 42

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "󰒓  Serashell"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                            font.bold: true
                        }

                    }

                    SidebarItem {
                        icon: "󰘔"
                        label: "Appearance"
                        selected: root.page === "appearance"
                        onActivated: root.page = "appearance"
                    }

                    SidebarItem {
                        icon: "󰃭"
                        label: "Date & Time"
                        selected: root.page === "clock"
                        onActivated: root.page = "clock"
                    }
                }
            }

            Rectangle {
                id: contentBackground

                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 6
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                radius: 20
                color: Local.Theme.surface
            }

            Item {
                id: content

                anchors.fill: contentBackground
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 20
                anchors.bottomMargin: 20

                Column {
                    visible: root.page === "appearance"
                    anchors.fill: parent
                    spacing: 14

                    Text {
                        text: "Appearance"
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "Shape and presentation"
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: ["Bar roundness", "Pill roundness"]

                        delegate: Item {
                            id: radiusRow

                            required property int index
                            required property string modelData
                            width: content.width
                            height: 46
                            readonly property int value: index === 0 ? Local.Settings.barRadius : Local.Settings.pillRadius

                            function setValue(next) {
                                if (index === 0)
                                    Local.Settings.barRadius = next
                                else
                                    Local.Settings.pillRadius = next
                                Local.Settings.save()
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: radiusRow.modelData
                                color: Local.Theme.text
                                font.family: Local.Theme.font
                                font.pixelSize: 13
                            }

                            Components.ValueStepper {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                value: radiusRow.value
                                onChanged: value => radiusRow.setValue(value)
                            }
                        }
                    }

                    Item {
                        id: islandStyleRow

                        width: parent.width
                        height: 46

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Island style"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 13
                        }

                        Components.Dropdown {
                            id: islandStyleDropdown

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: [
                                { label: "Dynamic Island" },
                                { label: "macOS Notch" }
                            ]
                            currentIndex: Local.Settings.notchMode ? 1 : 0
                            onSelected: index => {
                                Local.Settings.notchMode = index === 1
                                Local.Settings.save()
                            }
                        }

                        Rectangle {
                            id: styleSelector

                            visible: false

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 158
                            height: 34
                            radius: 10
                            color: root.islandStyleMenuOpen ? Local.Theme.surface : Local.Theme.background
                            border.color: root.islandStyleMenuOpen ? Local.Theme.highlight : Local.Theme.accent
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 11
                                anchors.verticalCenter: parent.verticalCenter
                                text: Local.Settings.notchMode ? "macOS Notch" : "Dynamic Island"
                                color: Local.Theme.text
                                font.family: Local.Theme.font
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.islandStyleMenuOpen ? "󰅀" : "󰅂"
                                color: Local.Theme.secondaryText
                                font.family: Local.Theme.font
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: selectorMouse
                                anchors.fill: parent
                                onClicked: root.islandStyleMenuOpen = !root.islandStyleMenuOpen
                            }
                        }

                        Rectangle {
                            z: 2
                            anchors.right: parent.right
                            anchors.top: styleSelector.bottom
                            anchors.topMargin: 5
                            width: styleSelector.width
                            height: root.islandStyleMenuOpen ? 72 : 0
                            opacity: root.islandStyleMenuOpen ? 1 : 0
                            visible: height > 0
                            clip: true
                            radius: 11
                            color: Local.Theme.background
                            border.color: Local.Theme.accent
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            Repeater {
                                model: [
                                    { label: "Dynamic Island", notch: false },
                                    { label: "macOS Notch", notch: true }
                                ]

                                delegate: Item {
                                    required property int index
                                    required property var modelData
                                    width: parent.width
                                    height: 36
                                    y: index * height

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        radius: 7
                                        color: optionMouse.containsMouse ? Local.Theme.surface : "transparent"

                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        z: 1
                                        anchors.left: parent.left
                                        anchors.leftMargin: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.label
                                        color: Local.Settings.notchMode === parent.modelData.notch ? Local.Theme.highlight : Local.Theme.text
                                        font.family: Local.Theme.font
                                        font.pixelSize: 11
                                        font.bold: Local.Settings.notchMode === parent.modelData.notch
                                    }

                                    MouseArea {
                                        id: optionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Local.Settings.notchMode = parent.modelData.notch
                                            Local.Settings.save()
                                            root.islandStyleMenuOpen = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: root.page === "clock"
                    anchors.fill: parent
                    spacing: 14

                    Text {
                        text: "Date & Time"
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "Choose what appears in the bar clock"
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 194
                        radius: 18
                        color: Local.Theme.surface

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 9

                            SettingRow {
                                label: "Show date"
                                description: "Display day and month"
                                enabled: true
                                checked: Local.Settings.showDate
                                onToggled: value => {
                                    Local.Settings.showDate = value
                                    Local.Settings.save()
                                }
                            }

                            SettingRow {
                                label: "Show time"
                                description: "Display the current time"
                                enabled: true
                                checked: Local.Settings.showTime
                                onToggled: value => {
                                    Local.Settings.showTime = value
                                    Local.Settings.save()
                                }
                            }

                            SettingRow {
                                label: "Show seconds"
                                description: "Include seconds beside the time"
                                enabled: Local.Settings.showTime
                                checked: Local.Settings.showSeconds
                                onToggled: value => {
                                    Local.Settings.showSeconds = value
                                    Local.Settings.save()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
