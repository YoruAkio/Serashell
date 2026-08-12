import QtQuick
import "Singletons" as Local

Item {
    id: calendar

    property var pill
    property real morphCloseness: 0

    function daysInMonth(date) {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
    }

    function firstWeekday(date) {
        return new Date(date.getFullYear(), date.getMonth(), 1).getDay()
    }

    anchors.fill: parent
    visible: pill.calendarOpen
    opacity: visible ? morphCloseness : 0

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃭"
            color: Local.Theme.highlight
            font.family: Local.Theme.font
            font.pixelSize: 16
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(pill.calendarMonth, "MMMM yyyy")
            color: Local.Theme.text
            font.family: Local.Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: "󰅁"
                color: calendarPrevious.containsMouse ? Local.Theme.text : Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 14

                MouseArea {
                    id: calendarPrevious
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: pill.calendarMonth = new Date(pill.calendarMonth.getFullYear(), pill.calendarMonth.getMonth() - 1, 1)
                }
            }

            Text {
                text: "󰅂"
                color: calendarNext.containsMouse ? Local.Theme.text : Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 14

                MouseArea {
                    id: calendarNext
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: pill.calendarMonth = new Date(pill.calendarMonth.getFullYear(), pill.calendarMonth.getMonth() + 1, 1)
                }
            }
        }
    }

    Grid {
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        rowSpacing: 7
        columnSpacing: 7

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]

            delegate: Text {
                required property string modelData
                width: 36
                height: 18
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Local.Theme.muted
                font.family: Local.Theme.font
                font.pixelSize: 10
            }
        }

        Repeater {
            model: 42

            delegate: Rectangle {
                required property int index
                readonly property int day: index - calendar.firstWeekday(pill.calendarMonth) + 1
                readonly property bool valid: day > 0 && day <= calendar.daysInMonth(pill.calendarMonth)
                readonly property bool today: valid && day === new Date().getDate() && pill.calendarMonth.getMonth() === new Date().getMonth() && pill.calendarMonth.getFullYear() === new Date().getFullYear()
                width: 36
                height: 28
                radius: 9
                color: today ? Local.Theme.highlight : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.valid ? parent.day : ""
                    color: parent.today ? Local.Theme.background : Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 11
                    font.bold: parent.today
                }
            }
        }
    }
}
