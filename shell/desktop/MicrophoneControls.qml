import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"

ColumnLayout {
    id: root
    required property var services
    spacing: 6
    ShellLabel {
        text: "Microphone"
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }
    ShellLabel {
        objectName: "microphoneStatus"
        text: root.services.microphoneStatus
        visible: text.length > 0
        color: Theme.colors.warning
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    ShellLabel {
        objectName: "microphoneName"
        text: root.services.microphoneName
        visible: root.services.microphoneAvailable && text.length > 0
        color: Theme.colors.muted
        font.pixelSize: 11
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
    RowLayout {
        Layout.fillWidth: true
        ShellLabel {
            text: "Input volume"
            Layout.fillWidth: true
        }
        ShellLabel {
            objectName: "microphonePercentage"
            text: root.services.microphoneAvailable ? root.services.microphoneVolumePercent + "%" : "Unavailable"
            font.pixelSize: 11
        }
    }
    Slider {
        id: slider
        objectName: "microphoneVolume"
        Layout.fillWidth: true
        from: 0
        to: 1
        stepSize: 0.01
        implicitHeight: 28
        value: root.services.microphoneVolume
        enabled: root.services.microphoneAvailable
        focusPolicy: Qt.StrongFocus
        Accessible.name: "Microphone volume"
        onMoved: root.services.setMicrophoneVolume(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            height: 6
            width: slider.availableWidth
            radius: 3
            color: Theme.colors.overlay
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 3
                color: Theme.colors.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: Theme.colors.accent
            border.width: slider.visualFocus ? 2 : 0
            border.color: Theme.colors.text
        }
    }
    ShellButton {
        objectName: "microphoneMute"
        text: root.services.microphoneMuted ? "Unmute microphone" : "Mute microphone"
        selected: root.services.microphoneMuted
        compact: true
        enabled: root.services.microphoneAvailable
        Accessible.checkable: true
        Accessible.checked: root.services.microphoneMuted
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        onClicked: root.services.toggleMicrophoneMute()
    }
}
