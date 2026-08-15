import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons" as Local

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "ai-usage"

    property bool open: false
    property bool shown: false
    property int anchorX: 0
    property var providers: []
    property string spendPeriod: "month"
    property double clockNow: Date.now()
    property double nextUpdateAt: Date.now() + Local.Settings.aiUsageRefreshMinutes * 60000
    readonly property int minutesUntilUpdate: Math.max(0, Math.ceil((nextUpdateAt - clockNow) / 60000))
    readonly property var providerGroups: {
        const groups = []
        providers.forEach(metric => {
            if (!Local.Settings.aiUsagePanelProviders.split(",").includes(metric.id))
                return
            let group = groups.find(item => item.id === metric.id)
            if (!group) {
                group = { id: metric.id, plan: metric.plan || "", metrics: [], todayCost: metric.todayCost || 0, monthCost: metric.monthCost || 0, yesterdayCost: metric.yesterdayCost || 0, todayTokens: metric.todayTokens || 0, monthTokens: metric.monthTokens || 0, yesterdayTokens: metric.yesterdayTokens || 0 }
                groups.push(group)
            }
            if (!group.plan && metric.plan)
                group.plan = metric.plan
            group.metrics.push(metric)
        })
        return groups
    }
    readonly property real totalSpend: providerGroups.reduce((sum, provider) => sum + (spendPeriod === "today" ? provider.todayCost : provider.monthCost), 0)
    function providerName(id) {
        return ({ claude: "Claude", codex: "Codex", cursor: "Cursor", antigravity: "Antigravity", copilot: "Copilot", grok: "Grok", opencode: "OpenCode" })[id] || id
    }

    function providerColor(id) {
        return ({
            cursor: "#13120A",
            claude: "#DE7356",
            codex: "#10A37F",
            grok: "#8E8E93",
            opencode: "#6E6E73",
            antigravity: "#4285F4",
            copilot: "#A855F7"
        })[id] || Local.Theme.highlight
    }

    function money(value) {
        if (value >= 1000) return "$" + (value / 1000).toFixed(1).replace(".0", "") + "K"
        return "$" + value.toFixed(2)
    }

    function tokens(value) {
        if (value >= 1000000) return (value / 1000000).toFixed(1) + "M tokens"
        if (value >= 1000) return (value / 1000).toFixed(1) + "K tokens"
        return Math.round(value) + " tokens"
    }

    function close() {
        open = false
        closeTimer.restart()
    }

    function refresh(force) {
        const command = [Quickshell.env("HOME") + "/.config/scripts/ai-usage.sh", Local.Settings.activeAiUsageProviders, String(Local.Settings.aiUsageRefreshMinutes * 60)]
        if (force) command.push("--force")
        usageProcess.command = command
        usageProcess.running = true
    }

    function toggle() {
        if (open)
            close()
        else {
            shown = true
            open = true
        }
    }

    Process {
        id: usageProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.providers = this.text.trim().split("\n").filter(line => line).map(line => JSON.parse(line))
                root.nextUpdateAt = Date.now() + Local.Settings.aiUsageRefreshMinutes * 60000
            }
        }
    }
    Process { id: settingsProcess }

    Timer { interval: Local.Settings.aiUsageRefreshMinutes * 60000; running: true; repeat: true; onTriggered: root.refresh(false) }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.clockNow = Date.now() }
    Timer { id: closeTimer; interval: 160; onTriggered: root.shown = false }
    Component.onCompleted: refresh(false)

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card
            width: root.open ? 360 : 30
            height: root.open ? dashboard.height + 56 : 30
            x: Math.max(12, Math.min(parent.width - width - 12, root.anchorX - width / 2))
            y: 46
            radius: root.open ? 24 : 15
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            clip: true
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }

            Column {
                id: dashboard
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 218
                        radius: 14
                        color: Local.Theme.surface

                        Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.top: parent.top; anchors.topMargin: 12; text: "Total Spend"; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14; font.bold: true }

                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 36
                            height: 28; radius: 14; color: Local.Theme.background
                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: [{ label: "Today", value: "today" }, { label: "30 Days", value: "month" }]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width / 2; height: parent.height; radius: 14
                                        color: root.spendPeriod === modelData.value ? Local.Theme.highlight : "transparent"
                                        Text { anchors.centerIn: parent; text: parent.modelData.label; color: root.spendPeriod === parent.modelData.value ? Local.Theme.background : Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                                        MouseArea { anchors.fill: parent; onClicked: { root.spendPeriod = parent.modelData.value; donut.requestPaint() } }
                                    }
                                }
                            }
                        }

                        Canvas {
                            id: donut
                            anchors.left: parent.left; anchors.leftMargin: 16; anchors.top: parent.top; anchors.topMargin: 78
                            width: 116; height: 116
                            onPaint: {
                                const context = getContext("2d")
                                context.clearRect(0, 0, width, height)
                                const center = width / 2
                                const radius = 42
                                context.lineWidth = 18
                                let angle = -Math.PI / 2
                                if (root.totalSpend <= 0) {
                                    context.strokeStyle = Local.Theme.accent.toString()
                                    context.beginPath(); context.arc(center, center, radius, 0, Math.PI * 2); context.stroke()
                                    return
                                }
                                root.providerGroups.forEach(provider => {
                                    const value = root.spendPeriod === "today" ? provider.todayCost : provider.monthCost
                                    if (value <= 0) return
                                    const next = angle + Math.PI * 2 * value / root.totalSpend
                                    context.strokeStyle = root.providerColor(provider.id).toString()
                                    context.beginPath(); context.arc(center, center, radius, angle, next); context.stroke()
                                    angle = next
                                })
                            }
                            Connections { target: root; function onTotalSpendChanged() { donut.requestPaint() } }
                            Text { anchors.centerIn: parent; text: root.money(root.totalSpend); color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 15; font.bold: true }
                        }

                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 145; anchors.right: parent.right; anchors.rightMargin: 14; anchors.top: parent.top; anchors.topMargin: 84
                            spacing: 7
                            Repeater {
                                model: root.providerGroups
                                delegate: Row {
                                    id: legendRow
                                    required property int index
                                    required property var modelData
                                    width: parent.width; height: 15; spacing: 6
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: root.providerColor(legendRow.modelData.id) }
                                    Text { anchors.verticalCenter: parent.verticalCenter; width: 75; text: root.providerName(legendRow.modelData.id); color: Local.Theme.secondaryText; font.family: Local.Theme.font; font.pixelSize: 11; elide: Text.ElideRight }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.money(root.spendPeriod === "today" ? legendRow.modelData.todayCost : legendRow.modelData.monthCost); color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.providerGroups
                        delegate: Item {
                            id: providerCard
                            required property int index
                            required property var modelData
                            width: dashboard.width
                            readonly property real metricsBlockHeight: {
                                let total = 12 + 8
                                for (let i = 0; i < modelData.metrics.length; i++) {
                                    if (i > 0)
                                        total += 8
                                    total += modelData.metrics[i].accountOnly ? 14 : 44
                                }
                                if (modelData.metrics.length > 0)
                                    total += 8
                                if (root.spendPeriod === "today")
                                    total += 14
                                else
                                    total += 14 + 8 + 14
                                return total
                            }
                            height: 30 + metricsBlockHeight

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 5
                                spacing: 6

                                Text { text: root.providerName(providerCard.modelData.id); color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 14; font.bold: true }
                                Text { visible: providerCard.modelData.plan.length > 0; anchors.verticalCenter: parent.verticalCenter; text: providerCard.modelData.plan; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11 }
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                width: 21
                                height: 21

                                Image {
                                    id: providerIcon
                                    anchors.fill: parent
                                    source: "assets/" + providerCard.modelData.id + ".svg"
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

                            Rectangle {
                                id: metricsCard
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 30
                                anchors.bottom: parent.bottom
                                radius: 14
                                color: Local.Theme.surface
                            }

                            Column {
                                anchors.left: metricsCard.left; anchors.right: metricsCard.right; anchors.top: metricsCard.top
                                anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 12
                                anchors.bottom: metricsCard.bottom; anchors.bottomMargin: 8
                                spacing: 8

                                Repeater {
                                    model: providerCard.modelData.metrics
                                    delegate: Item {
                                        id: metricRow
                                        required property var modelData
                                        width: parent.width
                                        height: modelData.accountOnly ? 14 : 44
                                        Text { anchors.left: parent.left; anchors.top: parent.top; text: metricRow.modelData.label; color: Local.Theme.text; font.family: Local.Theme.font; font.pixelSize: 12; font.bold: true }
                                        Text { anchors.right: parent.right; anchors.top: parent.top; text: metricRow.modelData.accountOnly ? "Signed in" : metricRow.modelData.remaining + "% left"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 11 }
                                        Rectangle { visible: !metricRow.modelData.accountOnly; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 20; height: 5; radius: 3; color: Local.Theme.accent }
                                        Rectangle { visible: !metricRow.modelData.accountOnly; anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 20; width: parent.width * metricRow.modelData.used / 100; height: 5; radius: 3; color: Local.Theme.highlight }
                                        Text { visible: !metricRow.modelData.accountOnly; anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 30; text: metricRow.modelData.used + "% used"; color: Local.Theme.subtleMuted; font.family: Local.Theme.font; font.pixelSize: 10 }
                                    }
                                }

                                Text {
                                    visible: root.spendPeriod === "today"
                                    width: parent.width
                                    text: root.money(providerCard.modelData.todayCost) + " · " + root.tokens(providerCard.modelData.todayTokens)
                                    color: Local.Theme.secondaryText
                                    font.family: Local.Theme.font
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Repeater {
                                    model: root.spendPeriod === "month" ? [
                                        { label: "Today", cost: providerCard.modelData.todayCost, tokens: providerCard.modelData.todayTokens },
                                        { label: "Yesterday", cost: providerCard.modelData.yesterdayCost, tokens: providerCard.modelData.yesterdayTokens }
                                    ] : []

                                    delegate: Item {
                                        required property var modelData
                                        width: parent.width
                                        height: 14
                                        Text { anchors.left: parent.left; text: root.money(parent.modelData.cost) + " · " + root.tokens(parent.modelData.tokens); color: Local.Theme.secondaryText; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                                        Text { anchors.right: parent.right; text: parent.modelData.label; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                    }
            }

            Item {
                x: 18
                y: dashboard.y + dashboard.height + 8
                width: parent.width - 36
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: usageProcess.running ? "Updating…" : "Next update in " + root.minutesUntilUpdate + "m"
                    color: updateMouse.containsMouse ? Local.Theme.text : Local.Theme.muted
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                }

                MouseArea {
                    id: updateMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 150
                    hoverEnabled: true
                    onClicked: root.refresh(true)
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: Local.Theme.highlight

                    Text { anchors.centerIn: parent; text: "•••"; color: Local.Theme.background; font.family: Local.Theme.font; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.close()
                            settingsProcess.command = ["qs", "ipc", "call", "pillSettings", "open", "ai-usage"]
                            settingsProcess.running = true
                        }
                    }
                }
            }
        }
    }
}
