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
    readonly property color iconColor: boxText

    readonly property real scaleFactor: Local.Settings.keystrokeSize / 60
    readonly property int fadeTimeMs: Local.Settings.keystrokeFadeTime * 1000
    readonly property bool fullMode: true

    // @note only the current keybind asset set is used by the overlay
    function keyIcon(key) {
        if (key === "MouseLeft") return "assets/MouseClickLeft.svg"
        if (key === "MouseRight") return "assets/MouseClickRight.svg"
        const icons = {
            Alt: "Alt", Backspace: "Backspace", Ctrl: "Ctrl", Enter: "Enter",
            Esc: "Esc", Shift: "Shift", Super: "Super", Tab: "Tab"
        }
        return icons[key] ? "assets/Keybind" + icons[key] + ".svg" : ""
    }

    function mouseClickHighlight(key) {
        if (key === "MouseLeft") return "assets/MouseClickLeftActive.svg"
        if (key === "MouseRight") return "assets/MouseClickRightActive.svg"
        return ""
    }

    // @note state buffers
    property string textBuffer: ""
    property var activeModifiers: []
    // @note ordered modifier display list; released mods linger briefly before clearing
    property var shownModifiers: []
    // @note chronological segments for full mode: {kind, key, modifiers?}
    property var fullSegments: []
    property string activeSpecial: ""
    property real containerOpacity: 0
    property real containerScale: 1
    property int maxBufferLength: 40
    property int pulseCounter: 0
    property int latestPulse: 0
    property bool animateLatestIcon: false
    property int textPulseCounter: 0
    property int latestTextPulse: 0
    property bool animateLatestText: false
    readonly property real modifierBadgeWidth: Math.round(62 * scaleFactor)
    readonly property real specialKeyWidth: Math.round(62 * scaleFactor)
    readonly property real keyIconMargin: Math.round(3 * scaleFactor)
    readonly property real typedMaxWidth: Math.max(100, screenCanvas.width - 16 - shownModifiers.length * (modifierBadgeWidth + 8) - (activeSpecial.length > 0 ? specialKeyWidth + 8 : 0))

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

        // @note shortcuts start a new text run and only record their first press
        if (activeModifiers.length > 0) {
            textBuffer = ""
            if (msg.is_repeat) {
                fadeTimer.restart()
                return
            }
            activeSpecial = key
            pushSegment("combo", { modifiers: activeModifiers.slice(), key: key })
            specialClearTimer.restart()
            fadeTimer.restart()
            return
        }

        // @note standalone keys that have an icon use the current keybind asset set
        if (key === "Backspace") {
            activeSpecial = "Backspace"
            pushSegment("special", "Backspace")
            specialClearTimer.restart()
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
            activeSpecial = "Enter"
            pushSegment("special", "Enter")
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

        // @note regular typing: append character into unified buffer
        if (isChar || key.length === 1) {
            activeSpecial = ""
            specialClearTimer.stop()
            appendChar(key)
        } else {
            activeSpecial = key
            pushSegment("special", key)
            specialClearTimer.restart()
        }

        fadeTimer.restart()
    }

    function appendChar(ch) {
        animateLatestIcon = false
        const textPulse = ++textPulseCounter
        latestTextPulse = textPulse
        animateLatestText = true
        let buf = textBuffer + ch
        if (buf.length > maxBufferLength) {
            buf = buf.slice(buf.length - maxBufferLength)
        }
        textBuffer = buf
        // @note full mode keeps each uninterrupted typing run as one segment
        if (fullMode) {
            let segs = fullSegments.slice()
            if (segs.length > 0 && segs[segs.length - 1].kind === "text") {
                const text = (segs[segs.length - 1].key + ch).slice(-maxBufferLength)
                segs[segs.length - 1] = { kind: "text", key: text, previousText: text.slice(0, -ch.length), lastChar: ch, textPulse: textPulse }
            } else {
                segs.push({ kind: "text", key: ch, previousText: "", lastChar: ch, textPulse: textPulse })
            }
            fullSegments = trimFullSegments(segs)
        }
    }

    function trimFullSegments(segs) {
        let budget = maxBufferLength
        let kept = []
        for (let i = segs.length - 1; i >= 0; i--) {
            const segment = segs[i]
            if (segment.kind === "text") {
                if (budget === 0) continue
                const text = segment.key.slice(-budget)
                kept.unshift({ kind: "text", key: text, previousText: text.slice(0, -segment.lastChar.length), lastChar: segment.lastChar, textPulse: segment.textPulse })
                budget -= text.length
                continue
            }
            const cost = segment.kind === "combo" ? 6 : 4
            if (cost > budget) continue
            kept.unshift(segment)
            budget -= cost
        }
        return kept
    }

    // @note full mode records typing, standalone keys, and modifier combinations in order
    function pushSegment(kind, key) {
        if (!fullMode) return
        let segs = fullSegments.slice()
        const last = segs[segs.length - 1]
        const pulse = ++pulseCounter
        latestPulse = pulse
        animateLatestIcon = true
        animateLatestText = false
        if (kind === "combo" && last && last.kind === "combo" && last.key === key.key && last.modifiers.join(",") === key.modifiers.join(",")) {
            segs[segs.length - 1] = { kind: kind, key: key.key, modifiers: key.modifiers, pulse: pulse }
            fullSegments = trimFullSegments(segs)
            return
        }
        if (kind === "special" && last && last.kind === "special" && last.key === key) {
            segs[segs.length - 1] = { kind: kind, key: key, pulse: pulse }
            fullSegments = trimFullSegments(segs)
            return
        }
        if (kind === "combo")
            segs.push({ kind: kind, key: key.key, modifiers: key.modifiers, pulse: pulse })
        else
            segs.push({ kind: kind, key: key, pulse: pulse })
        fullSegments = trimFullSegments(segs)
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
        interval: root.fadeTimeMs
        onTriggered: root.activeSpecial = ""
    }

    Timer {
        id: modLingerTimer
        interval: root.fadeTimeMs
        onTriggered: {
            // @note drop any modifier that is no longer physically held
            root.shownModifiers = root.activeModifiers.slice()
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
        command: ["python3", Qt.resolvedUrl("lib/keystroke_listener.py").toString().replace("file://", "")].concat(Local.Settings.keystrokeShowMouseClicks ? ["--mouse"] : [])
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

    Timer {
        id: settingsRestartTimer
        interval: 80
        onTriggered: if (Local.Settings.keystrokeEnabled) keystrokeProcess.running = true
    }

    Connections {
        target: Local.Settings
        function onKeystrokeShowMouseClicksChanged() {
            if (keystrokeProcess.running) {
                keystrokeProcess.running = false
                settingsRestartTimer.restart()
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

            // @note full mode: chronological segments in one compact box
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
                    // @note overflow stays pinned to the newest keystrokes on the right
                    x: Math.min(Math.round(10 * root.scaleFactor), parent.width - width - Math.round(10 * root.scaleFactor))
                    y: (parent.height - height) / 2
                    spacing: Math.round(6 * root.scaleFactor)

                    Repeater {
                        model: root.fullSegments

                        delegate: Item {
                            required property var modelData
                            readonly property bool isCombo: modelData.kind === "combo"
                            readonly property bool isText: modelData.kind === "text"
                            readonly property bool isMouse: modelData.key === "MouseLeft" || modelData.key === "MouseRight"
                            readonly property string svg: isCombo ? "" : root.keyIcon(modelData.key)
                            readonly property bool isSvg: svg.length > 0
                            width: isCombo ? comboRow.width : isText ? textRun.width : isSvg ? Math.round(44 * root.scaleFactor) : segText.implicitWidth
                            height: Math.round(40 * root.scaleFactor)

                            Image {
                                id: segSvg
                                anchors.fill: parent
                                anchors.margins: root.keyIconMargin
                                source: isSvg ? parent.svg : ""
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            MultiEffect {
                                id: segSvgTint
                                property int pulse: modelData.pulse || 0
                                property bool shouldPulse: pulse === root.latestPulse
                                anchors.fill: parent
                                anchors.margins: root.keyIconMargin
                                source: segSvg
                                brightness: 1
                                colorization: 1
                                colorizationColor: root.iconColor
                                transform: Translate { id: segSvgOffset; y: 0 }
                                onShouldPulseChanged: if (shouldPulse && root.animateLatestIcon && isSvg) segSvgEntrance.restart()
                                Component.onCompleted: if (shouldPulse && root.animateLatestIcon && isSvg) segSvgEntrance.start()

                                ParallelAnimation {
                                    id: segSvgEntrance
                                    NumberAnimation { target: segSvgTint; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: segSvgOffset; property: "y"; from: Math.round(8 * root.scaleFactor); to: 0; duration: 160; easing.type: Easing.OutCubic }
                                }
                            }

                            Image {
                                id: mouseClickActive
                                anchors.fill: parent
                                anchors.margins: root.keyIconMargin
                                source: root.mouseClickHighlight(modelData.key)
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            MultiEffect {
                                id: mouseClickActiveTint
                                property int pulse: modelData.pulse || 0
                                property bool shouldPulse: pulse === root.latestPulse
                                anchors.fill: mouseClickActive
                                source: mouseClickActive
                                visible: parent.isMouse
                                brightness: 1
                                colorization: 1
                                colorizationColor: Local.Theme.highlight
                                transform: Translate { id: mouseClickActiveOffset; y: 0 }
                                onShouldPulseChanged: if (shouldPulse && root.animateLatestIcon && visible) mouseClickActiveEntrance.restart()
                                Component.onCompleted: if (shouldPulse && root.animateLatestIcon && visible) mouseClickActiveEntrance.start()

                                ParallelAnimation {
                                    id: mouseClickActiveEntrance
                                    NumberAnimation { target: mouseClickActiveTint; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mouseClickActiveOffset; property: "y"; from: Math.round(8 * root.scaleFactor); to: 0; duration: 160; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                id: segText
                                visible: !isSvg && !parent.isCombo && !parent.isText
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.key
                                color: root.boxText
                                font.family: Local.Theme.font
                                font.pixelSize: Math.round(11 * root.scaleFactor)
                                font.letterSpacing: 0.5
                                font.bold: true
                            }

                            Row {
                                id: textRun
                                visible: parent.isText
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: modelData.previousText || ""
                                    color: root.boxText
                                    font.family: Local.Theme.font
                                    font.pixelSize: Math.round(11 * root.scaleFactor)
                                    font.letterSpacing: 0.5
                                    font.bold: true
                                }

                                Text {
                                    id: latestChar
                                    property int pulse: modelData.textPulse || 0
                                    property bool shouldPulse: pulse === root.latestTextPulse
                                    text: modelData.lastChar || modelData.key
                                    color: root.boxText
                                    font.family: Local.Theme.font
                                    font.pixelSize: Math.round(11 * root.scaleFactor)
                                    font.letterSpacing: 0.5
                                    font.bold: true
                                    transform: Translate { id: latestCharOffset; y: 0 }
                                    onShouldPulseChanged: if (shouldPulse && root.animateLatestText) latestCharEntrance.restart()
                                    Component.onCompleted: if (shouldPulse && root.animateLatestText) latestCharEntrance.start()

                                    ParallelAnimation {
                                        id: latestCharEntrance
                                        NumberAnimation { target: latestChar; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: latestCharOffset; property: "y"; from: Math.round(6 * root.scaleFactor); to: 0; duration: 120; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            Row {
                                id: comboRow
                                property int pulse: parent.modelData.pulse || 0
                                property bool shouldPulse: pulse === root.latestPulse
                                visible: parent.isCombo
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(5 * root.scaleFactor)
                                height: Math.round(32 * root.scaleFactor)
                                transform: Translate { id: comboRowOffset; y: 0 }
                                onShouldPulseChanged: if (shouldPulse && root.animateLatestIcon) comboRowEntrance.restart()
                                Component.onCompleted: if (shouldPulse && root.animateLatestIcon) comboRowEntrance.start()

                                ParallelAnimation {
                                    id: comboRowEntrance
                                    NumberAnimation { target: comboRow; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: comboRowOffset; property: "y"; from: Math.round(8 * root.scaleFactor); to: 0; duration: 160; easing.type: Easing.OutCubic }
                                }

                                Repeater {
                                    model: modelData.modifiers

                                    delegate: Item {
                                        required property string modelData
                                        required property int index
                                        readonly property bool hasNext: index < comboRow.parent.modelData.modifiers.length - 1
                                        width: comboModifierIcon.width + (hasNext ? comboModifierPlus.implicitWidth + Math.round(5 * root.scaleFactor) : 0)
                                        height: comboRow.height

                                        Image {
                                            id: comboModifierIcon
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.round(30 * root.scaleFactor)
                                            height: width
                                            source: root.keyIcon(modelData)
                                            fillMode: Image.PreserveAspectFit
                                            visible: false
                                        }

                                        MultiEffect {
                                            anchors.fill: comboModifierIcon
                                            source: comboModifierIcon
                                            brightness: 1
                                            colorization: 1
                                            colorizationColor: root.iconColor
                                        }

                                        Text {
                                            id: comboModifierPlus
                                            visible: parent.hasNext
                                            anchors.left: comboModifierIcon.right
                                            anchors.leftMargin: Math.round(5 * root.scaleFactor)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "+"
                                            color: root.boxText
                                            font.family: Local.Theme.font
                                            font.pixelSize: Math.round(11 * root.scaleFactor)
                                            font.bold: true
                                        }
                                    }
                                }

                                Item {
                                    width: comboPlus.implicitWidth
                                    height: comboRow.height

                                    Text {
                                        id: comboPlus
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.boxText
                                        font.family: Local.Theme.font
                                        font.pixelSize: Math.round(11 * root.scaleFactor)
                                        font.bold: true
                                    }
                                }

                                Item {
                                    width: comboKey.implicitWidth
                                    height: comboRow.height

                                    Text {
                                        id: comboKey
                                        anchors.centerIn: parent
                                        text: modelData.key
                                        color: root.boxText
                                        font.family: Local.Theme.font
                                        font.pixelSize: Math.round(11 * root.scaleFactor)
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // @note active modifier badges
            Repeater {
                model: root.shownModifiers

                delegate: Item {
                    id: modDelegate
                    required property string modelData
                    required property int index
                    visible: !root.fullMode

                    // @note uniform width so every modifier svg renders at the same height
                    readonly property real modWidth: root.modifierBadgeWidth
                    readonly property real modHeight: Math.round(50 * root.scaleFactor)
                    readonly property bool hasNext: index < root.shownModifiers.length - 1
                    width: modWidth + (hasNext ? modPlus.implicitWidth + Math.round(8 * root.scaleFactor) : 0)
                    height: modHeight

                    Rectangle {
                        width: modDelegate.modWidth
                        height: parent.height
                        radius: Math.round(12 * root.scaleFactor)
                        color: root.boxBg
                        border.color: root.boxBorder
                        border.width: 1

                        Image {
                            id: modSvg
                            anchors.fill: parent
                            anchors.margins: root.keyIconMargin
                            source: root.keyIcon(modDelegate.modelData)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: modSvg
                            source: modSvg
                            brightness: 1
                            colorization: 1
                            colorizationColor: root.iconColor
                        }
                    }

                    Text {
                        id: modPlus
                        visible: parent.hasNext
                        anchors.left: parent.left
                        anchors.leftMargin: modDelegate.modWidth + Math.round(8 * root.scaleFactor)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        color: root.boxText
                        font.family: Local.Theme.font
                        font.pixelSize: Math.round(12 * root.scaleFactor)
                        font.bold: true
                    }
                }
            }

            Text {
                visible: !root.fullMode && root.shownModifiers.length > 0 && root.activeSpecial.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: root.boxText
                font.family: Local.Theme.font
                font.pixelSize: Math.round(12 * root.scaleFactor)
                font.bold: true
            }

            // @note special / combo key box (e.g. in Ctrl+C, shows 'C' or 'Esc', '↵', etc.)
            Rectangle {
                visible: !root.fullMode && root.activeSpecial.length > 0
                readonly property string specialSvg: root.keyIcon(root.activeSpecial)
                width: specialSvg.length > 0 ? Math.round(62 * root.scaleFactor) : Math.max(Math.round(50 * root.scaleFactor), specialText.implicitWidth + Math.round(26 * root.scaleFactor))
                height: Math.round(50 * root.scaleFactor)
                radius: Math.round(12 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1

                Image {
                    id: specialSvgImage
                    anchors.fill: parent
                    anchors.margins: root.keyIconMargin
                    source: parent.specialSvg
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: specialSvgImage
                    source: specialSvgImage
                    brightness: 1
                    colorization: 1
                    colorizationColor: root.iconColor
                }

                Image {
                    id: specialMouseClickActive
                    anchors.fill: parent
                    anchors.margins: root.keyIconMargin
                    source: root.mouseClickHighlight(root.activeSpecial)
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: specialMouseClickActive
                    source: specialMouseClickActive
                    visible: root.activeSpecial === "MouseLeft" || root.activeSpecial === "MouseRight"
                    brightness: 1
                    colorization: 1
                    colorizationColor: Local.Theme.highlight
                }

                Text {
                    id: specialText
                    visible: parent.specialSvg.length === 0
                    anchors.centerIn: parent
                    text: root.activeSpecial
                    color: root.boxText
                    font.family: Local.Theme.font
                    font.pixelSize: Math.round(12 * root.scaleFactor)
                    font.letterSpacing: 0.5
                    font.bold: true
                }
            }

            // @note unified typed text bubble for phrases/words (no separate boxes per char)
            Rectangle {
                visible: !root.fullMode && root.textBuffer.length > 0
                width: Math.min(Math.max(Math.round(50 * root.scaleFactor), typedText.implicitWidth + Math.round(28 * root.scaleFactor)), root.typedMaxWidth)
                height: Math.round(50 * root.scaleFactor)
                radius: Math.round(12 * root.scaleFactor)
                color: root.boxBg
                border.color: root.boxBorder
                border.width: 1

                Text {
                    id: typedText
                    property int pulse: root.latestTextPulse
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Math.round(14 * root.scaleFactor)
                    anchors.rightMargin: Math.round(14 * root.scaleFactor)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.textBuffer
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                    color: root.boxText
                    font.family: Local.Theme.font
                    font.pixelSize: Math.round(12 * root.scaleFactor)
                    font.bold: true
                    transform: Translate { id: typedTextOffset; y: 0 }
                    onPulseChanged: if (root.animateLatestText) typedTextEntrance.restart()

                    ParallelAnimation {
                        id: typedTextEntrance
                        NumberAnimation { target: typedText; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                        NumberAnimation { target: typedTextOffset; property: "y"; from: Math.round(6 * root.scaleFactor); to: 0; duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
