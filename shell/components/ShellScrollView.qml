import QtQuick
import QtQuick.Controls
import "../services"

ScrollView {
    id: root
    property string scrollbarName: ""
    readonly property alias scrollBar: scrollbar
    clip: true
    contentWidth: availableWidth

    function reveal(item) {
        const viewport = contentItem;
        if (!item || !viewport || !viewport.contentItem)
            return;
        let ancestor = item;
        while (ancestor && ancestor !== viewport.contentItem)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const point = item.mapToItem(viewport.contentItem, 0, 0);
        const minimum = viewport.originY;
        const maximum = Math.max(minimum, minimum + viewport.contentHeight - viewport.height);
        if (point.y - 8 < viewport.contentY)
            viewport.contentY = Math.max(minimum, point.y - 8);
        else if (point.y + item.height + 8 > viewport.contentY + viewport.height)
            viewport.contentY = Math.min(maximum, point.y + item.height + 8 - viewport.height);
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            Qt.callLater(root.reveal, root.Window.window.activeFocusItem);
        }
    }
    ScrollBar.vertical: ScrollBar {
        id: scrollbar
        objectName: root.scrollbarName
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Theme.colors.subtle
        }
        background: Rectangle {
            color: "transparent"
        }
    }
}
