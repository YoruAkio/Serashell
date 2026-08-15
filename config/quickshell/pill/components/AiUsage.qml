import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell
import "../Singletons" as Local

Item {
    id: root

    property var providers: []
    readonly property var summary: {
        const ids = []
        return providers.filter(provider => {
            if (!Local.Settings.aiUsageBarProviders.split(",").includes(provider.id))
                return false
            if (ids.includes(provider.id))
                return false
            ids.push(provider.id)
            return true
        })
    }
    implicitWidth: row.implicitWidth
    implicitHeight: 20

    function refresh() {
        usageProcess.command = [Quickshell.env("HOME") + "/.config/scripts/ai-usage.sh", Local.Settings.activeAiUsageProviders, String(Local.Settings.aiUsageRefreshMinutes * 60)]
        usageProcess.running = true
    }

    Process {
        id: usageProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.providers = this.text.trim().split("\n").filter(line => line).map(line => JSON.parse(line))
            }
        }
    }

    Timer {
        interval: Local.Settings.aiUsageRefreshMinutes * 60000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: if (visible) refresh()
    onVisibleChanged: if (visible) refresh()

    Connections {
        target: Local.Settings
        function onActiveAiUsageProvidersChanged() { if (root.visible) root.refresh() }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Repeater {
            model: root.summary

            delegate: Row {
                id: providerUsage
                required property var modelData
                visible: !modelData.accountOnly
                spacing: 4

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15

                    Image {
                        id: aiIcon
                        anchors.fill: parent
                        source: "../assets/" + providerUsage.modelData.id + ".svg"
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: aiIcon
                        brightness: 1
                        colorization: 1
                        colorizationColor: Local.Theme.secondaryText
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: providerUsage.modelData.remaining + "%"
                    color: Local.Theme.secondaryText
                    font.family: Local.Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            const position = root.mapToItem(null, root.width / 2, 0)
            openProcess.command = ["qs", "ipc", "call", "aiUsage", "toggle", Math.round(position.x)]
            openProcess.running = true
        }
    }

    Process {
        id: openProcess
    }
}
