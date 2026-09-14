import QtQuick
import Quickshell
import Quickshell.Wayland

// The parent owns opened and the inherited screen; this component only requests dismissal.
PanelWindow {
    id: root
    property bool opened: false
    signal dismissed()

    visible: opened
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "senntisten-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function resetSearch() {
        content.resetSearch();
    }
    onVisibleChanged: if (visible) Qt.callLater(resetSearch)

    LauncherContent {
        id: content
        anchors.fill: parent
        onDismissed: root.dismissed()
    }
}
