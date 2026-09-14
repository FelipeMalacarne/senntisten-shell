import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../services"

Rectangle {
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
    implicitHeight: 38
    color: Theme.colors.background

    BarServices {
        id: nativeServices
    }

    SystemClock {
        id: clock
        objectName: "barClockSource"
        precision: SystemClock.Minutes
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6
        ShellButton {
            objectName: "barLauncher"
            text: "Apps"
            compact: true
            primary: true
            onClicked: root.launcherRequested()
        }
        ShellLabel {
            objectName: "barPreview"
            visible: root.popAbove
            text: "Preview"
            color: Theme.colors.warning
            font.pixelSize: 11
            wrapMode: Text.NoWrap
        }
        BarScrollStrip {
            id: workspaceViewport
            objectName: "barWorkspaceViewport"
            Layout.preferredWidth: Math.min(workspaceRow.implicitWidth, root.width * 0.35)
            Layout.maximumWidth: Layout.preferredWidth
            Layout.minimumWidth: root.workspaceCount > 0 ? 32 : 0
            Layout.fillWidth: true
            visible: root.workspaceCount > 0
            Layout.preferredHeight: 32
            contentWidth: workspaceRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: workspaceRow
                spacing: 4
                Repeater {
                    model: root.screenWorkspaces
                    ShellButton {
                        required property var modelData
                        objectName: "workspace-" + modelData.id
                        compact: true
                        width: Math.min(90, Math.max(32, implicitWidth))
                        leftPadding: 8
                        rightPadding: 8
                        text: modelData.name
                        selected: modelData.active
                        primary: modelData.urgent
                        Accessible.name: "Workspace " + modelData.name + (modelData.active ? ", active" : "") + (modelData.urgent ? ", urgent" : "")
                        onClicked: modelData.activate()
                        onActiveFocusChanged: if (activeFocus)
                            workspaceViewport.reveal(this)
                        onSelectedChanged: if (selected)
                            Qt.callLater(workspaceViewport.reveal, this)
                        onXChanged: if (selected)
                            Qt.callLater(workspaceViewport.reveal, this)
                    }
                }
            }
        }
        ShellLabel {
            objectName: "barWorkspaceStatus"
            visible: !root.services.compositorAvailable || root.workspaceCount === 0
            text: root.services.compositorAvailable ? "No workspaces on this screen" : "Hyprland unavailable"
            color: Theme.colors.warning
            font.pixelSize: 12
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            Layout.maximumWidth: root.width * 0.25
        }
        ShellLabel {
            objectName: "barWindowTitle"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: root.width >= 900 && text.length > 0
            text: root.services.activeToplevel && root.services.activeToplevel.monitor && root.services.activeToplevel.monitor.name === root.screenName ? root.services.activeToplevel.title : ""
            font.pixelSize: 12
            color: Theme.colors.muted
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
        Item {
            Layout.fillWidth: true
            visible: root.width < 900 || !root.services.activeToplevel
        }
        BarScrollStrip {
            id: trayViewport
            objectName: "barTrayViewport"
            Layout.preferredWidth: Math.min(trayRow.implicitWidth, root.width * 0.16)
            Layout.maximumWidth: Layout.preferredWidth
            Layout.minimumWidth: root.trayCount > 0 ? 32 : 0
            Layout.fillWidth: true
            visible: root.trayCount > 0
            Layout.preferredHeight: 32
            contentWidth: trayRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: trayRow
                spacing: 4
                Repeater {
                    model: root.services.trayItems
                    BarTrayButton {
                        required property var modelData
                        trayItem: modelData
                        hostWindow: root.hostWindow
                        popAbove: root.popAbove
                        onActiveFocusChanged: if (activeFocus)
                            trayViewport.reveal(this)
                    }
                }
            }
        }
        ShellLabel {
            objectName: "barTrayStatus"
            visible: root.trayCount === 0
            text: "Tray —"
            // SystemTray 0.3 has no ready/connected property: do not invent one.
            Accessible.name: "No tray items; the session bus may be unavailable"
            font.pixelSize: 12
            color: Theme.colors.muted
            wrapMode: Text.NoWrap
        }
        ShellButton {
            id: audioButton
            objectName: "barAudio"
            text: !root.services.audioAvailable ? "Audio —" : root.services.muted ? "Muted" : "Vol " + root.services.volumePercent + "%"
            compact: true
            selected: root.audioOpen
            Accessible.name: "Audio controls, " + (root.services.audioAvailable ? root.services.outputName + ", " + text : "unavailable")
            onClicked: root.audioRequested()
        }
        ShellLabel {
            objectName: "barClock"
            text: Qt.formatDateTime(clock.date, root.width >= 900 ? "ddd d MMM · HH:mm" : "HH:mm")
            font.pixelSize: 12
            wrapMode: Text.NoWrap
            Accessible.name: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy HH:mm")
        }
        ShellButton {
            objectName: "barAppearance"
            text: "Theme"
            compact: true
            onClicked: root.appearanceRequested()
        }
    }
}
