import QtQuick
import Quickshell
import Quickshell.Io
import "services"

FloatingWindow {
    id: window
    title: "Senntisten · Theme playground"
    implicitWidth: 1080
    implicitHeight: 820
    minimumSize: Qt.size(620, 480)
    color: Theme.colors.background
    onClosed: Qt.quit()
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
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

    property alias view: canvas
    Playground {
        id: canvas
        anchors.fill: parent
    }

    IpcHandler {
        target: "senntisten"
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
                background: canvas.color.toString(),
                saveStatus: Theme.saveStatus,
                message: Theme.message,
                writable: Theme.writable
            });
        }
    }
}
