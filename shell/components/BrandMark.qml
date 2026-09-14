import QtQuick
import "../services"

Item {
    implicitWidth: 28
    implicitHeight: 30
    Rectangle {
        x: 3
        y: 12
        width: 5
        height: 15
        radius: 1
        color: Theme.colors.accent
    }
    Rectangle {
        x: 11
        y: 3
        width: 5
        height: 24
        radius: 1
        color: Theme.colors.accent
    }
    Rectangle {
        x: 19
        y: 12
        width: 5
        height: 15
        radius: 1
        color: Theme.colors.accent
    }
    Rectangle {
        x: 3
        y: 25
        width: 21
        height: 3
        radius: 1
        color: Theme.colors.accent
    }
}
