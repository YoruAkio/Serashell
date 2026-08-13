import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons" as Local
import "components" as Components

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "control-center"

    property bool open: false
    property bool shown: false
    property string wifiName: "Wi-Fi"
    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property string bluetoothName: "Bluetooth"
    property real brightness: 50
    property string page: "home"
    property var wifiNetworks: []
    property var selectedWifi: null
    property string wifiPassword: ""
    property var bluetoothDevices: []
    property var selectedBluetooth: null
    signal dismissed()
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(item => item.isPlaying) || players[0] || null
    }

    function refresh() {
        networkProcess.running = true
        bluetoothProcess.running = true
        brightnessProcess.running = true
    }

    function close() {
        page = "home"
        open = false
        closeTimer.restart()
    }

    function toggle() {
        if (open) {
            close()
        } else {
            shown = true
            open = true
            refresh()
        }
    }

    function openPage(name) {
        page = name
        if (name === "wifi") {
            selectedWifi = null
            wifiPassword = ""
            wifiListProcess.running = true
        } else if (name === "bluetooth") {
            selectedBluetooth = null
            bluetoothListProcess.running = true
        }
    }

    function setWifi(enabled) {
        actionProcess.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        actionProcess.running = true
        refreshTimer.restart()
        if (enabled)
            wifiListProcess.running = true
    }

    function connectWifi() {
        if (!selectedWifi)
            return
        if (selectedWifi.connected) {
            actionProcess.command = ["sh", "-c", "nmcli device disconnect \"$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == \"wifi\" {print $1; exit}')\"", "wifi-disconnect"]
        } else if (selectedWifi.saved) {
            actionProcess.command = ["nmcli", "connection", "up", "id", selectedWifi.ssid]
        } else if (selectedWifi.secure) {
            wifiConnectProcess.ssid = selectedWifi.ssid
            wifiConnectProcess.password = wifiPassword
            wifiConnectProcess.running = true
            wifiPassword = ""
            refreshTimer.restart()
            return
        } else {
            actionProcess.command = ["sh", "-c", "nmcli device wifi connect \"$1\"", "wifi-connect", selectedWifi.ssid]
        }
        actionProcess.running = true
        wifiPassword = ""
        refreshTimer.restart()
    }

    function setBluetooth(enabled) {
        actionProcess.command = ["bluetoothctl", "power", enabled ? "on" : "off"]
        actionProcess.running = true
        refreshTimer.restart()
        if (enabled)
            bluetoothListProcess.running = true
    }

    function manageBluetooth(action) {
        if (!selectedBluetooth)
            return
        const mac = selectedBluetooth.mac
        if (action === "connect")
            actionProcess.command = ["bluetoothctl", selectedBluetooth.connected ? "disconnect" : "connect", mac]
        else if (action === "pair")
            actionProcess.command = ["bluetoothctl", "pair", mac]
        else if (action === "trust")
            actionProcess.command = ["bluetoothctl", "trust", mac]
        else
            actionProcess.command = ["bluetoothctl", "remove", mac]
        actionProcess.running = true
        bluetoothRefreshTimer.restart()
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "state=$(nmcli -t -f WIFI g 2>/dev/null); name=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1 == \"yes\" {print substr($0, 5); exit}'); printf '%s|%s' \"$state\" \"${name:-Wi-Fi}\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = this.text.trim().split("|")
                root.wifiEnabled = values[0] === "enabled"
                root.wifiName = values[1] || "Wi-Fi"
            }
        }
    }

    Process {
        id: bluetoothProcess
        command: ["sh", "-c", "powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}'); name=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-); printf '%s|%s' \"$powered\" \"${name:-Bluetooth}\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = this.text.trim().split("|")
                root.bluetoothEnabled = values[0] === "yes"
                root.bluetoothName = values[1] || "Bluetooth"
            }
        }
    }

    Process {
        id: brightnessProcess
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = this.text.trim().split(",")
                if (fields.length > 3)
                    root.brightness = Number(fields[3].replace("%", ""))
            }
        }
    }

    Process {
        id: wifiListProcess
        command: ["sh", "-c", "saved=$(nmcli -t -f NAME connection show 2>/dev/null); wifi=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == \"wifi\" {print $1; exit}'); state=$(nmcli -t -f GENERAL.STATE device show \"$wifi\" 2>/dev/null | cut -d: -f2); connection=$(nmcli -t -f GENERAL.CONNECTION device show \"$wifi\" 2>/dev/null | cut -d: -f2); nmcli -t --escape no -f ACTIVE,SSID,SECURITY,SIGNAL dev wifi list --rescan yes 2>/dev/null | awk -F: -v saved=\"$saved\" -v state=\"$state\" -v connection=\"$connection\" 'NF >= 4 && $2 != \"\" && !seen[$2]++ {isSaved = index(\"\\n\" saved \"\\n\", \"\\n\" $2 \"\\n\") > 0; connected = ($1 == \"yes\"); connecting = (state ~ /^40/ && connection == $2); print $2 \"|\" $3 \"|\" $4 \"|\" connected \"|\" isSaved \"|\" connecting}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiNetworks = this.text.trim().split("\n").map(line => {
                    const values = line.split("|")
                    return values.length === 6 ? { ssid: values[0], secure: values[1] !== "--" && values[1] !== "", signal: Number(values[2]), connected: values[3] === "1", saved: values[4] === "1", connecting: values[5] === "1" } : null
                }).filter(network => network !== null)
            }
        }
    }

    Process {
        id: bluetoothListProcess
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do info=$(bluetoothctl info \"$mac\" 2>/dev/null); connected=$(printf '%s\\n' \"$info\" | awk '/Connected:/ {print $2}'); paired=$(printf '%s\\n' \"$info\" | awk '/Paired:/ {print $2}'); trusted=$(printf '%s\\n' \"$info\" | awk '/Trusted:/ {print $2}'); printf '%s|%s|%s|%s|%s\\n' \"$mac\" \"$name\" \"$connected\" \"$paired\" \"$trusted\"; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothDevices = this.text.trim().split("\n").map(line => {
                    const values = line.split("|")
                    return values.length === 5 ? { mac: values[0], name: values[1], connected: values[2] === "yes", paired: values[3] === "yes", trusted: values[4] === "yes" } : null
                }).filter(device => device !== null)
            }
        }
    }

    Process { id: actionProcess }

    Process {
        id: wifiConnectProcess
        property string ssid: ""
        property string password: ""
        command: ["sh", "-c", "IFS= read -r password; nmcli device wifi connect \"$1\" password \"$password\"", "wifi-connect", ssid]
        onRunningChanged: {
            if (running)
                write(password + "\n")
        }
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: bluetoothRefreshTimer
        interval: 900
        onTriggered: bluetoothListProcess.running = true
    }

    Timer {
        id: closeTimer
        interval: 160
        onTriggered: {
            root.shown = false
            root.dismissed()
        }
    }

    component ActionTile: Rectangle {
        id: tile
        required property string icon
        required property string title
        required property string subtitle
        required property bool active
        signal activated()

        width: 178
        height: 72
        radius: 14
        color: active ? Local.Theme.highlight : Local.Theme.surface
        border.color: active ? Local.Theme.highlight : Local.Theme.accent
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            color: parent.active ? Local.Theme.background : Local.Theme.secondaryText
            font.family: Local.Theme.font
            font.pixelSize: 22
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 47
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: tile.title
                color: tile.active ? Local.Theme.background : Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.subtitle
                color: tile.active ? Local.Theme.accent : Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.activated()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: {
            if (root.page === "home")
                root.close()
            else
                root.page = "home"
        }

        Rectangle {
            id: card
            width: root.open ? (root.page === "home" ? 382 : 480) : 30
            height: root.open ? (root.page === "home" ? 396 : 340) : 30
            x: parent.width - width - 12
            y: 46
            radius: root.open ? 26 : 15
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            clip: true
            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Behavior on height {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea { anchors.fill: parent }

            Item {
                id: quickControls
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.margins: 12
                height: 152
                visible: root.page === "home"

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 8

                    ActionTile {
                        width: 172
                        height: 72
                        icon: "󰖩"
                        title: "Wi-Fi"
                        subtitle: root.wifiName
                        active: root.wifiEnabled
                        onActivated: {
                            root.openPage("wifi")
                        }
                    }

                    ActionTile {
                        width: 172
                        height: 72
                        icon: "󰂯"
                        title: "Bluetooth"
                        subtitle: root.bluetoothName
                        active: root.bluetoothEnabled
                        onActivated: {
                            root.openPage("bluetooth")
                        }
                    }
                }

                Rectangle {
                id: media
                anchors.right: parent.right
                anchors.top: parent.top
                width: 174
                height: parent.height
                radius: 18
                color: Local.Theme.surface
                border.color: Local.Theme.accent
                border.width: 1

                ClippingRectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    width: 48
                    height: 48
                    radius: 12
                    color: Local.Theme.accent

                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 68
                    anchors.margins: 10
                    spacing: 1

                    Text { width: parent.width; text: root.player ? root.player.trackTitle : "Not playing"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.player ? root.player.trackArtist : ""; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 11
                    spacing: 16

                    Text { text: "󰒮"; color: Local.Theme.secondaryText; font.family: Local.Theme.font; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: { if (root.player?.canGoPrevious) root.player.previous() } } }
                    Text { text: root.player?.isPlaying ? "󰏤" : "󰐊"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: { if (root.player?.canTogglePlaying) root.player.togglePlaying() } } }
                    Text { text: "󰒭"; color: Local.Theme.secondaryText; font.family: Local.Theme.font; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: { if (root.player?.canGoNext) root.player.next() } } }
                }
            }
            }

            Rectangle {
                id: soundCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: quickControls.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 14
                height: 62
                visible: root.page === "home"
                radius: 16
                color: Local.Theme.surface
                border.color: Local.Theme.accent
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Text { text: "󰕾  Sound"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 10; font.bold: true }
                    Components.Slider {
                        width: parent.width
                        height: 20
                        from: 0
                        to: 1
                        value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                        onMoved: { if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.volume = value }
                    }

                }
            }

            Rectangle {
                id: brightnessCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: soundCard.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 8
                height: 62
                visible: root.page === "home"
                radius: 16
                color: Local.Theme.surface
                border.color: Local.Theme.accent
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Text { text: "󰃠  Brightness"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 10; font.bold: true }
                    Components.Slider {
                        id: brightnessSlider
                        width: parent.width
                        height: 20
                        from: 1
                        to: 100
                        value: root.brightness
                        onMoved: {
                            root.brightness = value
                            actionProcess.command = ["brightnessctl", "set", Math.round(value) + "%"]
                            actionProcess.running = true
                        }
                    }
                }
            }

            Row {
                id: homeActions
                anchors.left: parent.left
                anchors.top: brightnessCard.bottom
                anchors.topMargin: 12
                anchors.leftMargin: 12
                spacing: 8
                visible: root.page === "home"

                ActionTile {
                    width: 174
                    height: 58
                    icon: "󰃭"
                    title: "Theme"
                    subtitle: Local.Theme.mode === "dark" ? "Dark" : "Light"
                    active: false
                    onActivated: {
                        actionProcess.command = ["sh", "-c", "$HOME/.config/scripts/theme-mode.sh " + (Local.Theme.mode === "dark" ? "light" : "dark")]
                        actionProcess.running = true
                    }
                }

                ActionTile {
                    width: 174
                    height: 58
                    icon: "󰹑"
                    title: "Screenshot"
                    subtitle: "Region copy"
                    active: false
                    onActivated: {
                        root.close()
                        actionProcess.command = [Quickshell.env("HOME") + "/.config/scripts/screenshot.sh", "region-clipboard"]
                        actionProcess.running = true
                    }
                }

            }

            WifiPanel { controlCenter: root }
            BluetoothPanel { controlCenter: root }
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }
}
