import QtQuick
import QtQuick.Controls
import "../services"

Pane {
    padding: Theme.metrics.panelPadding
    background: Rectangle {
        radius: Theme.metrics.panelRadius
        color: Theme.colors.surface
        border.color: Theme.colors.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
}
