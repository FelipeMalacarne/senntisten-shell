import QtQuick
import QtQuick.Controls
import "../services"

// Keep every workspace/tray item reachable without growing the panel height.
Flickable {
    id: root
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    function reveal(item) {
        if (!item)
            return;
        const left = item.mapToItem(contentItem, 0, 0).x;
        const desired = left < contentX ? left : Math.max(contentX, left + item.width - width);
        contentX = Math.max(0, Math.min(Math.max(0, contentWidth - width), desired));
    }
    ScrollBar.horizontal: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: true
        height: 3
        padding: 0
        contentItem: Rectangle {
            implicitHeight: 3
            implicitWidth: 20
            radius: 1
            color: Theme.colors.accent
        }
        background: Rectangle {
            color: Theme.colors.overlay
        }
    }
}
