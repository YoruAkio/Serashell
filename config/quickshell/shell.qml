import Quickshell
import Quickshell.Io
import QtQuick
import "pill" as Pill

ShellRoot {
    id: root

    property bool controlCenterLoaded: false
    property bool settingsLoaded: false
    property int aiUsageAnchorX: 0
    property string settingsPage: "bar"

    Pill.Bar {}
    Pill.Pill {}
    Pill.AiUsagePanel { id: aiUsagePanel; anchorX: root.aiUsageAnchorX }

    Loader {
        id: controlCenterLoader
        active: root.controlCenterLoaded
        sourceComponent: Component {
            Pill.ControlCenter { onDismissed: root.controlCenterLoaded = false }
        }
    }

    IpcHandler {
        target: "aiUsage"
        function toggle(anchorX: int): void {
            root.aiUsageAnchorX = anchorX
            aiUsagePanel.anchorX = anchorX
            aiUsagePanel.toggle()
        }
        function refresh(): void { aiUsagePanel.refresh(true) }
    }

    Loader {
        id: settingsLoader
        active: root.settingsLoaded
        sourceComponent: Component {
            Pill.SettingsWindow {
                page: root.settingsPage
                onDismissed: {
                    root.settingsPage = "bar"
                    root.settingsLoaded = false
                }
            }
        }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle(): void {
            if (controlCenterLoader.item)
                controlCenterLoader.item.toggle()
            else {
                root.controlCenterLoaded = true
                controlCenterOpenTimer.restart()
            }
        }
    }

    IpcHandler {
        target: "pillSettings"
        function toggle(): void {
            if (settingsLoader.item)
                settingsLoader.item.close()
            else {
                root.settingsPage = "bar"
                root.settingsLoaded = true
            }
        }
        function open(page: string): void {
            root.settingsPage = page
            if (settingsLoader.item) {
                settingsLoader.item.page = page
                settingsLoader.item.open = true
            } else {
                root.settingsLoaded = true
            }
        }
    }

    Timer {
        id: controlCenterOpenTimer
        interval: 0
        onTriggered: controlCenterLoader.item?.toggle()
    }
}
