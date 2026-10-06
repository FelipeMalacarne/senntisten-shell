import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../components"
import "../services"

Item {
    id: root
    signal launcherRequested
    signal appearanceRequested
    signal audioRequested
    property bool audioOpen: false
    readonly property alias audioAnchor: audioButton
    property var hostWindow: null
    property bool popAbove: false
    readonly property int trayCount: services.trayItems.length
    property string screenName: ""
    property var services: nativeServices
    readonly property var screenWorkspaces: services.workspaces.filter(workspace => workspace.monitor && workspace.monitor.name === screenName).sort((a, b) => a.id - b.id)
    readonly property int workspaceCount: screenWorkspaces.length
    readonly property int edgePadding: width < 600 ? 12 : 24
    // Equal side budgets reserve the true screen center even with asymmetric providers.
    readonly property real sideWidth: Math.max(0, (width - clockGroup.width) / 2 - edgePadding - 8)
    implicitHeight: Theme.metrics.barHeight

    BarServices {
        id: nativeServices
    }

    SystemClock {
        id: clock
        objectName: "barClockSource"
        precision: SystemClock.Minutes
    }
    Rectangle {
        id: barSurface
        objectName: "barSurface"
        anchors.fill: parent
        color: Theme.colors.surface

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.colors.border
            opacity: 0.5
        }

        RowLayout {
            id: clockGroup
            objectName: "barClockGroup"
            anchors.centerIn: parent
            spacing: 9
            ShellLabel {
                objectName: "barClock"
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: Theme.typography.sans
                font.pixelSize: 12
                wrapMode: Text.NoWrap
                Accessible.name: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy HH:mm")
            }
            ShellLabel {
                objectName: "barDate"
                visible: root.width >= 700
                text: Qt.formatDateTime(clock.date, "ddd, dd MMM")
                font.family: Theme.typography.sans
                font.pixelSize: 10
                color: Theme.colors.subtle
                wrapMode: Text.NoWrap
                Accessible.ignored: true
            }
        }

        RowLayout {
            id: leftGroup
            anchors.left: parent.left
            anchors.leftMargin: root.edgePadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.sideWidth
            spacing: root.width < 600 ? 4 : 14

            ShellButton {
                id: launcherButton
                objectName: "barLauncher"
                text: "Applications"
                Accessible.name: "Open application launcher"
                implicitWidth: 32
                implicitHeight: 32
                padding: 4
                leftPadding: padding
                rightPadding: padding
                topPadding: padding
                bottomPadding: padding
                compact: true
                quiet: true
                borderless: true
                contentItem: DistroMark {
                    objectName: "barDistroMark"
                    Accessible.ignored: true
                }
                background: Rectangle {
                    radius: Theme.metrics.controlRadius
                    color: parent.down || parent.hovered || parent.activeFocus ? Theme.colors.overlay : Qt.rgba(0, 0, 0, 0)
                }
                BarTooltip {
                    objectName: "barLauncherTooltip"
                    targetItem: launcherButton
                    text: "Applications"
                    hovered: launcherButton.hovered
                    popAbove: root.popAbove
                }
                onClicked: root.launcherRequested()
            }
            ShellLabel {
                id: preview
                objectName: "barPreview"
                visible: root.popAbove
                text: "Preview"
                color: Theme.colors.warning
                font.family: Theme.typography.sans
                font.pixelSize: root.width < 600 ? 10 : 11
                wrapMode: Text.NoWrap
            }
            BarScrollStrip {
                id: workspaceViewport
                objectName: "barWorkspaceViewport"
                Layout.preferredWidth: Math.min(workspaceRow.implicitWidth, root.width * (root.width < 600 ? 0.23 : 0.35), Math.max(32, root.sideWidth - 32 - (preview.visible ? preview.implicitWidth : 0) - leftGroup.spacing * (preview.visible ? 2 : 1)))
                Layout.maximumWidth: Layout.preferredWidth
                Layout.minimumWidth: root.workspaceCount > 0 ? 32 : 0
                visible: root.workspaceCount > 0
                Layout.preferredHeight: 32
                contentWidth: workspaceRow.implicitWidth
                contentHeight: height
                Row {
                    id: workspaceRow
                    spacing: 2
                    Repeater {
                        model: root.screenWorkspaces
                        ShellButton {
                            id: workspaceButton
                            required property var modelData
                            objectName: "workspace-" + modelData.id
                            width: 32
                            height: 32
                            padding: 0
                            leftPadding: padding
                            rightPadding: padding
                            topPadding: padding
                            bottomPadding: padding
                            text: modelData.name
                            selected: modelData.active
                            quiet: true
                            borderless: true
                            selectedBackground: Qt.rgba(0, 0, 0, 0)
                            Accessible.name: "Workspace " + modelData.name + (modelData.active ? ", active" : "") + (modelData.urgent ? ", urgent" : "")
                            Accessible.selected: selected
                            contentItem: Item {
                                Rectangle {
                                    objectName: "workspaceDot"
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 8
                                    radius: 4
                                    visible: !workspaceButton.selected
                                    color: workspaceButton.modelData.urgent ? Theme.colors.warning : Theme.colors.border
                                }
                                Rectangle {
                                    objectName: "workspaceActiveMarker"
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 8
                                    radius: 4
                                    color: workspaceButton.modelData.urgent ? Theme.colors.warning : Theme.colors.accent
                                    visible: workspaceButton.selected
                                }
                            }
                            background: Rectangle {
                                radius: Theme.metrics.controlRadius
                                color: workspaceButton.down || workspaceButton.hovered || workspaceButton.activeFocus ? Theme.colors.overlay : Qt.rgba(0, 0, 0, 0)
                            }
                            BarTooltip {
                                targetItem: workspaceButton
                                text: workspaceButton.Accessible.name
                                hovered: workspaceButton.hovered
                                popAbove: root.popAbove
                            }
                            onClicked: modelData.activate()
                            onActiveFocusChanged: if (activeFocus)
                                Qt.callLater(workspaceViewport.reveal, this)
                            onSelectedChanged: if (selected)
                                Qt.callLater(workspaceViewport.reveal, this)
                            onXChanged: if (selected)
                                Qt.callLater(workspaceViewport.reveal, this)
                            Component.onCompleted: if (selected)
                                Qt.callLater(workspaceViewport.reveal, this)
                        }
                    }
                }
            }
            ShellLabel {
                objectName: "barWorkspaceStatus"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: root.width >= 700 && (!root.services.compositorAvailable || root.workspaceCount === 0)
                text: root.services.compositorAvailable ? "No workspaces" : "Hyprland unavailable"
                color: Theme.colors.muted
                font.family: Theme.typography.sans
                font.pixelSize: 11
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            ShellLabel {
                id: title
                objectName: "barWindowTitle"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: root.width >= 900 && text.length > 0
                text: root.services.activeToplevel && root.services.activeToplevel.monitor && root.services.activeToplevel.monitor.name === root.screenName ? root.services.activeToplevel.title : ""
                font.family: Theme.typography.sans
                font.pixelSize: 12
                color: Theme.colors.muted
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            Item {
                Layout.fillWidth: true
                visible: !title.visible
            }
        }

        RowLayout {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: root.edgePadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.width < 600 ? 4 : 12

            BarScrollStrip {
                id: trayViewport
                objectName: "barTrayViewport"
                Layout.preferredWidth: Math.min(trayRow.implicitWidth, root.width * (root.width < 600 ? 0.12 : 0.16), Math.max(32, root.sideWidth - audioButton.implicitWidth - 32 - rightGroup.spacing * 2))
                Layout.maximumWidth: Layout.preferredWidth
                Layout.minimumWidth: root.trayCount > 0 ? 32 : 0
                visible: root.trayCount > 0
                Layout.preferredHeight: 28
                contentWidth: trayRow.implicitWidth
                contentHeight: height
                Row {
                    id: trayRow
                    spacing: 0
                    Repeater {
                        model: root.services.trayItems
                        BarTrayButton {
                            required property var modelData
                            trayItem: modelData
                            hostWindow: root.hostWindow
                            popAbove: root.popAbove
                            onActiveFocusChanged: if (activeFocus)
                                Qt.callLater(trayViewport.reveal, this)
                        }
                    }
                }
            }
            Rectangle {
                objectName: "barTrayDivider"
                visible: root.trayCount > 0 && root.width >= 600
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Theme.colors.border
                opacity: 0.5
            }
            ShellLabel {
                objectName: "barTrayStatus"
                visible: root.width >= 700 && root.trayCount === 0
                text: "Tray"
                Accessible.name: "No tray items; the session bus may be unavailable"
                font.family: Theme.typography.sans
                font.pixelSize: 11
                color: Theme.colors.muted
                wrapMode: Text.NoWrap
            }
            ShellButton {
                id: audioButton
                objectName: "barAudio"
                compact: true
                implicitWidth: root.width < 420 ? 32 : 64
                implicitHeight: 32
                padding: 6
                leftPadding: padding
                rightPadding: padding
                topPadding: padding
                bottomPadding: padding
                selected: root.audioOpen
                selectedBackground: Theme.colors.overlay
                selectedForeground: Theme.colors.text
                quiet: true
                borderless: true
                text: !root.services.audioAvailable ? "Audio unavailable" : root.services.muted ? "Muted" : root.width < 600 ? root.services.volumePercent + "%" : "Vol " + root.services.volumePercent + "%"
                Accessible.name: "Audio controls, " + (root.services.audioAvailable ? root.services.outputName + ", " + text : "unavailable")
                contentItem: RowLayout {
                    spacing: 6
                    ShellIcon {
                        objectName: "barAudioIcon"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        name: root.services.muted ? "speaker-muted" : "speaker"
                        color: root.services.audioAvailable ? Theme.colors.muted : Theme.colors.warning
                    }
                    ShellLabel {
                        visible: root.width >= 420
                        Layout.fillWidth: true
                        text: !root.services.audioAvailable ? "--" : root.services.muted ? "Mute" : root.services.volumePercent + "%"
                        font.family: Theme.typography.sans
                        font.pixelSize: 11
                        color: root.services.audioAvailable ? Theme.colors.text : Theme.colors.warning
                        wrapMode: Text.NoWrap
                        Accessible.ignored: true
                    }
                }
                background: Rectangle {
                    radius: Theme.metrics.controlRadius
                    color: audioButton.selected || audioButton.down || audioButton.hovered || audioButton.activeFocus ? Theme.colors.overlay : Qt.rgba(0, 0, 0, 0)
                }
                BarTooltip {
                    objectName: "barAudioTooltip"
                    targetItem: audioButton
                    text: audioButton.Accessible.name
                    hovered: audioButton.hovered
                    popAbove: root.popAbove
                }
                onClicked: root.audioRequested()
            }
            ShellButton {
                id: settingsButton
                objectName: "barAppearance"
                text: "Settings"
                Accessible.name: "Open Settings"
                implicitWidth: 32
                implicitHeight: 32
                padding: 8
                leftPadding: padding
                rightPadding: padding
                topPadding: padding
                bottomPadding: padding
                compact: true
                quiet: true
                borderless: true
                contentItem: ShellIcon {
                    objectName: "barSettingsIcon"
                    name: "settings"
                    color: Theme.colors.muted
                }
                background: Rectangle {
                    radius: Theme.metrics.controlRadius
                    color: parent.down || parent.hovered || parent.activeFocus ? Theme.colors.overlay : Qt.rgba(0, 0, 0, 0)
                }
                BarTooltip {
                    objectName: "barSettingsTooltip"
                    targetItem: settingsButton
                    text: "Settings"
                    hovered: settingsButton.hovered
                    popAbove: root.popAbove
                }
                onClicked: root.appearanceRequested()
            }
        }
    }
}
