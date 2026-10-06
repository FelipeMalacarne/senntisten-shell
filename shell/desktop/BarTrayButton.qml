import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import "../components"
import "../services"

ShellButton {
    id: root
    required property var trayItem
    property var hostWindow: null
    property bool popAbove: false
    objectName: "tray-" + trayItem.id
    text: trayItem.title || trayItem.id
    compact: true
    quiet: true
    width: 32
    leftPadding: 6
    rightPadding: 6
    primary: trayItem.status === Status.NeedsAttention
    Accessible.name: text
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: trayItem.tooltipTitle || text

    function openMenu() {
        if (!trayItem.hasMenu || !hostWindow)
            return;
        const position = mapToItem(hostWindow.contentItem, 0, popAbove ? 0 : height);
        trayItem.display(hostWindow, Math.round(position.x), Math.round(position.y));
    }

    onClicked: {
        if (trayItem.onlyMenu)
            openMenu();
        else
            trayItem.activate();
    }
    Keys.onMenuPressed: openMenu()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
            openMenu();
            event.accepted = true;
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.MiddleButton)
                root.trayItem.secondaryActivate();
            else
                root.openMenu();
        }
    }
    WheelHandler {
        onWheel: event => {
            const horizontal = event.angleDelta.y === 0;
            root.trayItem.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
        }
    }
    contentItem: Item {
        implicitWidth: 20
        implicitHeight: 20
        Image {
            id: icon
            anchors.centerIn: parent
            width: 18
            height: 18
            source: root.trayItem.icon
            sourceSize.width: 18
            sourceSize.height: 18
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }
        ShellLabel {
            anchors.centerIn: parent
            text: root.text.slice(0, 1).toUpperCase()
            font.pixelSize: 12
            visible: icon.status !== Image.Ready
        }
    }
}
