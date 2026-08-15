import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons" as Local

PanelWindow {
    id: root

    // @note full-screen transparent overlay, completely click-through
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Local.Settings.keystrokeEnabled
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "keystroke-overlay"


    // @note inverted theme colors: light background on dark mode, dark background on light mode
    readonly property color boxBg: Local.Theme.light ? "#352B2D" : "#F1DBC2"
    readonly property color boxBorder: Local.Theme.light ? "#4B3D43" : "#CCB7A0"
    readonly property color boxText: Local.Theme.light ? "#F1DBC2" : "#352B2D"
    readonly property color boxAccent: Local.Theme.light ? "#DFC8B1" : "#44373A"
    readonly property color boxMuted: Local.Theme.light ? "#AA9D8A" : "#625458"

    readonly property real scaleFactor: Local.Settings.keystrokeSize / 100
    readonly property int fadeTimeMs: Local.Settings.keystrokeFadeTime * 1000
    readonly property bool fullMode: Local.Settings.keystrokeMode === "full"

    // @note special keys drawn as svg badges instead of text glyphs
    function svgSource(key) {
        const svgKeys = ["Tab", "Caps", "PgUp", "PgDn", "Home", "End", "Ins"]
        return svgKeys.includes(key) ? "assets/key_" + key.toLowerCase() + ".svg" : ""
    }

    // @note state buffers
    property string textBuffer: ""
    property var activeModifiers: []
    // @note ordered modifier display list; released mods linger briefly before clearing
    property var shownModifiers: []
    // @note chronological segments for full mode: {kind: "mod"|"special"|"text", key?}
    property var fullSegments: []
    property string activeSpecial: ""
    property real containerOpacity: 0
    property real containerScale: 1
    property int maxBufferLength: 40

    function handleKeyPress(msg) {
        // @note reset fade timer on any key activity
        fadeTimer.stop()
        containerOpacity = 1
        containerScale = 1

        const key = msg.key
        const isMod = msg.modifier
        const isChar = msg.is_char

        if (isMod) {
            // @note only on the initial press; os key-repeat must not stack duplicate badges
            if (!activeModifiers.includes(key)) {
                let updated = activeModifiers.slice()
                updated.push(key)
                activeModifiers = updated
                pushSegment("mod", key)
            }
            // @note linger list for separate mode
            if (!shownModifiers.includes(key)) {
                let shown = shownModifiers.slice()
                shown.push(key)
                shownModifiers = shown
            }
            fadeTimer.restart()
            return
        }

        // @note backspace appends one ⌫; consecutive presses collapse into the same icon
        // ponytail: no String.trimEnd in quickshell's js engine, strip trailing spaces via regex
        if (key === "Backspace") {
            if (!textBuffer.replace(/\s+$/, "").endsWith("⌫")) {
                appendChar(textBuffer.length > 0 && !textBuffer.endsWith(" ") ? " ⌫ " : "⌫ ")
            }
            fadeTimer.restart()
            return
        }

        if (key === "Tab") {
            activeSpecial = "Tab"
            pushSegment("special", "Tab")
            if (activeModifiers.length === 0) specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        if (key === "Enter") {
            activeSpecial = "↵"
            pushSegment("special", "↵")
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        if (key === "Esc") {
            activeSpecial = "Esc"
            pushSegment("special", "Esc")
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        if (key === "Space") {
            if (activeModifiers.length > 0) {
                activeSpecial = "Space"
                pushSegment("special", "Space")
                specialClearTimer.restart()
            } else {
                appendChar(" ")
            }
            fadeTimer.restart()
            return
        }

        // @note if modifiers are active (like Ctrl+C, Super+D, Alt+F4), show as combo
        if (activeModifiers.length > 0) {
            activeSpecial = key
            pushSegment("special", key)
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        // @note regular typing: append character into unified buffer
        if (isChar || key.length === 1) {
            appendChar(key)
        } else {
            activeSpecial = key
            pushSegment("special", key)
            specialClearTimer.restart()
        }

        fadeTimer.restart()
    }

    function appendChar(ch) {
        let buf = textBuffer + ch
        if (buf.length > maxBufferLength) {
            buf = buf.slice(buf.length - maxBufferLength)
        }
        textBuffer = buf
        // @note full mode keeps typed text as the trailing segment
        if (fullMode) {
            let segs = fullSegments.slice()
            if (segs.length > 0 && segs[segs.length - 1].kind === "text") {
                segs[segs.length - 1] = { kind: "text", key: buf }
            } else {
                segs.push({ kind: "text", key: buf })
            }
            fullSegments = segs
        }
    }

    // @note full mode records keys in press order so "d then shift" renders as d [shift]
    function pushSegment(kind, key) {
        if (!fullMode) return
        let segs = fullSegments.slice()
        segs.push({ kind: kind, key: key })
        fullSegments = segs
    }

    function handleKeyRelease(msg) {
        const key = msg.key
        if (msg.modifier) {
            let updated = activeModifiers.filter(m => m !== key)
            activeModifiers = updated
            // @note keep the released modifier visible briefly instead of vanishing instantly
            modLingerTimer.restart()
        }
        fadeTimer.restart()
    }

    Timer {
        id: specialClearTimer
        interval: 1500
        onTriggered: root.activeSpecial = ""
    }

    Timer {
        id: modLingerTimer
        interval: 1500
        onTriggered: {
            // @note drop any modifier that is no longer physically held
            root.shownModifiers = root.activeModifiers.slice()
            if (root.fullMode) {
                const held = root.activeModifiers
                root.fullSegments = root.fullSegments.filter(seg => seg.kind !== "mod" || held.includes(seg.key))
            }
        }
    }

    Timer {
        id: fadeTimer
        interval: root.fadeTimeMs
        onTriggered: {
            fadeAnimation.start()
        }
    }

    SequentialAnimation {
        id: fadeAnimation
        ParallelAnimation {
            NumberAnimation { target: root; property: "containerOpacity"; to: 0; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "containerScale"; to: 0.94; duration: 320; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                root.textBuffer = ""
                root.activeSpecial = ""
                root.activeModifiers = []
                root.shownModifiers = []
                root.fullSegments = []
            }
        }
    }

    Process {
        id: keystrokeProcess
        command: ["python3", Qt.resolvedUrl("lib/keystroke_listener.py").toString().replace("file://", "")]
        running: Local.Settings.keystrokeEnabled

        stdout: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data)
                    if (msg.type === "press") {
                        root.handleKeyPress(msg)
                    } else if (msg.type === "release") {
                        root.handleKeyRelease(msg)
                    }
                } catch (e) {}
            }
        }

        onExited: {
            if (Local.Settings.keystrokeEnabled) {
                restartTimer.restart()
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: {
            if (Local.Settings.keystrokeEnabled) {
                keystrokeProcess.running = true
            }
        }
    }

    Item { id: clickHole; width: 0; height: 0 }
    mask: Region { item: clickHole }

    // @note position constants derived from settings
    readonly property var position: Local.Settings.keystrokePosition
    readonly property bool topSide: position.startsWith("top-")
    readonly property bool bottomSide: position.startsWith("bottom-")
    readonly property bool leftSide: position.endsWith("-left")
    readonly property bool rightSide: position.endsWith("-right")
    readonly property bool centerSide: position.endsWith("-center")

    Item {
        id: screenCanvas
        anchors.fill: parent
        width: root.width > 0 ? root.width : Screen.width
        height: root.height > 0 ? root.height : Screen.height

        Row {
            id: contentRow
            spacing: Math.round(8 * root.scaleFactor)
            opacity: root.containerOpacity
            scale: root.containerScale
            visible: root.shownModifiers.length > 0 || root.activeSpecial.length > 0 || root.textBuffer.length > 0 || root.fullSegments.length > 0

            // @note compute x/y directly instead of toggling anchor lines at runtime;
            // clearing anchors via undefined leaves conflicting lines that break positioning
            x: root.leftSide ? 8 : root.rightSide ? screenCanvas.width - width - 8 : (screenCanvas.width - width) / 2
            y: root.topSide ? 46 : screenCanvas.height - height - 8

            Behavior on opacity {
                enabled: !fadeAnimation.running
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: !fadeAnimation.running
                NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            // @note full mode: chronological segments in one compact box, modifiers as svg icons
            Rectangle {
                visible: root.fullMode && root.fullSegments.length > 0
                // @note cap to the screen so a long buffer never stretches the box full width
                width: Math.min(fullRow.width + Math.round(20 * root.scaleFactor), screenCanvas.width - 16)
                height: Math.round(40 * root.scaleFactor)
                radius: Math.round(10 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1
                clip: true

                Row {
                    id: fullRow
                    // @note position via x/y, not anchors, so the box width can depend on the row width
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    spacing: Math.round(6 * root.scaleFactor)

                    Repeater {
                        model: root.fullSegments

                        delegate: Item {
                            required property var modelData
                            // @note modifiers and badged specials (tab, caps, pgup...) render as svg
                            readonly property string svg: modelData.kind === "mod" ? "assets/key_" + modelData.key.toLowerCase() + ".svg" : root.svgSource(modelData.key)
                            readonly property bool isSvg: svg.length > 0
                            // @note compact icon width keeps the combined box tight
                            width: isSvg ? Math.round(44 * root.scaleFactor) : segText.implicitWidth
                            height: Math.round(40 * root.scaleFactor)

                            Image {
                                id: segSvg
                                anchors.fill: parent
                                anchors.margins: Math.round(2 * root.scaleFactor)
                                source: isSvg ? parent.svg : ""
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            MultiEffect {
                                visible: isSvg
                                anchors.fill: segSvg
                                source: segSvg
                                colorization: 1.0
                                colorizationColor: root.boxText
                            }

                            Text {
                                id: segText
                                visible: !isSvg
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.key
                                color: root.boxText
                                font.family: Local.Theme.font
                                font.pixelSize: Math.round(16 * root.scaleFactor)
                                font.letterSpacing: 0.5
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // @note active modifier badges (Ctrl, Alt, Super, Shift, Fn)
            Repeater {
                model: root.shownModifiers

                delegate: Item {
                    id: modDelegate
                    required property string modelData
                    required property int index
                    visible: !root.fullMode

                    // @note uniform width so every modifier svg renders at the same height
                    readonly property real modWidth: Math.round(62 * root.scaleFactor)
                    readonly property real modHeight: Math.round(50 * root.scaleFactor)
                    readonly property string svgName: modelData.toLowerCase()

                    width: modWidth
                    height: modHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(12 * root.scaleFactor)
                        color: root.boxBg
                        border.color: root.boxBorder
                        border.width: 1

                        Image {
                            id: modSvg
                            anchors.fill: parent
                            anchors.margins: Math.round(2 * root.scaleFactor)
                            source: "assets/key_" + modDelegate.svgName + ".svg"
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: modSvg
                            source: modSvg
                            colorization: 1.0
                            colorizationColor: root.boxText
                        }
                    }
                }
            }

            // @note special / combo key box (e.g. in Ctrl+C, shows 'C' or 'Esc', '↵', etc.)
            Rectangle {
                visible: !root.fullMode && root.activeSpecial.length > 0
                // @note badged specials (tab, caps, pgup...) get a fixed svg width
                readonly property string specialSvg: root.svgSource(root.activeSpecial)
                width: specialSvg.length > 0 ? Math.round(62 * root.scaleFactor) : Math.max(Math.round(50 * root.scaleFactor), specialText.implicitWidth + Math.round(26 * root.scaleFactor))
                height: Math.round(50 * root.scaleFactor)
                radius: Math.round(12 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1

                Image {
                    id: specialSvgImage
                    anchors.fill: parent
                    anchors.margins: Math.round(2 * root.scaleFactor)
                    source: parent.specialSvg
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    visible: parent.specialSvg.length > 0
                    anchors.fill: specialSvgImage
                    source: specialSvgImage
                    colorization: 1.0
                    colorizationColor: root.boxText
                }

                Text {
                    id: specialText
                    visible: parent.specialSvg.length === 0
                    anchors.centerIn: parent
                    text: root.activeSpecial
                    color: root.boxText
                    font.family: Local.Theme.font
                    font.pixelSize: Math.round(18 * root.scaleFactor)
                    font.letterSpacing: 0.5
                    font.bold: true
                }
            }

            // @note unified typed text bubble for phrases/words (no separate boxes per char)
            Rectangle {
                visible: !root.fullMode && root.textBuffer.length > 0
                width: Math.max(Math.round(50 * root.scaleFactor), typedText.implicitWidth + Math.round(28 * root.scaleFactor))
                height: Math.round(50 * root.scaleFactor)
                radius: Math.round(12 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1

                Text {
                    id: typedText
                    anchors.centerIn: parent
                    text: root.textBuffer
                    color: root.boxText
                    font.family: Local.Theme.font
                    font.pixelSize: Math.round(18 * root.scaleFactor)
                    font.bold: true
                }
            }
        }
    }
}
