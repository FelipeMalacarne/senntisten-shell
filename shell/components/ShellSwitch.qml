import QtQuick
import QtQuick.Controls
import "../services"

Switch {
    id: control
    implicitHeight: 32
    spacing: 12
    padding: 2
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 23
        x: control.leftPadding
        y: (control.height - height) / 2
        radius: 12
        color: control.checked ? Theme.colors.accent : Theme.colors.elevated
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.colors.accent : Theme.colors.border
        Rectangle {
            x: control.checked ? parent.width - width - 4 : 4
            y: (parent.height - height) / 2
            width: 15
            height: 15
            radius: 8
            color: control.checked ? Theme.colors.accentText : Theme.colors.text
            Behavior on x {
                NumberAnimation {
                    duration: Theme.animationDuration
                }
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
    contentItem: ShellLabel {
        objectName: "motionLabel"
        text: control.text
        font.pixelSize: 13
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
    }
}
