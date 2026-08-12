import Quickshell
import Quickshell.Io
import QtQuick
import "pill" as Pill

ShellRoot {
    id: root

    property bool controlCenterLoaded: false
    property bool settingsLoaded: false

    Pill.Bar {}
    Pill.Pill {}

    Loader {
        id: controlCenterLoader
        active: root.controlCenterLoaded
        sourceComponent: Component {
            Pill.ControlCenter { onDismissed: root.controlCenterLoaded = false }
        }
    }

    Loader {
        id: settingsLoader
        active: root.settingsLoaded
        sourceComponent: Component {
            Pill.SettingsWindow { onDismissed: root.settingsLoaded = false }
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
            else
                root.settingsLoaded = true
        }
    }

    Timer {
        id: controlCenterOpenTimer
        interval: 0
        onTriggered: controlCenterLoader.item?.toggle()
    }
}
