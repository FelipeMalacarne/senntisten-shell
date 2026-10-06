pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
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
            name: "wifi"
            color: Theme.colors.accent
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
        }
        ShellLabel {
            text: "Network"
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
    }
    ShellLabel {
        objectName: "networkStatus"
        text: root.service.status
        font.pixelSize: 12
        color: Theme.colors.muted
        Layout.fillWidth: true
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        ShellButton {
            objectName: "networkWifi"
            text: root.service.wifiEnabled ? "Wi-Fi off" : "Wi-Fi on"
            Accessible.name: root.service.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root.service.wifiAvailable && !root.service.pending && (root.service.wifiEnabled || root.service.wifiHardwareEnabled)
            onClicked: root.service.setWifiEnabled(!root.service.wifiEnabled)
        }
        ShellButton {
            objectName: "networkScan"
            text: root.service.scanning ? "Stop scan" : "Scan"
            Accessible.name: root.service.scanning ? "Stop Wi-Fi scanning" : "Scan Wi-Fi networks"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            enabled: root.service.wifiAvailable && root.service.wifiEnabled && root.service.wifiHardwareEnabled && !root.service.pending
            onClicked: root.service.setScanning(!root.service.scanning)
        }
    }
    ShellLabel {
        objectName: "networkPending"
        text: root.service.pendingStatus
        visible: root.service.pending
        color: Theme.colors.muted
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    ShellButton {
        objectName: "networkCancel"
        text: "Cancel connection"
        Accessible.name: "Cancel pending network connection"
        visible: root.service.canCancel
        enabled: root.service.canCancel
        compact: true
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        onClicked: root.service.cancel()
    }
    ShellLabel {
        objectName: "networkError"
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
            id: adapterRow
            required property var modelData
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: modelData.connected
            ShellButton {
                text: "Disconnect " + (adapterRow.modelData.name || "adapter")
                Accessible.name: "Disconnect network adapter " + (adapterRow.modelData.name || "unnamed")
                compact: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: root.service.available && !root.service.pending && adapterRow.modelData.connected
                onClicked: root.service.disconnectDevice(adapterRow.modelData)
            }
        }
    }
    Repeater {
        model: root.service.networks
        ColumnLayout {
            id: networkRow
            required property var modelData
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3
            ShellButton {
                text: (networkRow.modelData.connected ? "Disconnect " : "Connect ") + (networkRow.modelData.name || "unnamed network")
                Accessible.name: (networkRow.modelData.connected ? "Disconnect network " : "Connect to network ") + (networkRow.modelData.name || "unnamed")
                compact: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: networkRow.modelData.connected ? root.service.available && !root.service.pending : root.service.canConnect(networkRow.modelData)
                onClicked: networkRow.modelData.connected ? root.service.disconnectNetwork(networkRow.modelData) : root.service.connectNetwork(networkRow.modelData)
            }
            ShellLabel {
                text: networkRow.modelData.device.type === DeviceType.Wired ? "Wired" : networkRow.modelData.connected ? "Connected" : networkRow.modelData.stateChanging ? "Connection changing" : !networkRow.modelData.known && networkRow.modelData.security !== WifiSecurityType.Open ? "Secured: external credential agent required" : networkRow.modelData.known ? "Saved Wi-Fi" : "Open Wi-Fi"
                font.pixelSize: 10
                color: Theme.colors.subtle
                Layout.fillWidth: true
            }
        }
    }
    ShellLabel {
        objectName: "networkEmpty"
        text: "No networks reported. Scan Wi-Fi or check the wired link."
        visible: root.service.available && root.service.networks.length === 0
        color: Theme.colors.subtle
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    ShellLabel {
        text: "Only open or saved connections are supported here. Credentials stay with NetworkManager's external agent."
        color: Theme.colors.subtle
        font.pixelSize: 10
        Layout.fillWidth: true
    }
}
