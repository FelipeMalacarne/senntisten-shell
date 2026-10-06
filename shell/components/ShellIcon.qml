import QtQuick
import QtQuick.Shapes
import "../services"

Item {
    id: root
    property string name: "search"
    property color color: Theme.colors.text
    implicitWidth: 20
    implicitHeight: 20
    Accessible.ignored: true
    layer.enabled: true

    readonly property string geometry: {
        switch (name) {
        case "settings":
            return "M10 3l-1 3-3-1-2 4 2 3-2 3 2 4 3-1 1 3h4l1-3 3 1 2-4-2-3 2-3-2-4-3 1-1-3Z M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6Z";
        case "search":
            return "M10.5 4a6.5 6.5 0 1 0 0 13 6.5 6.5 0 1 0 0-13Z M16 16l5 5";
        case "close":
            return "M6 6l12 12M6 18L18 6";
        case "speaker":
            return "M4 9h4l5-4v14l-5-4H4Z M17 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14";
        case "speaker-muted":
            return "M4 9h4l5-4v14l-5-4H4Z M17 9l5 6m-5 0l5-6";
        case "arrow":
            return "M4 12h16m-6-6l6 6-6 6";
        case "chevron-up":
            return "M6 15l6-6 6 6";
        case "chevron-down":
            return "M6 9l6 6 6-6";
        case "plus":
            return "M5 12h14M12 5v14";
        case "minus":
            return "M5 12h14";
        case "monitor":
            return "M3 3h18v13H3Z M12 16v5m-5 0h10";
        case "check":
            return "M5 12l4 4L19 6";
        case "wifi":
            return "M3 9a15 15 0 0 1 18 0M6 12a10 10 0 0 1 12 0m-9 3a5 5 0 0 1 6 0M12 19h.01";
        case "bluetooth":
            return "M7 7l10 10-5 5V2l5 5L7 17";
        case "sun":
            return "M12 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8Z M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5";
        case "accessibility":
            return "M12 3a2 2 0 1 0 0 4 2 2 0 1 0 0-4Z M4 9l8 2 8-2M12 11v5m0 0-4 6m4-6 4 6";
        default:
            return "";
        }
    }

    Item {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: Math.min(root.width, root.height) / 24

        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.7
                fillColor: Qt.rgba(0, 0, 0, 0)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.geometry
                }
            }
        }
    }
}
