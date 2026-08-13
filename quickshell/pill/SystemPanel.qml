import QtQuick
import "Singletons" as Local

Item {
    id: system

    property var pill
    property real morphCloseness: 0

    Component.onCompleted: Local.SystemMonitor.panelActive = true
    Component.onDestruction: Local.SystemMonitor.panelActive = false

    component Metric: Rectangle {
        required property string icon
        required property string label
        required property string value
        width: 112
        height: 62
        radius: 11
        color: Local.Theme.surface
        border.color: Local.Theme.accent
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 9
            text: parent.icon + "  " + parent.label
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 9
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: parent.value
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 15
            font.bold: true
        }
    }

    component Graph: Canvas {
        required property var values
        required property color stroke
        width: 148
        height: 52
        onValuesChanged: requestPaint()
        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (values.length < 2)
                return
            let maximum = 100
            for (let i = 0; i < values.length; i++)
                maximum = Math.max(maximum, values[i])
            context.strokeStyle = stroke
            context.lineWidth = 2
            context.beginPath()
            for (let i = 0; i < values.length; i++) {
                const x = i * width / (values.length - 1)
                const y = height - 4 - (values[i] / maximum) * (height - 8)
                if (i === 0)
                    context.moveTo(x, y)
                else
                    context.lineTo(x, y)
            }
            context.stroke()
        }
    }

    anchors.fill: parent
    visible: pill.systemOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 18
        text: "󰍛  System status"
        color: Local.Theme.text
        font.family: Local.Theme.font
        font.pixelSize: 13
        font.bold: true
    }

    Row {
        id: metrics
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 48
        spacing: 8

        Metric { icon: "󰻠"; label: "CPU"; value: Local.SystemMonitor.cpu + "%" }
        Metric { icon: "󰍛"; label: "RAM"; value: Local.SystemMonitor.memory + "%" }
        Metric { icon: "󰔄"; label: "TEMP"; value: Local.SystemMonitor.temperature >= 0 ? Local.SystemMonitor.temperature + "°C" : "--" }
        Metric { icon: "󰈀"; label: "NET"; value: Math.round(Local.SystemMonitor.download + Local.SystemMonitor.upload) + " KB/s" }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: metrics.bottom
        anchors.topMargin: 18
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 8

        Row {
            width: parent.width
            height: 48
            spacing: 10
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: "CPU"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 9 }
            Graph { width: parent.width - 50; height: parent.height; values: Local.SystemMonitor.cpuHistory; stroke: Local.Theme.highlight }
        }

        Row {
            width: parent.width
            height: 48
            spacing: 10
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: "RAM"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 9 }
            Graph { width: parent.width - 50; height: parent.height; values: Local.SystemMonitor.memoryHistory; stroke: Local.Theme.secondaryText }
        }

        Row {
            width: parent.width
            height: 48
            spacing: 10
            Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: "NET"; color: Local.Theme.muted; font.family: Local.Theme.font; font.pixelSize: 9 }
            Graph { width: parent.width - 50; height: parent.height; values: Local.SystemMonitor.networkHistory; stroke: Local.Theme.text }
        }
    }
}
