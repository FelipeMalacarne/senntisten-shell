import QtQuick
import "../services"

Text {
    color: Theme.colors.text
    font.family: "Noto Sans"
    font.pixelSize: 14
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    renderType: Text.QtRendering
    Behavior on color {
        ColorAnimation {
            duration: Theme.animationDuration
        }
    }
}
