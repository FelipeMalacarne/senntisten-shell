pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

ColumnLayout {
    id: root
    required property var services
    spacing: 6
    ShellLabel {
        text: "Audio output"
        Layout.fillWidth: true
        font.weight: Font.DemiBold
    }
    ShellLabel {
        objectName: "audioDevicesStatus"
        text: root.services.audioStatus || (root.services.outputs.length === 0 ? "No audio outputs" : "")
        visible: text.length > 0
        color: Theme.colors.warning
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    Repeater {
        model: root.services.outputs
        ShellButton {
            required property var modelData
            required property int index
            objectName: "audioOutput-" + index
            text: modelData.description || modelData.nickname || modelData.name
            selected: root.services.sink === modelData
            compact: true
            quiet: true
            quietSelection: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Accessible.name: "Use audio output " + text
            Accessible.role: Accessible.RadioButton
            Accessible.checkable: true
            Accessible.checked: selected
            onClicked: root.services.selectOutput(modelData)
        }
    }
}
