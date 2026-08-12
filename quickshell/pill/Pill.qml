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

    implicitHeight: 430
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: island }
    WlrLayershell.keyboardFocus: (themePickerOpen || wallpaperPickerOpen || clipboardPickerOpen || launcherOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
    property bool clipboardPickerOpen: false
    property var clipboardEntries: []
    property string clipboardQuery: ""
    property int clipboardIndex: 0
    property bool copiedNotice: false
    property int clipboardPreviewVersion: 0
    readonly property string clipboardPreviewDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard"
    property bool launcherOpen: false
    property string launcherQuery: ""
    property int launcherIndex: 0
    readonly property var applications: DesktopEntries.applications.values
    readonly property var filteredApplications: filterApplications(launcherQuery)
    readonly property var selectedApplication: filteredApplications.length > 0 ? filteredApplications[launcherIndex] : null
    readonly property var filteredClipboard: filterClipboard(clipboardQuery)
    readonly property var selectedClipboard: filteredClipboard.length > 0 ? filteredClipboard[clipboardIndex] : null
    readonly property bool expanded: themePickerOpen || wallpaperPickerOpen || clipboardPickerOpen || launcherOpen || (hasMedia && islandHover.hovered && !copiedNotice)

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

    function filterClipboard(query) {
        const needle = query.toLowerCase().trim()
        if (!needle)
            return clipboardEntries

        return clipboardEntries.map(entry => {
            const haystack = entry.label.toLowerCase()
            let cursor = 0
            let score = 0
            for (let i = 0; i < needle.length; i++) {
                const match = haystack.indexOf(needle[i], cursor)
                if (match < 0)
                    return null
                score += match - cursor
                cursor = match + 1
            }
            return { entry: entry, score: score }
        }).filter(result => result !== null).sort((left, right) => left.score - right.score).map(result => result.entry)
    }

    function filterApplications(query) {
        const needle = query.toLowerCase().trim()
        return applications.map(app => {
            const keywords = app.keywords ? app.keywords.join(" ") : ""
            const haystack = [app.name, app.genericName, app.comment, keywords].join(" ").toLowerCase()
            let cursor = 0
            let score = 0
            for (let i = 0; i < needle.length; i++) {
                const match = haystack.indexOf(needle[i], cursor)
                if (match < 0)
                    return null
                score += match - cursor
                cursor = match + 1
            }
            return { app: app, score: score }
        }).filter(result => result !== null).sort((left, right) => left.score - right.score).map(result => result.app)
    }

    function openLauncher() {
        launcherOpen = !launcherOpen
        if (launcherOpen) {
            themePickerOpen = false
            wallpaperPickerOpen = false
            clipboardPickerOpen = false
            launcherQuery = ""
            launcherIndex = 0
            launcherFocusTimer.restart()
        }
    }

    function moveLauncher(step) {
        if (filteredApplications.length > 0)
            launcherIndex = Math.max(0, Math.min(filteredApplications.length - 1, launcherIndex + step))
    }

    function launchApplication(application) {
        if (!application)
            return
        Quickshell.execDetached({ command: application.command, workingDirectory: application.workingDirectory })
        launcherOpen = false
    }

    onLauncherQueryChanged: launcherIndex = 0

    function openClipboardPicker() {
        clipboardPickerOpen = !clipboardPickerOpen
        if (clipboardPickerOpen) {
            themePickerOpen = false
            wallpaperPickerOpen = false
            clipboardQuery = ""
            clipboardIndex = 0
            clipboardEntries = []
            clipboardPreviewProcess.running = true
            clipboardFocusTimer.restart()
        }
    }

    onClipboardQueryChanged: clipboardIndex = 0

    function moveClipboard(step) {
        if (filteredClipboard.length > 0)
            clipboardIndex = Math.max(0, Math.min(filteredClipboard.length - 1, clipboardIndex + step))
    }

    function copyClipboard(entry) {
        if (!entry)
            return
        clipboardCopyProcess.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "clipboard-copy", entry.id]
        clipboardCopyProcess.running = true
        clipboardPickerOpen = false
        copiedNotice = true
        copiedNoticeTimer.restart()
    }

    Process {
        id: clipboardProcess
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.clipboardEntries = this.text.split("\n").map(line => {
                    const separator = line.indexOf("\t")
                    if (separator < 1)
                        return null
                    const label = line.slice(separator + 1)
                    return {
                        id: line.slice(0, separator),
                        label: label,
                        image: /^\[\[ binary data .* (png|jpe?g|gif|bmp|webp) /i.test(label),
                        preview: root.clipboardPreviewDir + "/" + line.slice(0, separator) + ".png"
                    }
                }).filter(entry => entry !== null)
                root.clipboardIndex = 0
                clipboardFocusTimer.restart()
            }
        }
    }

    Process {
        id: clipboardCopyProcess
    }

    Process {
        id: clipboardPreviewProcess
        command: [Quickshell.env("HOME") + "/.config/scripts/clipboard-preview.sh"]
        onExited: {
            root.clipboardPreviewVersion++
            clipboardProcess.running = true
        }
    }

    Timer {
        id: clipboardFocusTimer
        interval: 0
        onTriggered: clipboardSelector.focusSearch()
    }

    Timer {
        id: copiedNoticeTimer
        interval: 1500
        onTriggered: root.copiedNotice = false
    }

    Timer {
        id: launcherFocusTimer
        interval: 0
        onTriggered: appLauncher.focusSearch()
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

        function toggleClipboard(): void {
            root.openClipboardPicker()
        }

        function toggleLauncher(): void {
            root.openLauncher()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.themePickerOpen || root.wallpaperPickerOpen || root.clipboardPickerOpen || root.launcherOpen
        Keys.priority: Keys.BeforeItem

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.themePickerOpen = false
                root.wallpaperPickerOpen = false
                root.clipboardPickerOpen = false
                root.launcherOpen = false
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
            } else if (root.clipboardPickerOpen && event.key === Qt.Key_Up) {
                root.moveClipboard(-1)
                event.accepted = true
            } else if (root.clipboardPickerOpen && event.key === Qt.Key_Down) {
                root.moveClipboard(1)
                event.accepted = true
            } else if (root.clipboardPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.copyClipboard(root.selectedClipboard)
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

        readonly property real targetWidth: root.launcherOpen ? 520 : (root.clipboardPickerOpen ? 520 : (root.wallpaperPickerOpen ? 460 : (root.themePickerOpen ? 300 : (root.copiedNotice ? 112 : (root.hasMedia ? (root.expanded ? 360 : 260) : 92)))))
        readonly property real targetHeight: root.launcherOpen ? 400 : (root.clipboardPickerOpen ? 400 : (root.wallpaperPickerOpen ? 166 : (root.themePickerOpen ? 88 : (root.hasMedia ? (root.expanded ? 120 : 30) : 24))))
        readonly property real morphCloseness: {
            const distance = Math.max(Math.abs(width - targetWidth), Math.abs(height - targetHeight))
            return 1 - Math.min(1, distance / 100)
        }

        Behavior on width {
            NumberAnimation {
                duration: root.copiedNotice ? 150 : (root.themePickerOpen ? 250 : 420)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.copiedNotice ? 150 : (root.themePickerOpen ? 250 : 420)
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
            visible: !root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen && !root.clipboardPickerOpen && !root.launcherOpen && !root.copiedNotice
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
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen && !root.clipboardPickerOpen && !root.launcherOpen && !root.copiedNotice

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
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen && !root.clipboardPickerOpen && !root.launcherOpen && !root.copiedNotice
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
            visible: root.hasMedia && !root.themePickerOpen && !root.wallpaperPickerOpen && !root.clipboardPickerOpen && !root.launcherOpen && !root.copiedNotice

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

        ClipboardSelector {
            id: clipboardSelector
            pill: root
            morphCloseness: island.morphCloseness
        }

        AppLauncher {
            id: appLauncher
            pill: root
            morphCloseness: island.morphCloseness
        }

        Text {
            anchors.centerIn: parent
            visible: root.copiedNotice && !root.clipboardPickerOpen
            text: "󰄬  Copied!"
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 11
            font.bold: true
        }
    }
}
