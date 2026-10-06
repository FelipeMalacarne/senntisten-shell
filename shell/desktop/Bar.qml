import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// One instance per screen. Desktop.qml supplies the inherited screen property.
PanelWindow {
    id: root
    property bool previewMode: false
    signal launcherRequested
    signal appearanceRequested
    signal dashboardRequested
    signal settingsRequested
    property alias dashboardOpen: audioPopup.visible

    function openDashboard(restoreSettingsFocus) {
        audioPopup.visible = true;
        audioPanel.focusInitial(restoreSettingsFocus);
    }

    function closeDashboard() {
        audioPopup.visible = false;
    }

    anchors {
        top: !root.previewMode
        bottom: root.previewMode
        left: true
        right: true
    }
    implicitHeight: Theme.metrics.barHeight
    exclusiveZone: root.previewMode ? 0 : implicitHeight
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.namespace: "senntisten-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: Theme.colors.background
    onVisibleChanged: if (!visible)
        audioPopup.visible = false

    BarContent {
        id: content
        anchors.fill: parent
        screenName: root.screen ? root.screen.name : ""
        hostWindow: root
        popAbove: root.previewMode
        audioOpen: audioPopup.visible
        onLauncherRequested: {
            audioPopup.visible = false;
            root.launcherRequested();
        }
        onAppearanceRequested: {
            audioPopup.visible = false;
            root.appearanceRequested();
        }
        onAudioRequested: root.dashboardRequested()
    }

    // xdg_popup gives outside-click dismissal and keyboard focus without making
    // the bar focusable or installing compositor-wide shortcuts/focus grabs.
    PopupWindow {
        id: audioPopup
        visible: false
        grabFocus: true
        anchor.item: content.audioAnchor
        anchor.edges: root.previewMode ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
        anchor.gravity: root.previewMode ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
        implicitWidth: Math.min(340, root.screen ? root.screen.width - 16 : 340)
        implicitHeight: audioPanel.implicitHeight
        color: "transparent"
        onVisibleChanged: if (visible)
            audioPanel.focusInitial(false)
        onClosed: visible = false
        AudioPanel {
            id: audioPanel
            anchors.fill: parent
            services: content.services
            onCloseRequested: audioPopup.visible = false
            onSettingsRequested: root.settingsRequested()
        }
    }
}
