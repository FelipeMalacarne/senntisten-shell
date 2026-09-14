import QtQuick
import QtQuick.Controls
import "../services"

Button {
    id: control
    property bool primary: false
    property bool selected: false
    property bool compact: false
    implicitHeight: compact ? 32 : 40
    leftPadding: 14
    rightPadding: 14
    topPadding: 6
    bottomPadding: 6
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    contentItem: ShellLabel {
        text: control.text
        font.pixelSize: 13
        font.weight: Font.Medium
        color: control.primary ? Theme.colors.accentText : Theme.colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
    background: Rectangle {
        radius: 8
        opacity: control.enabled ? 1 : 0.45
        color: control.down ? Theme.colors.overlay : control.primary ? Theme.colors.accent : control.hovered || control.selected ? Theme.colors.elevated : Theme.colors.surface
        border.color: control.visualFocus || control.selected ? Theme.colors.accent : Theme.colors.border
        border.width: control.visualFocus ? 2 : 1
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
}
