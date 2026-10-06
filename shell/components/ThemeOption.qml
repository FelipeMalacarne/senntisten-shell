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
    implicitHeight: 64
    padding: 10
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.role: Accessible.RadioButton
    Accessible.checkable: true
    Accessible.checked: selected
    background: Rectangle {
        color: control.selected ? Theme.colors.elevated : control.hovered ? Theme.colors.overlay : "transparent"
        radius: 7
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.colors.accent : control.selected ? Theme.colors.border : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.animationDuration
            }
        }
    }
    contentItem: RowLayout {
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                ShellLabel {
                    objectName: "themeOptionLabel"
                    Layout.fillWidth: true
                    text: control.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                ShellLabel {
                    visible: control.selected
                    text: "ACTIVE"
                    color: Theme.colors.accent
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
            }
            ShellLabel {
                Layout.fillWidth: true
                text: control.description
                color: Theme.colors.muted
                font.pixelSize: 10
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
        RowLayout {
            spacing: 3
            Repeater {
                model: ["background", "surface", "elevated", "muted", "accent"]
                Rectangle {
                    required property string modelData
                    Layout.preferredWidth: 13
                    Layout.preferredHeight: 13
                    radius: 6.5
                    color: control.previewColors[modelData]
                    border.color: Theme.colors.border
                }
            }
        }
        Rectangle {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
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
}
