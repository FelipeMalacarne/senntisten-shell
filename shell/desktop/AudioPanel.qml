import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"

Surface {
    id: root
    required property var services
    signal closeRequested
    padding: 16
    implicitWidth: 340
    implicitHeight: content.implicitHeight + topPadding + bottomPadding
    Keys.onEscapePressed: root.closeRequested()

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            ShellLabel {
                text: "Audio output"
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            ShellButton {
                objectName: "audioClose"
                text: "Close"
                compact: true
                Accessible.name: "Close audio controls"
                onClicked: root.closeRequested()
            }
        }
        ShellLabel {
            objectName: "audioStatus"
            text: root.services.audioStatus
            visible: text.length > 0
            color: Theme.colors.warning
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        ShellLabel {
            objectName: "audioOutputName"
            text: root.services.outputName
            Layout.fillWidth: true
            color: Theme.colors.muted
            font.pixelSize: 12
        }
        RowLayout {
            Layout.fillWidth: true
            ShellLabel {
                text: "Volume"
                Layout.fillWidth: true
            }
            ShellLabel {
                objectName: "audioPercentage"
                text: root.services.audioAvailable ? root.services.volumePercent + "%" : "—"
                font.weight: Font.DemiBold
            }
        }
        Slider {
            id: volumeSlider
            objectName: "audioVolume"
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.01
            value: root.services.volume
            enabled: root.services.audioAvailable
            focusPolicy: Qt.StrongFocus
            Accessible.name: "Output volume"
            // Only user moves write to PipeWire. External changes keep the binding.
            onMoved: root.services.setVolume(value)
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                implicitHeight: 6
                width: volumeSlider.availableWidth
                radius: 3
                color: Theme.colors.overlay
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: Theme.colors.accent
                }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: Theme.colors.accent
                border.width: volumeSlider.visualFocus ? 2 : 0
                border.color: Theme.colors.text
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ShellButton {
                objectName: "audioDecrease"
                text: "−5%"
                compact: true
                enabled: root.services.audioAvailable
                Accessible.name: "Decrease volume by five percent"
                onClicked: root.services.setVolume(root.services.volume - 0.05)
            }
            ShellButton {
                objectName: "audioMute"
                text: root.services.muted ? "Unmute" : "Mute"
                compact: true
                selected: root.services.muted
                enabled: root.services.audioAvailable
                Layout.fillWidth: true
                onClicked: root.services.toggleMute()
            }
            ShellButton {
                objectName: "audioIncrease"
                text: "+5%"
                compact: true
                enabled: root.services.audioAvailable
                Accessible.name: "Increase volume by five percent"
                onClicked: root.services.setVolume(root.services.volume + 0.05)
            }
        }
    }
}
