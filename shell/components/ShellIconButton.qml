import QtQuick
import "../services"

ShellButton {
    id: control
    property string iconName: "close"
    text: "Close"
    compact: true
    quiet: true
    borderless: true
    implicitWidth: 32
    implicitHeight: 32
    padding: 7
    leftPadding: padding
    rightPadding: padding
    topPadding: padding
    bottomPadding: padding
    contentItem: ShellIcon {
        name: control.iconName
        color: Theme.colors.muted
    }
    background: Rectangle {
        radius: Theme.metrics.controlRadius
        color: control.down || control.hovered || control.visualFocus ? Theme.colors.elevated : "transparent"
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.colors.accent
    }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
