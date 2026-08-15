import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons" as Local

// @note themed right-click menu for tray items, rendered from the dbus menu entries
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "tray-menu"

    property bool open: false
    property bool shown: false
    property int anchorX: 0
    property var trayItem: null
    // @note right click while open: let the shell switch to the tray item under the cursor
    signal switchRequested(int globalX)

    function openMenu(item, globalX) {
        trayItem = item
        anchorX = globalX
        shown = true
        open = true
        emptyCheckTimer.restart()
    }

    function close() {
        open = false
        closeTimer.restart()
    }

    Timer { id: closeTimer; interval: 160; onTriggered: { root.shown = false; root.trayItem = null } }

    // ponytail: apps that build their menu lazily render nothing here; fall back to the native menu
    Timer {
        id: emptyCheckTimer
        interval: 400
        onTriggered: {
            if (root.open && menuColumn.height === 0 && root.trayItem) {
                const item = root.trayItem
                root.close()
                item.display(card, root.anchorX - card.x, 8)
            }
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.trayItem ? root.trayItem.menu : null
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.switchRequested(Math.round(mouse.x))
            else root.close()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card
            x: Math.max(12, Math.min(parent.width - width - 12, root.anchorX - width / 2))
            y: 46
            width: 220
            height: menuColumn.height + 16
            radius: 14
            color: Local.Theme.background
            border.color: Local.Theme.accent
            border.width: 1
            visible: root.open && menuColumn.height > 0
            MouseArea { anchors.fill: parent }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        required property var modelData
                        width: menuColumn.width
                        height: modelData.isSeparator ? 9 : 30

                        Rectangle {
                            visible: modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Local.Theme.accent
                        }

                        Rectangle {
                            visible: !modelData.isSeparator
                            anchors.fill: parent
                            radius: 7
                            color: entryMouse.containsMouse && modelData.enabled ? Local.Theme.surface : "transparent"

                            IconImage {
                                id: entryIcon
                                visible: (modelData.icon || "").length > 0
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                source: modelData.icon
                            }

                            Text {
                                anchors.left: entryIcon.visible ? entryIcon.right : parent.left
                                anchors.leftMargin: entryIcon.visible ? 8 : 12
                                anchors.right: checkMark.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                // @note strip dbus menu mnemonic markers (&& is a literal &, & marks the mnemonic)
                                text: modelData.text.replace(/&&|&/g, m => m === "&&" ? "&" : "").replace(/^_/, "")
                                elide: Text.ElideRight
                                color: !modelData.enabled ? Local.Theme.muted : entryMouse.containsMouse ? Local.Theme.text : Local.Theme.secondaryText
                                font.family: Local.Theme.font
                                font.pixelSize: 12
                            }

                            Text {
                                id: checkMark
                                visible: modelData.checkState !== Qt.Unchecked
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✓"
                                color: Local.Theme.highlight
                                font.family: Local.Theme.font
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!modelData.enabled) return
                                    if (modelData.hasChildren) {
                                        // ponytail: submenus use the native popup instead of nesting panels
                                        modelData.display(card, entryMouse.mouseX, entryMouse.mouseY)
                                    } else {
                                        // @note emit the triggered signal; sendTriggered is not callable from qml
                                        modelData.triggered()
                                        root.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
