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
            Layout.leftMargin: root.wide ? Theme.metrics.panelPadding : Theme.metrics.narrowPadding
            Layout.rightMargin: root.wide ? Theme.metrics.panelPadding : Theme.metrics.narrowPadding
            Layout.preferredHeight: 44
            spacing: 12
            DistroMark {
                objectName: "settingsDistroMark"
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Accessible.ignored: true
            }
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
            ShellIconButton {
                id: closeButton
                objectName: "themeClose"
                text: "Close"
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
                Layout.preferredWidth: root.wide ? 170 : -1
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
                    Flickable {
                        id: navigationScroll
                        objectName: "settingsNavigation"
                        Layout.fillWidth: true
                        implicitHeight: navigationButtons.implicitHeight
                        contentWidth: navigationButtons.width
                        contentHeight: height
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        GridLayout {
                            id: navigationButtons
                            width: root.wide ? navigationScroll.width : implicitWidth
                            columns: root.wide ? 1 : 4
                            columnSpacing: 6
                            rowSpacing: 6
                            Repeater {
                                model: ["Appearance", "Desktop", "Launcher", "Accessibility"]
                                ShellButton {
                                    id: section
                                    required property string modelData
                                    required property int index
                                    objectName: "settings" + modelData
                                    Layout.fillWidth: root.wide
                                    Layout.minimumWidth: root.wide ? 0 : implicitWidth
                                    implicitWidth: sectionContent.implicitWidth + leftPadding + rightPadding
                                    implicitHeight: 40
                                    leftPadding: 8
                                    rightPadding: 8
                                    text: modelData + (index === 0 ? "" : ", Planned")
                                    Accessible.name: text
                                    enabled: index === 0
                                    selected: index === 0
                                    selectedBackground: Theme.colors.elevated
                                    selectedForeground: Theme.colors.accent
                                    quiet: true
                                    borderless: !visualFocus
                                    contentItem: RowLayout {
                                        id: sectionContent
                                        spacing: 6
                                        ShellIcon {
                                            objectName: "settingsSectionIcon"
                                            name: ["sun", "monitor", "search", "accessibility"][section.index]
                                            color: section.selected ? Theme.colors.accent : Theme.colors.muted
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                        }
                                        SettingsLabel {
                                            text: section.modelData
                                            font.pixelSize: root.wide ? 10 : 11
                                            color: section.selected ? Theme.colors.accent : Theme.colors.muted
                                        }
                                        Item {
                                            Layout.fillWidth: root.wide
                                        }
                                        SettingsLabel {
                                            visible: section.index !== 0
                                            text: "Planned"
                                            font.pixelSize: 7
                                            color: Theme.colors.subtle
                                        }
                                    }
                                    onClicked: root.focusInitial()
                                }
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

            ShellScrollView {
                id: scroll
                objectName: "settingsScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                scrollbarName: "settingsScrollbar"
                leftPadding: root.wide ? Theme.metrics.panelPadding : Theme.metrics.narrowPadding
                rightPadding: leftPadding + (scroll.scrollBar.visible ? 10 : 0)
                topPadding: Theme.metrics.panelPadding
                bottomPadding: Theme.metrics.panelPadding

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
                                    implicitHeight: root.wide ? 164 : 140
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
                                        Item {
                                            id: palettePreview
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: root.wide ? 76 : 48
                                            clip: true
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 6
                                                color: card.previewColors.background
                                            }
                                            Rectangle {
                                                x: parent.width * 0.7
                                                y: -width * 0.25
                                                width: parent.width * 0.65
                                                height: width
                                                radius: width / 2
                                                color: card.previewColors.accent
                                                opacity: 0.15
                                            }
                                            Canvas {
                                                anchors.fill: parent
                                                onWidthChanged: requestPaint()
                                                onHeightChanged: requestPaint()
                                                onPaint: {
                                                    const context = getContext("2d");
                                                    context.reset();
                                                    context.fillStyle = card.previewColors.accent;
                                                    context.globalAlpha = 0.16;
                                                    context.beginPath();
                                                    context.moveTo(0, height);
                                                    context.bezierCurveTo(width * 0.2, 0, width * 0.45, height * 0.25, width * 0.65, height * 0.8);
                                                    context.bezierCurveTo(width * 0.8, height, width * 0.9, height * 0.9, width, height * 0.6);
                                                    context.lineTo(width, height);
                                                    context.closePath();
                                                    context.fill();
                                                }
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: 8
                                                color: card.previewColors.surface
                                            }
                                            Rectangle {
                                                x: parent.width * 0.1
                                                y: 16
                                                width: parent.width * 0.5
                                                height: parent.height * 0.62
                                                radius: 6
                                                color: card.previewColors.surface
                                                border.color: card.previewColors.border
                                                Rectangle {
                                                    x: 6
                                                    y: 7
                                                    width: parent.width - 12
                                                    height: 4
                                                    radius: 2
                                                    color: card.previewColors.accent
                                                }
                                                Rectangle {
                                                    x: 6
                                                    y: 17
                                                    width: parent.width - 12
                                                    height: 4
                                                    radius: 2
                                                    color: card.previewColors.elevated
                                                }
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
                                            ShellIcon {
                                                objectName: "themeActiveCheck"
                                                name: "check"
                                                opacity: card.selected ? 1 : 0
                                                Layout.preferredWidth: 16
                                                Layout.preferredHeight: 16
                                                color: Theme.colors.accent
                                            }
                                        }
                                        SettingsLabel {
                                            Layout.fillWidth: true
                                            text: card.description
                                            color: Theme.colors.muted
                                            font.pixelSize: 11
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
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
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: feedback.implicitHeight + 24
            color: Theme.colors.surface
            SettingsLabel {
                id: feedback
                objectName: "themeSaveStatus"
                x: root.wide ? Theme.metrics.panelPadding : Theme.metrics.narrowPadding
                y: 12
                width: parent.width - x * 2
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
    }

    Keys.onEscapePressed: root.closeRequested()
}
