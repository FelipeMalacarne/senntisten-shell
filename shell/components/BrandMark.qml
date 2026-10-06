import QtQuick
import "../services"

Item {
    implicitWidth: 28
    implicitHeight: 30
    Rectangle {
        x: 4
        y: 3
        width: 18
        height: 4
        radius: 1
        color: Theme.colors.accent
        rotation: -24
    }
    Rectangle {
        x: 6
        y: 13
        width: 17
        height: 4
        radius: 1
        color: Theme.colors.accent
        rotation: 24
    }
    Rectangle {
        x: 4
        y: 23
        width: 18
        height: 4
        radius: 1
        color: Theme.colors.accent
        rotation: -24
    }
    Rectangle {
        x: 12
        y: 11
        width: 4
        height: 8
        radius: 2
        color: Theme.colors.accent
    }
}
