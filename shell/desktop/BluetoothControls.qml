pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../components"
import "../services"

ColumnLayout {
    id: root
    required property var service
    spacing: 8
    Layout.minimumWidth: 0

    RowLayout {
        Layout.fillWidth: true
        ShellIcon {
            name: "bluetooth"
            color: Theme.colors.accent
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
        }
        ShellLabel {
            text: "Bluetooth"
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
    }
    ShellLabel {
        objectName: "bluetoothStatus"
        text: root.service.status
        font.pixelSize: 12
        color: Theme.colors.muted
        Layout.fillWidth: true
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        ShellButton {
            objectName: "bluetoothPower"
            text: root.service.radioEnabled ? "Turn off" : "Turn on"
            Accessible.name: root.service.radioEnabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root.service.available && !root.service.blocked && !root.service.pending
            onClicked: root.service.setEnabled(!root.service.radioEnabled)
        }
        ShellButton {
            objectName: "bluetoothScan"
            text: root.service.discovering ? "Stop scan" : "Discover"
            Accessible.name: root.service.discovering ? "Stop Bluetooth discovery" : "Discover Bluetooth devices"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root.service.available && root.service.radioEnabled && !root.service.blocked && !root.service.pending
            onClicked: root.service.setDiscovering(!root.service.discovering)
        }
    }
    ShellLabel {
        objectName: "bluetoothPending"
        text: root.service.pendingStatus
        visible: root.service.pending
        color: Theme.colors.muted
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    ShellButton {
        objectName: "bluetoothCancel"
        text: "Cancel pairing"
        Accessible.name: "Cancel pending Bluetooth pairing"
        visible: root.service.canCancel
        enabled: root.service.canCancel
        compact: true
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        onClicked: root.service.cancel()
    }
    ShellLabel {
        objectName: "bluetoothError"
        text: root.service.error
        visible: text.length > 0
        color: Theme.colors.warning
        font.pixelSize: 11
        Layout.fillWidth: true
        Accessible.name: text
    }
    Repeater {
        model: root.service.devices
        ColumnLayout {
            id: deviceRow
            required property var modelData
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3
            ShellButton {
                text: (deviceRow.modelData.connected ? "Disconnect " : deviceRow.modelData.paired ? "Connect " : "Pair ") + (deviceRow.modelData.name || deviceRow.modelData.address || "unnamed device")
                Accessible.name: (deviceRow.modelData.connected ? "Disconnect Bluetooth device " : deviceRow.modelData.paired ? "Connect Bluetooth device " : "Pair Bluetooth device ") + (deviceRow.modelData.name || deviceRow.modelData.address || "unnamed")
                compact: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: root.service.canAct(deviceRow.modelData)
                onClicked: deviceRow.modelData.connected ? root.service.disconnectDevice(deviceRow.modelData) : deviceRow.modelData.paired ? root.service.connectDevice(deviceRow.modelData) : root.service.pairDevice(deviceRow.modelData)
            }
            ShellLabel {
                text: deviceRow.modelData.blocked ? "Blocked" : deviceRow.modelData.pairing ? "Pairing" : deviceRow.modelData.state === BluetoothDeviceState.Connecting ? "Connecting" : deviceRow.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting" : deviceRow.modelData.connected ? "Connected" : deviceRow.modelData.paired ? "Paired" : "Not paired"
                font.pixelSize: 10
                color: Theme.colors.subtle
                Layout.fillWidth: true
            }
        }
    }
    ShellLabel {
        objectName: "bluetoothEmpty"
        text: root.service.radioEnabled ? "No devices reported. Start discovery to find devices." : "Turn Bluetooth on to see devices."
        visible: root.service.available && root.service.devices.length === 0
        color: Theme.colors.subtle
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    ShellLabel {
        text: "Pairing uses your existing system Bluetooth agent. PIN prompts are not provided here; native errors may report only as a timeout."
        color: Theme.colors.subtle
        font.pixelSize: 10
        Layout.fillWidth: true
    }
}
