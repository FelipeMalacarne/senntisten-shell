import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "services"

Rectangle {
    id: root
    property bool panelOpen: true
    readonly property bool wide: width >= 920
    property date now: new Date()
    color: Theme.colors.background

    Shortcut {
        sequence: "Ctrl+,"
        onActivated: root.panelOpen = !root.panelOpen
    }
    Shortcut {
        sequence: "Ctrl+T"
        onActivated: Theme.cycleTheme()
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.panelOpen
        onActivated: root.panelOpen = false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 22

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            radius: 12
            color: Theme.colors.surface
            border.color: Theme.colors.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 12
                BrandMark {}
                ShellLabel {
                    text: "Senntisten"
                    font.weight: Font.DemiBold
                    font.pixelSize: 15
                }
                Rectangle {
                    visible: root.wide
                    width: 1
                    height: 20
                    color: Theme.colors.border
                }
                ShellLabel {
                    visible: root.wide
                    text: "THEME PLAYGROUND"
                    color: Theme.colors.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                Item {
                    Layout.fillWidth: true
                }
                ShellLabel {
                    text: Qt.formatDateTime(root.now, "HH:mm")
                    color: Theme.colors.muted
                    font.pixelSize: 13
                }
                ShellButton {
                    objectName: "appearanceButton"
                    text: "Appearance"
                    compact: true
                    selected: root.panelOpen
                    onClicked: root.panelOpen = !root.panelOpen
                    ToolTip.visible: hovered
                    ToolTip.text: "Show or hide the appearance panel · Ctrl+,"
                }
            }
        }

        ScrollView {
            id: scroll
            objectName: "contentScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            rightPadding: scrollbar.visible ? 14 : 0
            clip: true

            function containsItem(item) {
                let current = item;
                while (current && current !== scroll.contentItem.contentItem)
                    current = current.parent;
                return current === scroll.contentItem.contentItem;
            }

            function reveal(item) {
                if (!item || !containsItem(item))
                    return;
                const viewport = scroll.contentItem;
                const point = item.mapToItem(viewport.contentItem, 0, 0);
                const margin = 8;
                const top = point.y - margin;
                const bottom = point.y + item.height + margin;
                const minimum = viewport.originY;
                const maximum = Math.max(minimum, viewport.contentHeight - viewport.height);
                if (top < viewport.contentY)
                    viewport.contentY = Math.max(minimum, top);
                else if (bottom > viewport.contentY + viewport.height)
                    viewport.contentY = Math.min(maximum, bottom - viewport.height);
            }

            Connections {
                target: root.Window.window
                function onActiveFocusItemChanged() {
                    Qt.callLater(scroll.reveal, root.Window.window.activeFocusItem);
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: scrollbar
                objectName: "contentScrollbar"
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.colors.muted
                    opacity: scrollbar.pressed ? 0.9 : 0.45
                }
            }
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 24
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ShellLabel {
                        text: "YOUR DESKTOP, UNDER YOUR CONTROL"
                        color: Theme.colors.accent
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                    }
                    ShellLabel {
                        text: "Theme playground"
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }
                    ShellLabel {
                        Layout.fillWidth: true
                        text: "A quiet surface. A shared visual language. Nothing here changes your active desktop."
                        color: Theme.colors.muted
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.wide && root.panelOpen ? 2 : 1
                    columnSpacing: 20
                    rowSpacing: 20
                    Surface {
                        id: componentCanvas
                        objectName: "componentCanvas"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        ColumnLayout {
                            width: parent.width
                            spacing: 20
                            RowLayout {
                                Layout.fillWidth: true
                                ShellLabel {
                                    text: "Component canvas"
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                ShellLabel {
                                    text: "LIVE"
                                    color: Theme.colors.accent
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 176
                                radius: 10
                                color: Theme.colors.background
                                border.color: Theme.colors.border
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 22
                                    spacing: 10
                                    RowLayout {
                                        BrandMark {}
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        ShellLabel {
                                            text: "SENNTISTEN / 01"
                                            color: Theme.colors.muted
                                            font.pixelSize: 10
                                            font.letterSpacing: 1
                                        }
                                    }
                                    Item {
                                        Layout.fillHeight: true
                                    }
                                    ShellLabel {
                                        objectName: "previewTitle"
                                        text: "One palette. Every surface."
                                        font.pixelSize: 21
                                        font.weight: Font.Medium
                                    }
                                    ShellLabel {
                                        text: Theme.name
                                        color: Theme.colors.muted
                                        font.pixelSize: 12
                                    }
                                }
                            }
                            ShellLabel {
                                Layout.fillWidth: true
                                text: "Text, cards, borders and controls all read the same semantic colors."
                                color: Theme.colors.muted
                                font.pixelSize: 13
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                ShellButton {
                                    objectName: "cycleThemeButton"
                                    text: "Cycle palette"
                                    primary: true
                                    enabled: Theme.ready && Theme.writable
                                    onClicked: Theme.cycleTheme()
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Switch to the next palette · Ctrl+T"
                                }
                                ShellLabel {
                                    text: "Ctrl+T"
                                    color: Theme.colors.muted
                                    font.pixelSize: 11
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                            ShellLabel {
                                text: "COLOR ROLES"
                                color: Theme.colors.muted
                                font.pixelSize: 10
                                font.letterSpacing: 1
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 12
                                Repeater {
                                    model: ["background", "surface", "elevated", "accent", "text", "muted"]
                                    Column {
                                        required property string modelData
                                        width: 66
                                        spacing: 6
                                        Rectangle {
                                            width: 58
                                            height: 38
                                            radius: 6
                                            color: Theme.colors[parent.modelData]
                                            border.color: Theme.colors.border
                                        }
                                        ShellLabel {
                                            text: parent.modelData
                                            font.pixelSize: 10
                                            color: Theme.colors.muted
                                        }
                                        ShellLabel {
                                            text: Theme.colors[parent.modelData]
                                            font.pixelSize: 11
                                            color: Theme.colors.muted
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Surface {
                        objectName: "appearancePanel"
                        visible: root.panelOpen
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.wide ? 288 : -1
                        Layout.alignment: Qt.AlignTop
                        ColumnLayout {
                            width: parent.width
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true
                                ShellLabel {
                                    text: "Theme"
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                ShellLabel {
                                    text: Theme.name
                                    color: Theme.colors.accent
                                    font.pixelSize: 11
                                }
                            }
                            Repeater {
                                model: Theme.presets
                                ThemeOption {
                                    required property var modelData
                                    objectName: "theme-" + modelData.id
                                    Layout.fillWidth: true
                                    themeId: modelData.id
                                    text: modelData.name
                                    description: modelData.description
                                    enabled: Theme.ready && Theme.writable
                                    onClicked: Theme.selectTheme(themeId)
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.colors.border
                            }
                            ShellSwitch {
                                objectName: "reducedMotionSwitch"
                                Layout.fillWidth: true
                                text: "Reduce motion"
                                checked: Theme.settings.reducedMotion
                                enabled: Theme.ready && Theme.writable
                                onToggled: Theme.setReducedMotion(checked)
                            }
                        }
                    }
                }
            }
        }
        StateFooter {
            objectName: "stateFooter"
            Layout.fillWidth: true
        }
    }
}
