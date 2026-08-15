import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import "Singletons" as Local
import "components" as Components

FloatingWindow {
    id: root

    title: "Serashell"
    implicitWidth: 1040
    implicitHeight: 720
    minimumSize: Qt.size(760, 520)
    color: "transparent"
    visible: open

    property bool open: true
    property string page: "bar"
    property bool barExpanded: true
    property bool islandStyleMenuOpen: false
    readonly property int settingRowHeight: 40
    readonly property int settingSpacing: 8
    readonly property int dropdownRowHeight: 42
    signal dismissed()

    function close() {
        open = false
        dismissed()
    }

    function aiUsageVisible(provider, target) {
        const providers = target === "bar" ? Local.Settings.aiUsageBarProviders : Local.Settings.aiUsagePanelProviders
        return providers.split(",").includes(provider)
    }

    function setAiUsageVisible(provider, target, enabled) {
        const property = target === "bar" ? "aiUsageBarProviders" : "aiUsagePanelProviders"
        const providers = Local.Settings[property].split(",").filter(value => value && value !== provider)
        if (enabled) providers.push(provider)
        Local.Settings[property] = providers.join(",")
        Local.Settings.save()
    }

    component SidebarItem: Rectangle {
        id: sidebarItem

        required property string icon
        required property string label
        required property bool selected
        property bool expandable: false
        property bool expanded: false
        signal activated()

        width: parent.width - 8
        x: 4
        height: 30
        radius: 9
        color: selected ? Local.Theme.highlight : sidebarMouse.containsMouse ? Local.Theme.surface : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: sidebarItem.icon
            color: sidebarItem.selected ? Local.Theme.background : Local.Theme.secondaryText
            font.family: Local.Theme.font
            font.pixelSize: 16
        }

        Text {
            visible: sidebarItem.expandable
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: sidebarItem.expanded ? "󰅀" : "󰅂"
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
            font.pixelSize: 14
            font.bold: sidebarItem.selected
        }

        MouseArea {
            id: sidebarMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: sidebarItem.activated()
        }
    }

    component SidebarChild: Rectangle {
        id: sidebarChild

        required property string icon
        required property string label
        required property bool selected
        signal activated()

        width: parent.width - 28
        x: 24
        height: 28
        radius: 7
        color: selected ? Local.Theme.accent : childMouse.containsMouse ? Local.Theme.surface : "transparent"

        Text { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: sidebarChild.icon; color: Local.Theme.secondaryText; font.family: Local.Theme.font; font.pixelSize: 16 }
        Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: sidebarChild.label; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 12; font.bold: sidebarChild.selected }
        MouseArea { id: childMouse; anchors.fill: parent; hoverEnabled: true; onClicked: sidebarChild.activated() }
    }

    component SettingRow: Item {
        required property string label
        required property string description
        required property bool enabled
        required property bool checked
        signal toggled(bool value)

        width: parent.width
        height: root.settingRowHeight
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: parent.label
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 24
            text: parent.description
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 11
        }

        Components.Toggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            interactive: parent.enabled
            checked: parent.checked
            onToggled: value => parent.toggled(value)
        }
    }

    component PanelSizeRow: Item {
        required property string label
        required property string sizeProperty

        width: parent.width
        height: root.settingRowHeight

        function setSize(value) {
            Local.Settings[sizeProperty] = value
            Local.Settings.save()
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 14
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Components.ValueStepper { value: Local.Settings[parent.parent.sizeProperty]; minimum: 50; maximum: 200; onChanged: value => parent.parent.setSize(value) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "%"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 12 }
        }
    }

    component AiProviderRow: Item {
        id: providerRow
        required property string providerId
        required property string label

        width: parent.width
        height: 34
        opacity: Local.Settings.showAiUsage ? 1 : 0.45

        Item {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            Image {
                id: providerIcon
                anchors.fill: parent
                source: "assets/" + providerRow.providerId + ".svg"
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: providerIcon
                brightness: 1
                colorization: 1
                colorizationColor: Local.Theme.secondaryText
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 14
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Components.Toggle {
                interactive: Local.Settings.showAiUsage
                checked: root.aiUsageVisible(parent.parent.providerId, "bar")
                onToggled: value => root.setAiUsageVisible(parent.parent.providerId, "bar", value)
            }

            Components.Toggle {
                interactive: Local.Settings.showAiUsage
                checked: root.aiUsageVisible(parent.parent.providerId, "panel")
                onToggled: value => root.setAiUsageVisible(parent.parent.providerId, "panel", value)
            }
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
            width: root.width
            height: root.height
            radius: 10
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            scale: root.open ? 1 : 0.94

            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    islandStyleDropdown.open = false
                    if (typeof keystrokePositionDropdown !== "undefined") keystrokePositionDropdown.open = false
                    if (typeof keystrokeModeDropdown !== "undefined") keystrokeModeDropdown.open = false
                }
            }

            Rectangle {
                z: 1
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                width: 26
                height: 26
                radius: height / 2
                color: Local.Theme.highlight

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: Local.Theme.background
                    font.family: Local.Theme.font
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }

            Rectangle {
                id: sidebar

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                anchors.bottomMargin: 4
                anchors.leftMargin: 2
                width: 210
                radius: 15
                color: Local.Theme.background

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 34

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -10
                            text: "󰒓"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 19
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -10
                            text: "Serashell"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 18
                            font.bold: true
                        }

                    }

                    SidebarItem {
                        icon: "󰌷"
                        label: "Bar Settings"
                        selected: root.page === "bar"
                        expandable: true
                        expanded: root.barExpanded
                        onActivated: { root.page = "bar"; root.barExpanded = !root.barExpanded }
                    }

                    SidebarChild { visible: root.barExpanded; icon: "󰊤"; label: "AI Usage"; selected: root.page === "ai-usage"; onActivated: root.page = "ai-usage" }
                    SidebarChild { visible: root.barExpanded; icon: "󰃭"; label: "Date & Time"; selected: root.page === "clock"; onActivated: root.page = "clock" }
                    SidebarChild { visible: root.barExpanded; icon: "󰍛"; label: "System status"; selected: root.page === "system"; onActivated: root.page = "system" }

                    SidebarItem {
                        icon: "󰒓"
                        label: "Pill Settings"
                        selected: root.page === "pill"
                        expandable: true
                        expanded: true
                        onActivated: root.page = "pill"
                    }

                    SidebarChild { icon: "󰧑"; label: "Panel sizes"; selected: root.page === "panel-sizes"; onActivated: root.page = "panel-sizes" }

                    SidebarItem {
                        icon: "󰌌"
                        label: "Keystroke"
                        selected: root.page === "keystroke"
                        onActivated: root.page = "keystroke"
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    spacing: 5

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 9
                        color: githubMouse.containsMouse ? Local.Theme.surface : Local.Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: githubMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached({ command: ["xdg-open", "https://github.com/YoruAkio/Serashell"] })
                        }
                    }

                    Rectangle {
                        width: parent.width - 39
                        height: 34
                        radius: 9
                        color: resetMouse.containsMouse ? Local.Theme.surface : Local.Theme.accent

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰑓"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 16
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Reset"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Local.Settings.reset()
                        }
                    }
                }
            }

            Rectangle {
                id: contentBackground

                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 15
                color: Local.Theme.surface
            }

            Flickable {
                id: contentViewport
                anchors.fill: contentBackground
                anchors.topMargin: 38
                clip: true
                contentWidth: width
                contentHeight: content.height + 40

                ScrollBar.vertical: ScrollBar { }

                Item {
                    id: content
                    x: 20
                    y: 4
                    width: contentViewport.width - 40
                    height: root.page === "bar" ? 480 : root.page === "panel-sizes" ? 340 : root.page === "keystroke" ? 520 : contentViewport.height - 40

                Column {
                    visible: root.page === "pill"
                    anchors.fill: parent
                    spacing: root.settingSpacing

                    Text {
                        text: "Pill Settings"
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "Center island shape and presentation"
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: ["Pill roundness"]
                        visible: root.page === "pill"

                        delegate: Item {
                            id: radiusRow

                            required property int index
                            required property string modelData
                            width: content.width
                            height: root.settingRowHeight
                            readonly property int value: Local.Settings.pillRadius

                            function setValue(next) {
                                Local.Settings.pillRadius = next
                                Local.Settings.save()
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: radiusRow.modelData
                                color: Local.Theme.text
                                font.family: Local.Theme.font
                                font.pixelSize: 14
                            }

                            Components.ValueStepper {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                value: radiusRow.value
                                maximum: 15
                                onChanged: value => radiusRow.setValue(value)
                            }
                        }
                    }

                    Item {
                        id: islandStyleRow

                        width: parent.width
                        height: root.dropdownRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Island style"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
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
                    visible: root.page === "bar"
                    width: parent.width
                    spacing: root.settingSpacing

                    Text { text: "Bar Settings"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 20; font.bold: true }
                    Text { text: "Bar shape and elements"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 13 }
                    Item {
                        width: parent.width
                        height: root.settingRowHeight
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Bar roundness"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14 }
                        Components.ValueStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; value: Local.Settings.barRadius; maximum: 15; onChanged: value => { Local.Settings.barRadius = value; Local.Settings.save() } }
                    }

                    SettingRow { label: "System tray"; description: "Display application status icons"; enabled: true; checked: Local.Settings.showTray; onToggled: value => { Local.Settings.showTray = value; Local.Settings.save() } }
                    SettingRow { label: "Workspaces"; description: "Display Hyprland workspace buttons"; enabled: true; checked: Local.Settings.showWorkspaces; onToggled: value => { Local.Settings.showWorkspaces = value; Local.Settings.save() } }
                    SettingRow { label: "Window name"; description: "Display the active window title"; enabled: true; checked: Local.Settings.showWindowTitle; onToggled: value => { Local.Settings.showWindowTitle = value; Local.Settings.save() } }
                    SettingRow { label: "Sound"; description: "Display volume and mute control"; enabled: true; checked: Local.Settings.showAudio; onToggled: value => { Local.Settings.showAudio = value; Local.Settings.save() } }
                    SettingRow { label: "Brightness"; description: "Display brightness control"; enabled: true; checked: Local.Settings.showBrightness; onToggled: value => { Local.Settings.showBrightness = value; Local.Settings.save() } }
                    SettingRow { label: "Battery"; description: "Display battery percentage"; enabled: true; checked: Local.Settings.showBattery; onToggled: value => { Local.Settings.showBattery = value; Local.Settings.save() } }
                    SettingRow { label: "Control centre"; description: "Display the quick controls button"; enabled: true; checked: Local.Settings.showControlCenter; onToggled: value => { Local.Settings.showControlCenter = value; Local.Settings.save() } }
                }

                Column {
                    visible: root.page === "ai-usage"
                    width: parent.width
                    spacing: root.settingSpacing

                    Text { text: "AI Usage"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 20; font.bold: true }
                    Text { text: "Choose where each provider appears"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 13 }
                    SettingRow { label: "Show AI Usage"; description: "Display AI usage controls and provider data"; enabled: true; checked: Local.Settings.showAiUsage; onToggled: value => { Local.Settings.showAiUsage = value; Local.Settings.save() } }

                    Item {
                        width: parent.width
                        height: root.settingRowHeight
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Refresh interval"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14; font.bold: true }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Components.ValueStepper { value: Local.Settings.aiUsageRefreshMinutes; minimum: 1; maximum: 60; onChanged: value => { Local.Settings.aiUsageRefreshMinutes = value; Local.Settings.save() } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "min"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 12 }
                        }
                    }

                    Item {
                        width: parent.width
                        height: root.settingRowHeight

                        Text { anchors.left: parent.left; anchors.top: parent.top; text: "Rescan providers"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14; font.bold: true }
                        Text { anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 24; text: "Refresh usage and subscription information now"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11 }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 96
                            height: 28
                            radius: 9
                            color: rescanMouse.containsMouse ? Local.Theme.highlight : Local.Theme.surface
                            border.color: Local.Theme.accent
                            border.width: 1

                            Text { anchors.centerIn: parent; text: "󰑐  Rescan"; color: rescanMouse.containsMouse ? Local.Theme.background : Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: rescanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached({ command: ["qs", "ipc", "call", "aiUsage", "refresh"] })
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 20
                        Row {
                            anchors.right: parent.right
                            spacing: 18
                            Item { width: 48; height: 20; Text { anchors.centerIn: parent; text: "Bar"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true } }
                            Item { width: 48; height: 20; Text { anchors.centerIn: parent; text: "Panel"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true } }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        AiProviderRow { providerId: "claude"; label: "Claude" }
                        AiProviderRow { providerId: "codex"; label: "Codex" }
                        AiProviderRow { providerId: "cursor"; label: "Cursor" }
                        AiProviderRow { providerId: "antigravity"; label: "Antigravity" }
                        AiProviderRow { providerId: "copilot"; label: "GitHub Copilot" }
                        AiProviderRow { providerId: "grok"; label: "Grok" }
                        AiProviderRow { providerId: "opencode"; label: "OpenCode" }
                    }
                }

                Column {
                    visible: root.page === "panel-sizes"
                    width: parent.width
                    spacing: root.settingSpacing

                    Text { text: "Panel sizes"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 20; font.bold: true }
                    Text { text: "Scale each panel from its default size"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 13 }
                    PanelSizeRow { label: "Media"; sizeProperty: "mediaPanelSize" }
                    PanelSizeRow { label: "Clipboard"; sizeProperty: "clipboardPanelSize" }
                    PanelSizeRow { label: "App launcher"; sizeProperty: "launcherPanelSize" }
                    PanelSizeRow { label: "Wallpaper selector"; sizeProperty: "wallpaperPanelSize" }
                    PanelSizeRow { label: "Theme selector"; sizeProperty: "themePanelSize" }
                }

                Column {
                    visible: root.page === "clock"
                    anchors.fill: parent
                    spacing: root.settingSpacing

                    Text {
                        text: "Date & Time"
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "Choose what appears in the bar clock"
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 13
                    }

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

                Column {
                    visible: root.page === "system"
                    anchors.fill: parent
                    spacing: root.settingSpacing

                    Text {
                        text: "System status"
                        color: Local.Theme.text
                        font.family: Local.Theme.font
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: "Choose what appears in the bar"
                        color: Local.Theme.muted
                        font.family: Local.Theme.font
                        font.pixelSize: 13
                    }

                    SettingRow { label: "CPU usage"; description: "Display processor load"; enabled: true; checked: Local.Settings.showCpu; onToggled: value => { Local.Settings.showCpu = value; Local.Settings.save() } }
                    SettingRow { label: "RAM usage"; description: "Display memory use"; enabled: true; checked: Local.Settings.showMemory; onToggled: value => { Local.Settings.showMemory = value; Local.Settings.save() } }
                    SettingRow { label: "Temperature"; description: "Display system temperature"; enabled: true; checked: Local.Settings.showTemperature; onToggled: value => { Local.Settings.showTemperature = value; Local.Settings.save() } }
                    SettingRow { label: "Network speed"; description: "Display network throughput"; enabled: true; checked: Local.Settings.showNetwork; onToggled: value => { Local.Settings.showNetwork = value; Local.Settings.save() } }

                    Item {
                        z: temperatureDropdown.open ? 1 : 0
                        width: parent.width
                        height: root.dropdownRowHeight

                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Temperature unit"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14 }
                        Components.Dropdown { id: temperatureDropdown; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; options: [{ label: "Celsius (°C)" }, { label: "Fahrenheit (°F)" }]; currentIndex: Local.Settings.temperatureUnit === "F" ? 1 : 0; onSelected: index => { Local.Settings.temperatureUnit = index === 1 ? "F" : "C"; Local.Settings.save() } }
                    }

                    Item {
                        width: parent.width
                        height: root.dropdownRowHeight

                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Network display"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14 }
                        Components.Dropdown { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; options: [{ label: "Download" }, { label: "Upload" }, { label: "Both" }]; currentIndex: Local.Settings.networkMode === "download" ? 0 : Local.Settings.networkMode === "upload" ? 1 : 2; onSelected: index => { Local.Settings.networkMode = ["download", "upload", "both"][index]; Local.Settings.save() } }
                    }
                }

                Column {
                    visible: root.page === "keystroke"
                    anchors.fill: parent
                    spacing: root.settingSpacing

                    Text { text: "Keystroke Visualizer"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 20; font.bold: true }
                    Text { text: "On-screen keystroke overlay for casting and recording"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 13 }

                    SettingRow {
                        label: "Enable keystroke overlay"
                        description: "Display currently pressed keys on screen"
                        enabled: true
                        checked: Local.Settings.keystrokeEnabled
                        onToggled: value => {
                            Local.Settings.keystrokeEnabled = value
                            Local.Settings.save()
                        }
                    }

                    Item {
                        id: dropdownRow
                        z: keystrokePositionDropdown.open ? 9999 : 1
                        width: parent.width
                        height: root.dropdownRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Position"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                        }

                        Components.Dropdown {
                            id: keystrokePositionDropdown
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: [
                                { label: "Top Left", value: "top-left" },
                                { label: "Top Center", value: "top-center" },
                                { label: "Top Right", value: "top-right" },
                                { label: "Bottom Left", value: "bottom-left" },
                                { label: "Bottom Center", value: "bottom-center" },
                                { label: "Bottom Right", value: "bottom-right" }
                            ]
                            currentIndex: {
                                const pos = Local.Settings.keystrokePosition
                                const idx = ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"].indexOf(pos)
                                return idx >= 0 ? idx : 4
                            }
                            onSelected: index => {
                                const positions = ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
                                Local.Settings.keystrokePosition = positions[index]
                                Local.Settings.save()
                            }
                        }
                    }

                    Item {
                        id: modeRow
                        z: keystrokeModeDropdown.open ? 9999 : 1
                        width: parent.width
                        height: root.dropdownRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Mode"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                        }

                        Components.Dropdown {
                            id: keystrokeModeDropdown
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: [
                                { label: "Separate", value: "separate" },
                                { label: "Full", value: "full" }
                            ]
                            currentIndex: Local.Settings.keystrokeMode === "full" ? 1 : 0
                            onSelected: index => {
                                Local.Settings.keystrokeMode = index === 1 ? "full" : "separate"
                                Local.Settings.save()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: root.settingRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Box size"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Components.ValueStepper {
                                value: Local.Settings.keystrokeSize
                                minimum: 50
                                maximum: 200
                                onChanged: value => {
                                    Local.Settings.keystrokeSize = value
                                    Local.Settings.save()
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "%"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 12 }
                        }
                    }

                    Item {
                        width: parent.width
                        height: root.settingRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Fade duration"
                            color: Local.Theme.text
                            font.family: Local.Theme.font
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Components.ValueStepper {
                                value: Local.Settings.keystrokeFadeTime
                                minimum: 1
                                maximum: 10
                                onChanged: value => {
                                    Local.Settings.keystrokeFadeTime = value
                                    Local.Settings.save()
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "s"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 12 }
                        }
                    }
                }
                }
            }
        }
    }
}
