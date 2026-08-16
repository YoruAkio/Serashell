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

    implicitHeight: Math.ceil(9 + 400 * Math.max(1, Local.Settings.launcherPanelSize / 100, Local.Settings.clipboardPanelSize / 100))
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: dismissArea.visible ? dismissArea : island }
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var player: {
        const players = Mpris.players.values
        return players.find(player => player.isPlaying) || players[0] || null
    }
    readonly property bool hasMedia: player && player.trackTitle !== ""
    readonly property bool idleMedia: !hasMedia
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
    property bool pillNotification: false
    property string pillNotificationIcon: ""
    property string pillNotificationText: ""
    property color pillNotificationColor: Local.Theme.danger
    property real pillNotificationWidth: 110
    property int clipboardPreviewVersion: 0
    readonly property string clipboardPreviewDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard"
    property bool launcherOpen: false
    property string launcherQuery: ""
    property int launcherIndex: 0
    property var launcherUsage: ({})
    readonly property string launcherUsagePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/serashell/app-launcher-usage"
    readonly property var applications: DesktopEntries.applications.values
    readonly property var filteredApplications: filterApplications(launcherQuery)
    readonly property var selectedApplication: filteredApplications.length > 0 ? filteredApplications[launcherIndex] : null
    property bool calendarOpen: false
    property bool systemOpen: false
    property bool emojiPickerOpen: false
    property bool recorderOpen: false
    property bool recording: false
    property var recordActions: []
    property int recordIndex: 0
    property int emojiIndex: 0
    property string emojiQuery: ""
    property var emojiEntries: []
    readonly property string emojiDataPath: Quickshell.env("HOME") + "/.config/quickshell/pill/data/emoji-test.txt"
    readonly property var filteredEmojis: emojiEntries.filter(entry => entry.name.toLowerCase().includes(emojiQuery.toLowerCase().trim()) || entry.emoji.includes(emojiQuery.trim()))
    property date calendarMonth: new Date()
    readonly property var filteredClipboard: filterClipboard(clipboardQuery)
    readonly property var selectedClipboard: filteredClipboard.length > 0 ? filteredClipboard[clipboardIndex] : null
    readonly property bool expanded: panelOpen || ((hasMedia || idleMedia) && islandHover.hovered && !pillNotification)
    readonly property bool panelOpen: themePickerOpen || wallpaperPickerOpen || clipboardPickerOpen || launcherOpen || calendarOpen || systemOpen || emojiPickerOpen || recorderOpen

    function closePanels() {
        themePickerOpen = false
        wallpaperPickerOpen = false
        clipboardPickerOpen = false
        launcherOpen = false
        calendarOpen = false
        systemOpen = false
        emojiPickerOpen = false
        recorderOpen = false
        emojiEntries = []
    }

    // @note short-lived pill notification; width is the extra width beyond the idle pill
    function showPillNotification(text, icon, color, width) {
        pillNotificationText = text
        pillNotificationIcon = icon !== undefined ? icon : ""
        pillNotificationColor = color !== undefined ? color : Local.Theme.danger
        pillNotificationWidth = width !== undefined ? width : 110
        pillNotification = true
        pillNotificationTimer.restart()
    }

    function togglePanel(panel) {
        const alreadyOpen = (panel === "theme" && themePickerOpen)
                || (panel === "wallpaper" && wallpaperPickerOpen)
                || (panel === "clipboard" && clipboardPickerOpen)
                || (panel === "launcher" && launcherOpen)
                || (panel === "calendar" && calendarOpen)
                || (panel === "system" && systemOpen)
                || (panel === "emoji" && emojiPickerOpen)
                || (panel === "recorder" && recorderOpen)
        closePanels()
        if (alreadyOpen)
            return
        if (panel === "theme") themePickerOpen = true
        else if (panel === "wallpaper") wallpaperPickerOpen = true
        else if (panel === "clipboard") clipboardPickerOpen = true
        else if (panel === "launcher") launcherOpen = true
        else if (panel === "calendar") calendarOpen = true
        else if (panel === "system") systemOpen = true
        else if (panel === "emoji") emojiPickerOpen = true
        else if (panel === "recorder") recorderOpen = true
    }

    function openRecorder() {
        togglePanel("recorder")
        if (recorderOpen) {
            recordActions = []
            recordIndex = 0
            recorderListProcess.running = true
        }
    }

    function runRecorderAction(action) {
        if (!action)
            return
        if (action.mode === "stop") {
            root.recording = false
            Quickshell.execDetached({
                command: ["sh", "-c", "pkill -INT -x wf-recorder", "serashell-recorder"]
            })
            root.showPillNotification("Recording Stopped", "", Local.Theme.danger, 70)
        } else {
            root.recording = true
            Quickshell.execDetached({
                command: ["sh", "-c", "mkdir -p \"$HOME/Videos/Screenrecord\"; output=\"$HOME/Videos/Screenrecord/$(date '+%H-%M-%S_%d-%m-%y').mp4\"; audio=--audio; if command -v pactl >/dev/null; then source=\"$(pactl get-default-sink 2>/dev/null).monitor\"; [ -n \"$source\" ] && audio=\"--audio=$source\"; fi; setsid -f wf-recorder -o \"$1\" \"$audio\" -f \"$output\" </dev/null >\"${XDG_RUNTIME_DIR:-/tmp}/serashell-recording.log\" 2>&1; sleep 0.3; pgrep -x wf-recorder >/dev/null", "serashell-recorder", action.value]
            })
            root.showPillNotification("Recording Started", "", Local.Theme.danger, 70)
        }
        closePanels()
    }

    Process {
        id: recorderListProcess
        command: ["sh", "-c", "if pgrep -x wf-recorder >/dev/null; then printf 'stop\\tStop recording\\tFinalize the current recording\\n'; else hyprctl monitors -j | jq -r '.[].name' | while IFS= read -r output; do [ -n \"$output\" ] && printf 'output\\t%s\\tRecord monitor %s\\n' \"$output\" \"$output\"; done; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.recordActions = this.text.trim().split("\n").filter(line => line).map(line => {
                    const fields = line.split("\t")
                    return {
                        mode: fields[0],
                        value: fields[0] === "output" ? fields[1] : "",
                        label: fields[1],
                        description: fields[2]
                    }
                })
                root.recordIndex = 0
            }
        }
    }


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

    Process {
        id: settingsProcess
        command: ["qs", "ipc", "call", "pillSettings", "toggle"]
    }

    function openWallpaperPicker() {
        togglePanel("wallpaper")
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
            return { app: app, score: score, usage: launcherUsage[app.id] || 0 }
        }).filter(result => result !== null).sort((left, right) => left.score - right.score || right.usage - left.usage || left.app.name.localeCompare(right.app.name)).map(result => result.app)
    }

    function openLauncher() {
        togglePanel("launcher")
        if (launcherOpen) {
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
        const usage = Object.assign({}, launcherUsage)
        usage[application.id] = (usage[application.id] || 0) + 1
        launcherUsage = usage
        launcherUsageProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\"; touch \"$1\"; tmp=$(mktemp \"${1}.XXXXXX\") || exit 1; awk -F '\\t' -v id=\"$2\" 'BEGIN { found=0 } $1 == id { print id \"\\t\" ($2 + 1); found=1; next } NF { print } END { if (!found) print id \"\\t1\" }' \"$1\" > \"$tmp\" && mv \"$tmp\" \"$1\"", "launcher-usage", launcherUsagePath, application.id]
        launcherUsageProcess.running = true
        Quickshell.execDetached({ command: application.command, workingDirectory: application.workingDirectory })
        launcherOpen = false
    }

    FileView {
        path: root.launcherUsagePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            const usage = {}
            const lines = text().trim().split("\n")
            for (let i = 0; i < lines.length; i++) {
                const fields = lines[i].split("\t")
                if (fields.length === 2 && fields[0])
                    usage[fields[0]] = Math.max(0, Number(fields[1]) || 0)
            }
            root.launcherUsage = usage
        }
        onFileChanged: reload()
    }

    Process { id: launcherUsageProcess }

    function openCalendar() {
        togglePanel("calendar")
        if (calendarOpen) {
            calendarMonth = new Date()
        }
    }

    function openSystem() {
        togglePanel("system")
    }

    onLauncherQueryChanged: launcherIndex = 0

    function openClipboardPicker() {
        togglePanel("clipboard")
        if (clipboardPickerOpen) {
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
        showPillNotification("Copied!", "󰄬", Local.Theme.success, 110)
    }

    function openEmojiPicker() {
        togglePanel("emoji")
        if (emojiPickerOpen) {
            emojiQuery = ""
            emojiIndex = 0
            emojiDataProcess.running = true
            emojiFocusTimer.restart()
        }
    }

    function moveEmoji(horizontal, vertical) {
        const next = emojiIndex + horizontal + vertical * 6
        emojiIndex = Math.max(0, Math.min(filteredEmojis.length - 1, next))
    }

    function copyEmoji(entry) {
        if (!entry)
            return
        emojiCopyProcess.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "emoji-copy", entry.emoji]
        emojiCopyProcess.running = true
        emojiPickerOpen = false
        showPillNotification("Emoji Copied!", "󰄬", Local.Theme.success, 150)
    }

    Process { id: emojiCopyProcess }

    Process {
        id: emojiDataProcess
        command: ["sh", "-c", "awk '/; fully-qualified/ { split($0, a, \"# \"); emoji = a[2]; sub(/ E[0-9.]+ .*/, \"\", emoji); name = a[2]; sub(/^.* E[0-9.]+ /, \"\", name); printf \"%s\\t%s\\n\", emoji, name }' \"$1\"", "emoji-data", root.emojiDataPath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.emojiPickerOpen)
                    return
                root.emojiEntries = this.text.trim().split("\n").map(line => {
                    const separator = line.indexOf("\t")
                    return separator > 0 ? { emoji: line.slice(0, separator), name: line.slice(separator + 1) } : null
                }).filter(entry => entry !== null)
            }
        }
    }

    onEmojiQueryChanged: emojiIndex = 0

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
        onTriggered: clipboardLoader.item?.focusSearch()
    }

    Timer {
        id: pillNotificationTimer
        interval: 1500
        onTriggered: root.pillNotification = false
    }

    Timer {
        id: launcherFocusTimer
        interval: 0
        onTriggered: launcherLoader.item?.focusSearch()
    }

    Timer {
        id: emojiFocusTimer
        interval: 0
        onTriggered: emojiLoader.item?.focusSearch()
    }

    IpcHandler {
        target: "pill"

        function toggleTheme(): void {
            root.togglePanel("theme")
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

        function toggleEmoji(): void {
            root.openEmojiPicker()
        }

        function toggleRecorder(): void {
            root.openRecorder()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.panelOpen
        Keys.priority: Keys.BeforeItem

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closePanels()
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
            } else if (root.emojiPickerOpen && event.key === Qt.Key_Left) {
                root.moveEmoji(-1, 0)
                event.accepted = true
            } else if (root.emojiPickerOpen && event.key === Qt.Key_Right) {
                root.moveEmoji(1, 0)
                event.accepted = true
            } else if (root.emojiPickerOpen && event.key === Qt.Key_Up) {
                root.moveEmoji(0, -1)
                event.accepted = true
            } else if (root.emojiPickerOpen && event.key === Qt.Key_Down) {
                root.moveEmoji(0, 1)
                event.accepted = true
            } else if (root.emojiPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.copyEmoji(root.filteredEmojis[root.emojiIndex])
                event.accepted = true
            } else if (root.recorderOpen && event.key === Qt.Key_Up) {
                root.recordIndex = Math.max(0, root.recordIndex - 1)
                event.accepted = true
            } else if (root.recorderOpen && event.key === Qt.Key_Down) {
                root.recordIndex = Math.min(root.recordActions.length - 1, root.recordIndex + 1)
                event.accepted = true
            } else if (root.recorderOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.runRecorderAction(root.recordActions[root.recordIndex])
                event.accepted = true
            }
        }
    }

    Item {
        id: dismissArea
        anchors.fill: parent
        visible: root.panelOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanels()
        }
    }

    NotchShoulder {
        visible: Local.Settings.notchMode
        concaveLeft: true
        shoulderSize: 18
        fill: Local.Theme.background
        anchors.right: island.left
        anchors.rightMargin: -1
        anchors.top: island.top
    }

    NotchShoulder {
        visible: Local.Settings.notchMode
        concaveLeft: false
        shoulderSize: 18
        fill: Local.Theme.background
        anchors.left: island.right
        anchors.leftMargin: -1
        anchors.top: island.top
    }

    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Local.Settings.notchMode ? 0 : 8
        width: targetWidth
        height: targetHeight
        radius: Local.Settings.pillRadius
        topLeftRadius: Local.Settings.notchMode ? 0 : radius
        topRightRadius: Local.Settings.notchMode ? 0 : radius
        bottomLeftRadius: radius
        bottomRightRadius: radius
        color: Local.Theme.background
        border.color: Local.Theme.accent
        border.width: Local.Settings.notchMode ? 0 : 1
        clip: true

        readonly property real idleWidth: Local.Settings.notchMode || root.hasMedia ? 260 : 180
        readonly property real targetWidth: {
            if (root.systemOpen) return 520
            if (root.launcherOpen) return 520 * Local.Settings.launcherPanelSize / 100
            if (root.clipboardPickerOpen) return 520 * Local.Settings.clipboardPanelSize / 100
            if (root.emojiPickerOpen) return 430
            if (root.recorderOpen) return 360
            if (root.calendarOpen) return 340
            if (root.wallpaperPickerOpen) return 460 * Local.Settings.wallpaperPanelSize / 100
            if (root.themePickerOpen) return 340 * Local.Settings.themePanelSize / 100
            if (root.pillNotification) return idleWidth + root.pillNotificationWidth
            if (Local.Settings.notchMode) return root.expanded ? 420 * Local.Settings.mediaPanelSize / 100 : 260
            if (root.hasMedia) return root.expanded ? 420 * Local.Settings.mediaPanelSize / 100 : 260
            if (root.idleMedia) return root.expanded ? 420 * Local.Settings.mediaPanelSize / 100 : 180
            return 180
        }
        readonly property real targetHeight: {
            if (root.systemOpen) return 340
            if (root.calendarOpen) return 300
            if (root.launcherOpen) return 400 * Local.Settings.launcherPanelSize / 100
            if (root.clipboardPickerOpen) return 400 * Local.Settings.clipboardPanelSize / 100
            if (root.emojiPickerOpen) return 376
            if (root.recorderOpen) return Math.max(86, 42 + root.recordActions.length * 46)
            if (root.wallpaperPickerOpen) return 166 * Local.Settings.wallpaperPanelSize / 100
            if (root.themePickerOpen) return 100 * Local.Settings.themePanelSize / 100
            if (Local.Settings.notchMode) return root.expanded ? 180 * Local.Settings.mediaPanelSize / 100 : 36
            if (root.hasMedia) return root.expanded ? 180 * Local.Settings.mediaPanelSize / 100 : 30
            if (root.idleMedia) return root.expanded ? 180 * Local.Settings.mediaPanelSize / 100 : 30
            return 30
        }
        readonly property real morphCloseness: {
            const distance = Math.max(Math.abs(width - targetWidth), Math.abs(height - targetHeight))
            return 1 - Math.min(1, distance / 100)
        }

        Behavior on width {
            NumberAnimation {
                duration: root.pillNotification ? 150 : (root.themePickerOpen ? 250 : 420)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.pillNotification ? 150 : (root.themePickerOpen ? 250 : 420)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }

        HoverHandler {
            id: islandHover
        }

        component Art: ClippingRectangle {
            id: artFrame
            required property string artSource
            property real cornerRadius: 8

            radius: cornerRadius
            color: Local.Theme.accent

            Image {
                anchors.fill: parent
                source: artFrame.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true

                Rectangle {
                    anchors.fill: parent
                    radius: artFrame.radius
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
            property bool highlighted: false
            property real contentScale: 1
            signal activated()

            width: (highlighted ? 24 : 28) * contentScale
            height: (highlighted ? 24 : 28) * contentScale
            radius: height / 2
            color: highlighted ? Local.Theme.surface : (controlMouse.containsMouse ? Local.Theme.accent : "transparent")
            opacity: enabled ? 1 : 0.35

            Text {
                anchors.centerIn: parent
                text: parent.icon
                color: highlighted ? Local.Theme.highlight : Local.Theme.secondaryText
                font.family: Local.Theme.font
                font.pixelSize: 15 * parent.contentScale
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
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.hasMedia && !root.expanded && !root.themePickerOpen && !root.wallpaperPickerOpen && !root.clipboardPickerOpen && !root.launcherOpen && !root.calendarOpen && !root.systemOpen && !root.emojiPickerOpen && !root.pillNotification
            text: ""
            color: root.recording ? Local.Theme.danger : Local.Theme.subtleMuted
            font.family: Local.Theme.font
            font.pixelSize: 16
        }

        Art {
            id: compactArt
            width: 24
            height: width
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: Local.Settings.notchMode ? 6 : 3
            artSource: root.player ? root.player.trackArtUrl : ""
            cornerRadius: width / 2
            opacity: root.expanded ? 0 : 1
            visible: root.hasMedia && !root.panelOpen && !root.pillNotification

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
            visible: root.hasMedia && !root.panelOpen && !root.pillNotification
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
            anchors.topMargin: 12 * contentScale
            height: parent.height - anchors.topMargin
            readonly property real contentScale: Math.min(parent.width / 420, parent.height / 180)
            opacity: root.expanded ? island.morphCloseness : 0
            visible: (root.hasMedia || root.idleMedia) && !root.panelOpen && !root.pillNotification

            Behavior on opacity {
                NumberAnimation { duration: 50 }
            }

            Art {
                width: 100 * details.contentScale
                height: width
                anchors.left: parent.left
                anchors.leftMargin: 12 * details.contentScale
                anchors.top: parent.top
                anchors.topMargin: 38 * details.contentScale
                artSource: root.player ? root.player.trackArtUrl : ""
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 126 * details.contentScale
                anchors.right: parent.right
                anchors.rightMargin: 12 * details.contentScale
                anchors.top: parent.top
                anchors.topMargin: 40 * details.contentScale
                spacing: 3 * details.contentScale

                Text {
                    width: parent.width
                    text: root.hasMedia ? root.player.trackTitle : "No Media Running"
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 11 * details.contentScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.hasMedia ? root.player.trackArtist : "No Author"
                    color: Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 9 * details.contentScale
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8 * details.contentScale
                spacing: 10 * details.contentScale

                Control {
                    icon: "󰒮"
                    enabled: root.player?.canGoPrevious ?? false
                    contentScale: details.contentScale
                    onActivated: root.player.previous()
                }

                Control {
                    icon: root.player?.isPlaying ? "󰏤" : "󰐊"
                    enabled: root.player?.canTogglePlaying ?? false
                    contentScale: details.contentScale
                    onActivated: root.player.togglePlaying()
                }

                Control {
                    icon: "󰒭"
                    enabled: root.player?.canGoNext ?? false
                    contentScale: details.contentScale
                    onActivated: root.player.next()
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8 * details.contentScale
                anchors.top: parent.top
                spacing: 2 * details.contentScale

                Control {
                    icon: "󰃭"
                    enabled: true
                    highlighted: true
                    contentScale: details.contentScale
                    onActivated: root.openCalendar()
                }

                Control {
                    icon: "󰍛"
                    enabled: true
                    highlighted: true
                    contentScale: details.contentScale
                    onActivated: root.openSystem()
                }
            }

            Control {
                anchors.right: parent.right
                anchors.rightMargin: 10 * details.contentScale
                anchors.top: parent.top
                icon: "󰒓"
                enabled: true
                highlighted: true
                contentScale: details.contentScale
                onActivated: settingsProcess.running = true
            }
        }

        Loader {
            active: root.themePickerOpen
            anchors.fill: parent
            sourceComponent: Component { ThemeSelector { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            active: root.wallpaperPickerOpen
            anchors.fill: parent
            sourceComponent: Component { WallpaperSelector { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            id: clipboardLoader
            active: root.clipboardPickerOpen
            anchors.fill: parent
            sourceComponent: Component { ClipboardSelector { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            id: launcherLoader
            active: root.launcherOpen
            anchors.fill: parent
            sourceComponent: Component { AppLauncher { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            active: root.calendarOpen
            anchors.fill: parent
            sourceComponent: Component { CalendarPanel { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            active: root.systemOpen
            anchors.fill: parent
            sourceComponent: Component { SystemPanel { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            id: emojiLoader
            active: root.emojiPickerOpen
            anchors.fill: parent
            sourceComponent: Component { EmojiSelector { pill: root; morphCloseness: island.morphCloseness } }
        }

        Loader {
            active: root.recorderOpen
            anchors.fill: parent
            sourceComponent: Component { RecorderPanel { pill: root; morphCloseness: island.morphCloseness } }
        }


        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pillNotification && !root.clipboardPickerOpen && !root.emojiPickerOpen
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pillNotificationIcon !== ""
                text: root.pillNotificationIcon
                color: root.pillNotificationColor
                font.family: Local.Theme.font
                font.pixelSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.pillNotificationText
                color: Local.Theme.text
                font.family: Local.Theme.font
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
