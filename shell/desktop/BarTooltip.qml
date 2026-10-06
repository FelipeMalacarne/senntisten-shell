import QtQuick
import Quickshell
import "../components"
import "../services"

PopupWindow {
    id: root
    required property Item targetItem
    required property string text
    property bool hovered: false
    property bool popAbove: false
    property bool shown: false
    visible: hovered && shown
    grabFocus: false
    // Qt Controls tooltips create an overlay that intercepts layer-bar clicks.
    // This passive surface has no input region and never takes a pointer grab.
    mask: Region {}
    anchor.item: targetItem
    anchor.edges: popAbove ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
    anchor.gravity: popAbove ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    implicitWidth: Math.min(label.implicitWidth + 24, 420)
    implicitHeight: label.implicitHeight + 16
    color: "transparent"

    onHoveredChanged: {
        shown = false;
        if (hovered)
            delay.restart();
        else
            delay.stop();
    }
    Timer {
        id: delay
        interval: 500
        onTriggered: root.shown = true
    }
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.colors.elevated
        border.color: Theme.colors.border
    }
    ShellLabel {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 24)
        text: root.text
        font.pixelSize: 11
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        Accessible.ignored: true
    }
}
