import QtQuick
import QtQuick.Controls
import "../services"

Pane {
    padding: 22
    background: Rectangle {
        radius: 14
        color: Theme.colors.surface
        border.color: Theme.colors.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
}
