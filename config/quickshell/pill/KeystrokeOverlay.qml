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

    // @note state buffers
    property string textBuffer: ""
    property var activeModifiers: []
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
            // @note add modifier if not already present
            if (!activeModifiers.includes(key)) {
                let updated = activeModifiers.slice()
                updated.push(key)
                activeModifiers = updated
            }
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
            if (activeModifiers.length === 0) {
                activeSpecial = "Tab"
                specialClearTimer.restart()
            } else {
                activeSpecial = "Tab"
            }
            fadeTimer.restart()
            return
        }

        if (key === "Enter") {
            activeSpecial = "↵"
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        if (key === "Esc") {
            activeSpecial = "Esc"
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        if (key === "Space") {
            if (activeModifiers.length > 0) {
                activeSpecial = "Space"
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
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        // @note regular typing: append character into unified buffer
        if (isChar || key.length === 1) {
            appendChar(key)
        } else {
            activeSpecial = key
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
    }

    function handleKeyRelease(msg) {
        const key = msg.key
        if (msg.modifier) {
            let updated = activeModifiers.filter(m => m !== key)
            activeModifiers = updated
        }
        fadeTimer.restart()
    }

    function isWideMod(key) {
        return key === "Shift" || key === "Tab"
    }

    Timer {
        id: specialClearTimer
        interval: 1500
        onTriggered: root.activeSpecial = ""
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
            visible: root.activeModifiers.length > 0 || root.activeSpecial.length > 0 || root.textBuffer.length > 0

            anchors.top: root.topSide ? parent.top : undefined
            anchors.bottom: root.bottomSide ? parent.bottom : undefined
            anchors.left: root.leftSide ? parent.left : undefined
            anchors.right: root.rightSide ? parent.right : undefined
            anchors.horizontalCenter: root.centerSide ? parent.horizontalCenter : undefined
            anchors.topMargin: root.topSide ? 46 : 0
            anchors.bottomMargin: root.bottomSide ? 8 : 0
            anchors.leftMargin: root.leftSide ? 8 : 0
            anchors.rightMargin: root.rightSide ? 8 : 0

            Behavior on opacity {
                enabled: !fadeAnimation.running
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: !fadeAnimation.running
                NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            // @note active modifier badges (Ctrl, Alt, Super, Shift, Fn)
            Repeater {
                model: root.activeModifiers

                delegate: Item {
                    id: modDelegate
                    required property string modelData
                    required property int index

                    readonly property bool isWide: root.isWideMod(modelData)
                    readonly property real modWidth: isWide ? Math.round(84 * root.scaleFactor) : Math.round(62 * root.scaleFactor)
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
                            anchors.margins: Math.round(6 * root.scaleFactor)
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
                visible: root.activeSpecial.length > 0
                width: Math.max(Math.round(50 * root.scaleFactor), specialText.implicitWidth + Math.round(26 * root.scaleFactor))
                height: Math.round(50 * root.scaleFactor)
                radius: Math.round(12 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1

                Text {
                    id: specialText
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
                visible: root.textBuffer.length > 0
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
