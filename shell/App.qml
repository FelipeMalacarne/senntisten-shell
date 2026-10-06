import QtQuick
import Quickshell
import Quickshell.Io
import "services"

FloatingWindow {
    id: window
    property bool standalone: true
    title: standalone ? "Senntisten · Theme playground" : "Senntisten · Settings"
    implicitWidth: standalone ? 1080 : 860
    implicitHeight: standalone ? 820 : 650
    minimumSize: standalone ? Qt.size(620, 480) : Qt.size(320, 360)
    color: Theme.colors.background
    onVisibleChanged: if (visible && !standalone)
        Qt.callLater(picker.focusInitial)
    onClosed: {
        if (standalone)
            Qt.quit();
        else
            visible = false;
    }
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: {
            if (window.standalone)
                Qt.quit();
            else
                window.visible = false;
        }
    }

    // This MVP owns only a normal window, never Quickshell's layer-shell reload popup.
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
        function onReloadFailed(error) {
            Quickshell.inhibitReloadPopup();
        }
    }

    property alias view: canvas.item
    property alias settingsView: picker
    // Do not register playground-only shortcuts in the dedicated Settings window.
    Loader {
        id: canvas
        anchors.fill: parent
        active: window.standalone
        sourceComponent: Playground {}
    }
    ThemePicker {
        id: picker
        anchors.fill: parent
        visible: !window.standalone
        onCloseRequested: window.visible = false
    }

    Component.onCompleted: if (visible && !standalone)
        Qt.callLater(picker.focusInitial)

    IpcHandler {
        target: "senntisten"
        enabled: window.standalone
        function theme(id: string): bool {
            return Theme.selectTheme(id);
        }
        function status(): string {
            return JSON.stringify({
                ready: Theme.ready,
                visible: window.visible,
                width: window.width,
                title: window.title,
                theme: Theme.settings.theme,
                background: canvas.item.color.toString(),
                saveStatus: Theme.saveStatus,
                message: Theme.message,
                writable: Theme.writable
            });
        }
    }
}
