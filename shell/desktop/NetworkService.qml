pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell.Networking
import "../lib/Connectivity.js" as Connectivity

Item {
    id: root

    // Provider requests are deliberate. Only observed properties complete an action.
    property var provider: nativeProvider
    property int actionTimeoutMs: 30000
    readonly property var devices: provider ? Connectivity.values(provider.devices) : []
    readonly property var networks: Connectivity.networks(devices)
    readonly property bool available: !!provider && provider.backendAvailable && devices.length > 0
    readonly property var wifiDevices: devices.filter(d => d.type === DeviceType.Wifi)
    readonly property bool wifiAvailable: available && wifiDevices.length > 0
    readonly property bool wifiEnabled: wifiAvailable && provider.wifiEnabled
    readonly property bool wifiHardwareEnabled: wifiAvailable && provider.wifiHardwareEnabled
    readonly property bool scanning: wifiDevices.some(d => d.scannerEnabled)
    readonly property bool pending: operation !== null || devices.some(d => changing(d.state)) || networks.some(n => n.stateChanging)
    readonly property bool canCancel: operation !== null && operation.action === "connect" && networks.indexOf(operation.target) >= 0
    readonly property string status: {
        if (!available)
            return "Network service or adapters unavailable";
        if (devices.some(d => d.state === ConnectionState.Connecting) || networks.some(n => n.state === ConnectionState.Connecting))
            return "Connecting";
        if (devices.some(d => d.state === ConnectionState.Disconnecting) || networks.some(n => n.state === ConnectionState.Disconnecting))
            return "Disconnecting";
        const active = networks.filter(n => n.connected);
        if (active.length > 0)
            return active.map(n => (n.device.type === DeviceType.Wired ? "Wired: " : "Wi-Fi: ") + (n.name || "Name unavailable")).join("; ");
        if (devices.some(d => d.connected && d.type === DeviceType.Wired))
            return "Wired connected";
        if (devices.some(d => d.connected && d.type === DeviceType.Wifi))
            return "Wi-Fi connected (name unavailable)";
        if (wifiAvailable && !wifiHardwareEnabled)
            return "Wi-Fi hardware blocked";
        if (wifiAvailable && !wifiEnabled)
            return "Wi-Fi off";
        return "Disconnected";
    }
    property string error: ""
    readonly property string pendingStatus: operation ? ({
            connect: "Connection requested",
            disconnect: "Disconnection requested",
            deviceDisconnect: "Disconnection requested",
            wifi: "Wi-Fi change requested",
            scan: "Scan change requested"
        })[operation.action] : pending ? "Network state is changing" : ""
    property var operation: null

    function changing(state) {
        return state === ConnectionState.Connecting || state === ConnectionState.Disconnecting;
    }
    function clearError() {
        error = "";
    }
    function canConnect(network) {
        return available && !pending && networks.indexOf(network) >= 0 && !network.connected && !network.stateChanging && (network.device.type !== DeviceType.Wifi || (wifiEnabled && wifiHardwareEnabled && (network.known || network.security === WifiSecurityType.Open)));
    }
    function connectNetwork(network) {
        if (!canConnect(network)) {
            if (!pending && networks.indexOf(network) >= 0 && network.device.type === DeviceType.Wifi && !network.known && network.security !== WifiSecurityType.Open)
                error = Connectivity.failure("authentication", false);
            return false;
        }
        return request("connect", network, true);
    }
    function disconnectNetwork(network) {
        if (!available || pending || networks.indexOf(network) < 0 || !network.connected)
            return false;
        return request("disconnect", network, false);
    }
    function disconnectDevice(device) {
        if (!available || pending || devices.indexOf(device) < 0 || !device.connected)
            return false;
        return request("deviceDisconnect", device, false);
    }
    function setWifiEnabled(enabled) {
        if (typeof enabled !== "boolean" || !wifiAvailable || pending || (enabled && !wifiHardwareEnabled) || enabled === wifiEnabled)
            return false;
        return request("wifi", null, enabled);
    }
    function setScanning(enabled) {
        if (typeof enabled !== "boolean" || !wifiAvailable || !wifiEnabled || !wifiHardwareEnabled || pending || wifiDevices.every(d => d.scannerEnabled === enabled))
            return false;
        return request("scan", null, enabled);
    }
    function request(action, target, value) {
        error = "";
        operation = {
            action: action,
            target: target,
            value: value,
            provider: provider,
            started: Date.now()
        };
        try {
            provider.request(action, target, value);
        } catch (_) {
            fail("unknown");
            return false;
        }
        return true;
    }
    function fail(category) {
        operation = null;
        error = Connectivity.failure(category, false);
    }
    function cancel() {
        if (!canCancel)
            return false;
        const current = operation;
        operation = null;
        try {
            current.provider.cancel(current.action, current.target);
            error = "Connection cancellation requested; state may still change.";
        } catch (_) {
            error = Connectivity.failure("unknown", false);
        }
        return true;
    }
    function reconcile() {
        const current = operation;
        if (!current)
            return;
        if (!available || provider !== current.provider) {
            fail("unavailable");
            return;
        }
        const target = current.target;
        if (target && (current.action === "deviceDisconnect" ? devices : networks).indexOf(target) < 0) {
            fail("disappeared");
            return;
        }
        if ((current.action === "connect" && target.device.type === DeviceType.Wifi || current.action === "scan" && current.value) && (!wifiEnabled || !wifiHardwareEnabled)) {
            fail("disabled");
            return;
        }
        let complete = false;
        switch (current.action) {
        case "connect":
            complete = target.connected && target.state === ConnectionState.Connected;
            break;
        case "disconnect":
        case "deviceDisconnect":
            complete = !target.connected && target.state === ConnectionState.Disconnected;
            break;
        case "wifi":
            complete = provider.wifiEnabled === current.value;
            break;
        case "scan":
            complete = wifiDevices.length > 0 && wifiDevices.every(d => d.scannerEnabled === current.value);
            break;
        }
        if (complete) {
            operation = null;
        } else if (Date.now() - current.started >= actionTimeoutMs) {
            fail("timeout");
        }
    }

    Item {
        id: nativeProvider
        readonly property var devices: Networking.devices.values
        readonly property bool backendAvailable: Networking.backend !== NetworkBackendType.None
        readonly property bool wifiEnabled: Networking.wifiEnabled
        readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
        signal failed(string category)
        function request(action, target, value) {
            switch (action) {
            case "connect":
                target.connect();
                break;
            case "disconnect":
                target.disconnect();
                break;
            case "deviceDisconnect":
                target.disconnect();
                break;
            case "wifi":
                Networking.wifiEnabled = value;
                break;
            case "scan":
                for (const device of root.wifiDevices)
                    device.scannerEnabled = value;
                break;
            }
        }
        function cancel(action, target) {
            if (action === "connect")
                target.disconnect();
        }
    }
    Connections {
        target: root.provider
        function onFailed(category) {
            root.fail(category);
        }
    }
    Instantiator {
        model: root.networks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                if (!root.operation || root.operation.target === modelData) {
                    const category = reason === ConnectionFailReason.NoSecrets ? "authentication" : reason === ConnectionFailReason.WifiAuthTimeout ? "authentication" : reason === ConnectionFailReason.WifiNetworkLost || reason === ConnectionFailReason.WifiClientDisconnected ? "lost" : "unknown";
                    root.fail(category);
                }
            }
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: root.operation !== null
        onTriggered: root.reconcile()
    }
}
