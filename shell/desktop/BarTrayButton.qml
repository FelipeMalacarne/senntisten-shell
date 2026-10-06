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
    borderless: true
    width: 28
    height: 28
    leftPadding: 6
    rightPadding: 6
    primary: trayItem.status === Status.NeedsAttention
    Accessible.name: text
    BarTooltip {
        targetItem: root
        text: root.trayItem.tooltipTitle || root.text
        hovered: root.hovered
        popAbove: root.popAbove
    }
    background: Rectangle {
        radius: 6
        color: root.down || root.hovered || root.visualFocus ? Theme.colors.elevated : "transparent"
        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.colors.accent
    }

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
            objectName: "trayIcon"
            anchors.centerIn: parent
            width: 16
            height: 16
            source: root.trayItem.icon
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }
        Rectangle {
            visible: root.trayItem.status === Status.NeedsAttention
            anchors.top: parent.top
            anchors.right: parent.right
            width: 4
            height: 4
            radius: 2
            color: Theme.colors.warning
        }
        ShellLabel {
            anchors.centerIn: parent
            text: root.text.slice(0, 1).toUpperCase()
            font.pixelSize: 12
            visible: icon.status !== Image.Ready
        }
    }
}
