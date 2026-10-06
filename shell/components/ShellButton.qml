import QtQuick
import QtQuick.Controls
import "../services"

Button {
    id: control
    property bool primary: false
    property bool selected: false
    property bool compact: false
    property bool quiet: false
    property bool quietSelection: false
    property bool borderless: false
    property color selectedBackground: Theme.colors.accent
    property color selectedForeground: Theme.colors.accentText
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
        color: control.down ? Theme.colors.text : control.primary ? Theme.colors.accentText : control.selected ? control.selectedForeground : Theme.colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
    background: Rectangle {
        radius: 8
        opacity: control.enabled ? 1 : 0.45
        color: control.down ? Theme.colors.overlay : control.activeFocus && !control.selected ? Theme.colors.overlay : control.primary ? Theme.colors.accent : control.selected ? control.selectedBackground : control.quiet ? control.hovered ? Theme.colors.overlay : "transparent" : control.hovered ? Theme.colors.elevated : Theme.colors.surface
        border.color: control.borderless ? "transparent" : control.visualFocus ? Theme.colors.accent : control.quiet && control.quietSelection ? Theme.colors.border : control.quiet ? control.selected ? Theme.colors.accent : Theme.colors.border : control.selected ? Theme.colors.accent : Theme.colors.border
        border.width: control.borderless ? 0 : control.visualFocus ? 2 : 1
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
}
