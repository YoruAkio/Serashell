pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: monitor
    visible: false

    property int cpu: 0
    property int memory: 0
    property int temperature: -1
    property real download: 0
    property real upload: 0
    property real previousTotal: 0
    property real previousIdle: 0
    property real previousReceived: 0
    property real previousSent: 0
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: []
    property bool barActive: false
    property bool panelActive: false
    readonly property bool active: barActive || panelActive

    function append(history, value) {
        const next = history.slice()
        next.push(value)
        return next.slice(-32)
    }

    Process {
        id: statsProcess
        command: ["sh", "-c", "read _ u n s i w x y z _ < /proc/stat; total=$((u+n+s+i+w+x+y+z)); idle=$((i+w)); set -- $(awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo); temp=$(for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do [ -r \"$f\" ] && { cat \"$f\"; break; }; done); set -- $(awk 'NR>2 {gsub(/:/, \"\", $1); if ($1 != \"lo\") {rx += $2; tx += $10}} END {print rx+0, tx+0}' /proc/net/dev) \"$@\"; printf '%s %s %s %s %s %s\n' \"$total\" \"$idle\" \"$3\" \"$4\" \"${temp:-0}\" \"$1 $2\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = this.text.trim().split(/\s+/).map(Number)
                if (values.length < 7)
                    return
                const total = values[0]
                const idle = values[1]
                const memoryTotal = values[2]
                const memoryAvailable = values[3]
                const temperature = values[4]
                const received = values[5]
                const sent = values[6]
                const deltaTotal = total - monitor.previousTotal
                const deltaIdle = idle - monitor.previousIdle

                if (monitor.previousTotal > 0 && deltaTotal > 0)
                    monitor.cpu = Math.round(100 * (deltaTotal - deltaIdle) / deltaTotal)
                if (memoryTotal > 0)
                    monitor.memory = Math.round(100 * (memoryTotal - memoryAvailable) / memoryTotal)
                monitor.temperature = temperature > 1000 ? Math.round(temperature / 1000) : -1
                if (monitor.previousReceived > 0) {
                    monitor.download = Math.max(0, (received - monitor.previousReceived) / 1024)
                    monitor.upload = Math.max(0, (sent - monitor.previousSent) / 1024)
                }

                monitor.previousTotal = total
                monitor.previousIdle = idle
                monitor.previousReceived = received
                monitor.previousSent = sent
                if (monitor.panelActive) {
                    monitor.cpuHistory = monitor.append(monitor.cpuHistory, monitor.cpu)
                    monitor.memoryHistory = monitor.append(monitor.memoryHistory, monitor.memory)
                    monitor.networkHistory = monitor.append(monitor.networkHistory, monitor.download + monitor.upload)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: monitor.active
        repeat: true
        onTriggered: statsProcess.running = true
    }

    onActiveChanged: {
        if (active)
            statsProcess.running = true
    }
}
