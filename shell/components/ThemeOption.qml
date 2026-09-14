import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "../lib/ThemeCatalog.js" as Catalog

Button {
    id: control
    required property string themeId
    required property string description
    readonly property var previewColors: Catalog.paletteFor(themeId)
    readonly property bool selected: Theme.settings.theme === themeId
    implicitWidth: 250
    implicitHeight: 116
    padding: 13
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.role: Accessible.RadioButton
    Accessible.checkable: true
    Accessible.checked: selected
    background: Rectangle {
        color: control.hovered ? Theme.colors.elevated : Theme.colors.background
        radius: 10
        border.width: control.visualFocus ? 2 : 1
        border.color: control.selected || control.visualFocus ? Theme.colors.accent : Theme.colors.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
    contentItem: ColumnLayout {
        spacing: 8
        RowLayout {
            ShellLabel {
                objectName: "themeOptionLabel"
                Layout.fillWidth: true
                text: control.text
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: control.selected ? Theme.colors.accent : "transparent"
                border.color: control.selected ? Theme.colors.accent : Theme.colors.muted
                Rectangle {
                    visible: control.selected
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.colors.accentText
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["background", "surface", "elevated", "muted", "accent"]
                Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 27
                    radius: 4
                    color: control.previewColors[modelData]
                    border.color: Theme.colors.border
                }
            }
        }
        ShellLabel {
            text: control.description
            color: Theme.colors.muted
            font.pixelSize: 11
        }
    }
}
