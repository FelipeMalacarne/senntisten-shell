import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "services"

FocusScope {
    id: root
    signal closeRequested
    property alias feedbackLabel: feedback
    readonly property bool preferencesEnabled: Theme.ready && Theme.writable
    readonly property bool wide: width >= 640
    implicitWidth: 860
    implicitHeight: 650
    focus: true

    function focusInitial() {
        if (!visible)
            return;
        const index = Theme.presets.findIndex(preset => preset.id === Theme.settings.theme);
        const option = palettes.itemAt(index);
        if (option && option.enabled) {
            option.forceActiveFocus();
            Qt.callLater(scroll.reveal, option);
        } else
            closeButton.forceActiveFocus();
    }

    onVisibleChanged: if (visible)
        Qt.callLater(root.focusInitial)
    Connections {
        target: Theme
        function onReadyChanged() {
            if (Theme.ready && root.visible)
                Qt.callLater(root.focusInitial);
        }
    }

    component SettingsLabel: ShellLabel {
        font.family: Theme.typography.sans
    }

    Rectangle {
        objectName: "settingsSurface"
        anchors.fill: parent
        color: Theme.colors.surface
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.wide ? Theme.metrics.panelPadding : 16
            Layout.rightMargin: root.wide ? Theme.metrics.panelPadding : 16
            Layout.preferredHeight: 52
            spacing: 12
            SettingsLabel {
                Layout.fillWidth: true
                text: "Senntisten / Settings"
                font.pixelSize: 12
                color: Theme.colors.muted
            }
            SettingsLabel {
                visible: root.wide
                text: Theme.name
                font.pixelSize: 11
                color: Theme.colors.accent
            }
            ShellButton {
                id: closeButton
                objectName: "themeClose"
                text: "Close"
                compact: true
                quiet: true
                Accessible.name: "Close Settings"
                onClicked: root.closeRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.colors.border
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.wide ? 2 : 1
            columnSpacing: 0
            rowSpacing: 0

            Rectangle {
                objectName: "settingsSidebar"
                Layout.fillWidth: !root.wide
                Layout.fillHeight: root.wide
                Layout.preferredWidth: root.wide ? 180 : -1
                implicitHeight: navigation.implicitHeight + 24
                color: Theme.colors.background

                ColumnLayout {
                    id: navigation
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: root.wide ? 16 : 0
                    SettingsLabel {
                        visible: root.wide
                        Layout.leftMargin: 8
                        Layout.topMargin: 12
                        text: "PREFERENCES"
                        color: Theme.colors.subtle
                        font.family: Theme.typography.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.wide ? 1 : 3
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: ["Appearance", "Desktop", "Launcher"]
                            ShellButton {
                                id: section
                                required property string modelData
                                required property int index
                                objectName: "settings" + modelData
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 1
                                implicitHeight: 48
                                leftPadding: 8
                                rightPadding: 8
                                text: modelData + (index === 0 ? "" : "\nPlanned")
                                enabled: index === 0
                                selected: index === 0
                                selectedBackground: Theme.colors.elevated
                                selectedForeground: Theme.colors.accent
                                quiet: true
                                borderless: !visualFocus
                                contentItem: SettingsLabel {
                                    text: section.text
                                    font.pixelSize: root.wide ? 12 : 11
                                    color: section.selected ? Theme.colors.accent : Theme.colors.muted
                                    horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: root.focusInitial()
                            }
                        }
                    }
                    SettingsLabel {
                        visible: root.wide
                        Layout.fillWidth: true
                        Layout.margins: 8
                        Layout.topMargin: 24
                        text: "Your shell, your space.\nAppearance lives here."
                        color: Theme.colors.subtle
                        font.pixelSize: 11
                        lineHeight: 1.5
                    }
                }
            }

            ScrollView {
                id: scroll
                objectName: "settingsScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                clip: true
                leftPadding: root.wide ? Theme.metrics.panelPadding : 16
                rightPadding: leftPadding + (scrollbar.visible ? 10 : 0)
                topPadding: Theme.metrics.panelPadding
                bottomPadding: Theme.metrics.panelPadding
                contentWidth: availableWidth

                function reveal(item) {
                    if (!item)
                        return;
                    const viewport = scroll.contentItem;
                    const point = item.mapToItem(viewport.contentItem, 0, 0);
                    const maximum = Math.max(0, viewport.contentHeight - viewport.height);
                    if (point.y - 8 < viewport.contentY)
                        viewport.contentY = Math.max(0, point.y - 8);
                    else if (point.y + item.height + 8 > viewport.contentY + viewport.height)
                        viewport.contentY = Math.min(maximum, point.y + item.height + 8 - viewport.height);
                }

                ScrollBar.vertical: ScrollBar {
                    id: scrollbar
                    objectName: "settingsScrollbar"
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
                    spacing: 22
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        SettingsLabel {
                            text: "PERSONALIZATION"
                            color: Theme.colors.subtle
                            font.family: Theme.typography.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                        SettingsLabel {
                            objectName: "settingsHeading"
                            text: "Appearance"
                            font.family: Theme.typography.serif
                            font.pixelSize: 32
                        }
                        SettingsLabel {
                            Layout.fillWidth: true
                            text: "Palettes and interface preferences for your desktop."
                            color: Theme.colors.muted
                            font.pixelSize: 12
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        SettingsLabel {
                            text: "Color palette"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: root.wide ? 2 : 1
                            columnSpacing: 12
                            rowSpacing: 12
                            Repeater {
                                id: palettes
                                model: Theme.presets
                                ThemeOption {
                                    id: card
                                    required property var modelData
                                    objectName: "theme-" + modelData.id
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 1
                                    implicitHeight: root.wide ? 172 : 140
                                    padding: 12
                                    themeId: modelData.id
                                    text: modelData.name
                                    description: modelData.description
                                    enabled: root.preferencesEnabled
                                    onClicked: Theme.selectTheme(themeId)
                                    onActiveFocusChanged: if (activeFocus)
                                        Qt.callLater(scroll.reveal, card)
                                    background: Rectangle {
                                        radius: Theme.metrics.controlRadius
                                        color: card.hovered || card.activeFocus ? Theme.colors.elevated : Theme.colors.surface
                                        border.width: card.visualFocus ? 2 : 1
                                        border.color: card.selected || card.visualFocus ? Theme.colors.accent : Theme.colors.border
                                    }
                                    contentItem: ColumnLayout {
                                        spacing: 10
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: root.wide ? 76 : 48
                                            radius: 6
                                            color: card.previewColors.background
                                            clip: true
                                            Rectangle {
                                                width: parent.width
                                                height: 8
                                                color: card.previewColors.elevated
                                            }
                                            Rectangle {
                                                x: parent.width * 0.15
                                                y: 30
                                                width: parent.width * 0.7
                                                height: 90
                                                radius: 45
                                                rotation: -12
                                                color: card.previewColors.accent
                                                opacity: 0.4
                                            }
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 10
                                                width: parent.width * 0.42
                                                height: 40
                                                radius: 6
                                                color: card.previewColors.surface
                                                border.color: card.previewColors.border
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            SettingsLabel {
                                                objectName: "themeOptionLabel"
                                                Layout.fillWidth: true
                                                text: card.text
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                            }
                                            SettingsLabel {
                                                text: card.selected ? "Active" : ""
                                                color: Theme.colors.accent
                                                font.pixelSize: 10
                                            }
                                        }
                                        SettingsLabel {
                                            Layout.fillWidth: true
                                            text: card.description
                                            color: Theme.colors.muted
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        ShellSwitch {
                            id: motionSwitch
                            objectName: "reducedMotionSwitch"
                            Layout.fillWidth: true
                            text: "Reduce motion"
                            checked: Theme.settings.reducedMotion
                            enabled: root.preferencesEnabled
                            onToggled: Theme.setReducedMotion(checked)
                            onActiveFocusChanged: if (activeFocus)
                                Qt.callLater(scroll.reveal, motionSwitch)
                        }
                        SettingsLabel {
                            Layout.fillWidth: true
                            text: "Limit animations across the shell."
                            color: Theme.colors.muted
                            font.pixelSize: 11
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: [
                                {
                                    id: "wallpaper",
                                    title: "Wallpaper",
                                    description: "Choose a background for your desktop.",
                                    action: "Choose image"
                                },
                                {
                                    id: "font",
                                    title: "Typography",
                                    description: "Customize the shell's local fonts.",
                                    action: "Customize"
                                },
                                {
                                    id: "density",
                                    title: "Interface density",
                                    description: "Adjust spacing and sizing across the shell.",
                                    action: "Configure"
                                }
                            ]
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: Theme.colors.border
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 16
                                    Layout.bottomMargin: 16
                                    columns: root.wide ? 2 : 1
                                    columnSpacing: 16
                                    rowSpacing: 10
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        SettingsLabel {
                                            text: modelData.title
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }
                                        SettingsLabel {
                                            Layout.fillWidth: true
                                            text: modelData.description
                                            color: Theme.colors.muted
                                            font.pixelSize: 11
                                        }
                                    }
                                    ShellButton {
                                        objectName: "settings-" + modelData.id
                                        Layout.preferredWidth: 164
                                        text: modelData.action + " / Planned"
                                        enabled: false
                                        compact: true
                                        Accessible.name: modelData.title + ": " + text
                                        contentItem: SettingsLabel {
                                            text: modelData.action + " / Planned"
                                            color: Theme.colors.muted
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.colors.border
        }
        SettingsLabel {
            id: feedback
            objectName: "themeSaveStatus"
            Layout.fillWidth: true
            Layout.margins: root.wide ? Theme.metrics.panelPadding : 16
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            text: {
                if (!Theme.ready || Theme.saveStatus === "loading")
                    return "Loading appearance...";
                if (Theme.message)
                    return Theme.message;
                switch (Theme.saveStatus) {
                case "saving":
                    return "Saving appearance...";
                case "saved":
                    return "Appearance saved.";
                case "error":
                    return "Could not save appearance. Changes are not saved.";
                case "blocked":
                    return "Unsupported newer appearance schema. Saving is disabled.";
                default:
                    return "Changes are saved automatically.";
                }
            }
            color: Theme.saveStatus === "error" ? Theme.colors.error : Theme.saveStatus === "blocked" || Theme.saveStatus === "recovered" ? Theme.colors.warning : Theme.colors.muted
            font.pixelSize: 11
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Accessible.name: text
        }
    }

    Keys.onEscapePressed: root.closeRequested()
}
