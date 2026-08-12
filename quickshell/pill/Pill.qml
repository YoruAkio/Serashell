import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons" as Local

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 188
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: island }
    WlrLayershell.keyboardFocus: (themePickerOpen || wallpaperPickerOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var player: {
        const players = Mpris.players.values
        return players.find(player => player.isPlaying) || players[0] || null
    }
    readonly property bool hasMedia: player && player.trackTitle !== ""
    property bool themePickerOpen: false
    readonly property var themeModes: ["dark", "light"]
    property int themeIndex: 0
    property bool wallpaperPickerOpen: false
    property var wallpapers: []
    property int wallpaperIndex: 0
    readonly property string wallDir: Quickshell.env("HOME") + "/.wall"
    readonly property string selectedWallpaper: wallpapers.length > 0 ? wallpapers[wallpaperIndex] : ""
    readonly property bool expanded: themePickerOpen || wallpaperPickerOpen || (hasMedia && islandHover.hovered)

    function applyTheme(mode) {
        themeProcess.mode = mode
        themeProcess.running = true
        themePickerOpen = false
    }

    Process {
        id: themeProcess
        property string mode: "dark"
        command: ["sh", "-c", "$HOME/.config/scripts/theme-mode.sh " + mode]
    }

    function openWallpaperPicker() {
        wallpaperPickerOpen = !wallpaperPickerOpen
        if (wallpaperPickerOpen)
            wallpaperProcess.running = true
    }

    function moveWallpaper(step) {
        if (wallpapers.length > 0)
            wallpaperIndex = Math.max(0, Math.min(wallpapers.length - 1, wallpaperIndex + step))
    }

    function applyWallpaper(name) {
        if (!name)
            return
        wallpaperApplyProcess.command = [Quickshell.env("HOME") + "/.config/scripts/set-wallpaper.sh", wallDir + "/" + name]
        wallpaperApplyProcess.running = true
        wallpaperPickerOpen = false
    }

    Process {
        id: wallpaperProcess
        command: ["sh", "-c", "{ cat \"$HOME/.wall/.current\" 2>/dev/null || true; printf '\\n'; find -L \"$HOME/.wall\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \\) ! -name '.*' -printf '%f\\n' | sort; }"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const current = lines.shift()
                root.wallpapers = lines.filter(name => name)
                root.wallpaperIndex = Math.max(0, root.wallpapers.indexOf(current))
            }
        }
    }

    Process {
        id: wallpaperApplyProcess
    }

    IpcHandler {
        target: "pill"

        function toggleTheme(): void {
            root.themePickerOpen = !root.themePickerOpen
            if (root.themePickerOpen)
                root.themeIndex = Math.max(0, root.themeModes.indexOf(Local.Theme.mode))
        }

        function toggleWallpaper(): void {
            root.openWallpaperPicker()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.themePickerOpen || root.wallpaperPickerOpen

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.themePickerOpen = false
                root.wallpaperPickerOpen = false
                event.accepted = true
            } else if (root.themePickerOpen && event.key === Qt.Key_Left) {
                root.themeIndex = Math.max(0, root.themeIndex - 1)
                event.accepted = true
            } else if (root.themePickerOpen && event.key === Qt.Key_Right) {
                root.themeIndex = Math.min(root.themeModes.length - 1, root.themeIndex + 1)
                event.accepted = true
            } else if (root.themePickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.applyTheme(root.themeModes[root.themeIndex])
                event.accepted = true
            } else if (root.wallpaperPickerOpen && event.key === Qt.Key_Left) {
                root.moveWallpaper(-1)
                event.accepted = true
            } else if (root.wallpaperPickerOpen && event.key === Qt.Key_Right) {
                root.moveWallpaper(1)
                event.accepted = true
            } else if (root.wallpaperPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.applyWallpaper(root.selectedWallpaper)
                event.accepted = true
            }
        }
    }

    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: targetWidth
        height: targetHeight
        radius: 15
        color: Local.Theme.background
        border.color: Local.Theme.accent
        border.width: 1
        clip: true

        readonly property real targetWidth: root.wallpaperPickerOpen ? 460 : (root.themePickerOpen ? 300 : (root.hasMedia ? (root.expanded ? 360 : 260) : 92))
        readonly property real targetHeight: root.wallpaperPickerOpen ? 166 : (root.themePickerOpen ? 88 : (root.hasMedia ? (root.expanded ? 120 : 30) : 24))
        readonly property real morphCloseness: {
            const distance = Math.max(Math.abs(width - targetWidth), Math.abs(height - targetHeight))
            return 1 - Math.min(1, distance / 100)
        }

        Behavior on width {
            NumberAnimation {
                duration: root.themePickerOpen ? 250 : 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.themePickerOpen ? 250 : 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }

        HoverHandler {
            id: islandHover
        }

        component Art: Rectangle {
            required property string source

            radius: width / 2
            color: Local.Theme.accent
            clip: true

            Image {
                anchors.fill: parent
                source: parent.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Local.Theme.accent
                    visible: parent.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        color: Local.Theme.highlight
                        font.family: Local.Theme.font
                        font.pixelSize: 16
                    }
                }
            }
        }

        component Control: Rectangle {
            required property string icon
            required property bool enabled
            signal activated()

            width: 28
            height: 28
            radius: height / 2
            color: controlMouse.containsMouse ? Local.Theme.accent : "transparent"
            opacity: enabled ? 1 : 0.35

            Text {
                anchors.centerIn: parent
                text: parent.icon
                color: Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 15
            }

            MouseArea {
                id: controlMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.enabled
                onClicked: parent.activated()
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen
            text: "●  ●"
            color: Local.Theme.subtleMuted
            font.family: Local.Theme.font
            font.pixelSize: 9
        }

        Art {
            id: compactArt
            width: 24
            height: width
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 3
            source: root.player ? root.player.trackArtUrl : ""
            opacity: root.expanded ? 0 : 1
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Text {
            anchors.left: compactArt.right
            anchors.leftMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: compactArt.verticalCenter
            opacity: root.expanded ? 0 : 1
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen
            text: root.player ? root.player.trackTitle : ""
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Item {
            id: details
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 12
            height: 96
            opacity: root.expanded ? island.morphCloseness : 0
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen

            Behavior on opacity {
                NumberAnimation { duration: 50 }
            }

            Art {
                width: 54
                height: width
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 0
                source: root.player ? root.player.trackArtUrl : ""
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 78
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 2
                spacing: 3

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackTitle : ""
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackArtist : ""
                    color: Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 10

                Control {
                    icon: "󰒮"
                    enabled: root.player?.canGoPrevious ?? false
                    onActivated: root.player.previous()
                }

                Control {
                    icon: root.player?.isPlaying ? "󰏤" : "󰐊"
                    enabled: root.player?.canTogglePlaying ?? false
                    onActivated: root.player.togglePlaying()
                }

                Control {
                    icon: "󰒭"
                    enabled: root.player?.canGoNext ?? false
                    onActivated: root.player.next()
                }
            }
        }

        ThemeSelector {
            pill: root
            morphCloseness: island.morphCloseness
        }

        WallpaperSelector {
            pill: root
            morphCloseness: island.morphCloseness
        }
    }
}
