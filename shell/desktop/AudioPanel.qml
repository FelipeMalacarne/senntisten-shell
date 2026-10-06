import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../components"
import "../services"

Surface {
    id: root
    required property var services
    property string connectivityPage: ""
    signal closeRequested
    signal settingsRequested
    padding: Theme.metrics.panelPadding
    implicitWidth: Theme.metrics.controlsWidth
    implicitHeight: content.implicitHeight + header.implicitHeight + 12 + topPadding + bottomPadding
    Keys.onEscapePressed: root.closeRequested()

    function focusInitial(restoreSettingsFocus) {
        if (restoreSettingsFocus)
            settingsButton.forceActiveFocus();
        else if (volumeSlider.enabled)
            volumeSlider.forceActiveFocus();
        else
            closeButton.forceActiveFocus();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            id: header
            Layout.fillWidth: true
            ShellLabel {
                text: "YOUR DESKTOP"
                color: Theme.colors.subtle
                font.family: Theme.typography.mono
                font.pixelSize: 9
                font.letterSpacing: 1.1
                Layout.fillWidth: true
            }
            ShellIconButton {
                id: closeButton
                objectName: "audioClose"
                text: "Close Quick Controls"
                Accessible.name: "Close Quick Controls"
                onClicked: root.closeRequested()
            }
        }
        ShellScrollView {
            id: scroll
            objectName: "quickControlsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            ColumnLayout {
                id: content
                width: scroll.availableWidth
                spacing: 12
                ShellLabel {
                    text: "Your space"
                    font.family: Theme.typography.serif
                    font.pixelSize: 25
                    Layout.fillWidth: true
                }
                ShellLabel {
                    text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                    color: Theme.colors.muted
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            {
                                name: "quickNetwork",
                                page: "network",
                                title: "Network",
                                icon: "wifi",
                                service: root.services.network
                            },
                            {
                                name: "quickBluetooth",
                                page: "bluetooth",
                                title: "Bluetooth",
                                icon: "bluetooth",
                                service: root.services.bluetooth
                            }
                        ]
                        ShellButton {
                            required property var modelData
                            objectName: modelData.name
                            text: modelData.title
                            selected: root.connectivityPage === modelData.page
                            selectedBackground: Theme.colors.elevated
                            selectedForeground: Theme.colors.accent
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            implicitHeight: 76
                            Accessible.name: modelData.title + ", " + modelData.service.status + (modelData.service.error ? ", " + modelData.service.error : "")
                            Accessible.checkable: true
                            Accessible.checked: selected
                            onClicked: root.connectivityPage = selected ? "" : modelData.page
                            contentItem: ColumnLayout {
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    ShellIcon {
                                        name: modelData.icon
                                        color: Theme.colors.accent
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    ShellIcon {
                                        name: "arrow"
                                        color: Theme.colors.subtle
                                        rotation: root.connectivityPage === modelData.page ? 90 : 0
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                    }
                                }
                                ShellLabel {
                                    text: modelData.title
                                    font.pixelSize: 11
                                    color: Theme.colors.muted
                                }
                                ShellLabel {
                                    objectName: modelData.name + "Status"
                                    text: modelData.service.error || modelData.service.status
                                    font.pixelSize: 9
                                    color: modelData.service.error ? Theme.colors.warning : Theme.colors.subtle
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }
                }
                NetworkControls {
                    objectName: "quickNetworkDetails"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: root.connectivityPage === "network"
                    service: root.services.network
                }
                BluetoothControls {
                    objectName: "quickBluetoothDetails"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: root.connectivityPage === "bluetooth"
                    service: root.services.bluetooth
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
                    visible: root.services.audioAvailable && text.length > 0
                    Layout.fillWidth: true
                    color: Theme.colors.muted
                    font.pixelSize: 12
                }
                RowLayout {
                    Layout.fillWidth: true
                    ShellLabel {
                        text: "Output volume"
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
                    implicitHeight: 28
                    value: root.services.volume
                    enabled: root.services.audioAvailable
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: "Output volume"
                    // Only user moves write to PipeWire. External changes keep the binding.
                    onMoved: root.services.setVolume(value)
                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        height: 6
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
                        width: 18
                        height: 18
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
                        Accessible.checkable: true
                        Accessible.checked: root.services.muted
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
                AudioDevices {
                    objectName: "audioDevices"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    services: root.services
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.colors.border
                }
                MicrophoneControls {
                    objectName: "microphoneControls"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    services: root.services
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.colors.border
                }
                MediaControls {
                    objectName: "mediaControls"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    service: root.services.media
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.colors.border
                }
                ShellButton {
                    id: settingsButton
                    objectName: "quickSettings"
                    text: "Settings"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 56
                    quiet: true
                    borderless: true
                    leftPadding: 0
                    rightPadding: 0
                    Accessible.name: "Open Settings"
                    onClicked: root.settingsRequested()
                    contentItem: RowLayout {
                        spacing: 12
                        ShellIcon {
                            name: "settings"
                            color: Theme.colors.muted
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            ShellLabel {
                                text: "Settings"
                                font.pixelSize: 13
                            }
                            ShellLabel {
                                text: "Appearance and desktop preferences"
                                font.pixelSize: 10
                                color: Theme.colors.muted
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
                        ShellIcon {
                            name: "arrow"
                            color: Theme.colors.muted
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                        }
                    }
                }
            }
        }
    }
}
