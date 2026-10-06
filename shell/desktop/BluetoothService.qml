import QtQuick
import Quickshell.Bluetooth
import "../lib/Connectivity.js" as Connectivity

Item {
    id: root
    property var provider: nativeProvider
    property int actionTimeoutMs: 30000
    readonly property var adapters: provider ? Connectivity.values(provider.adapters) : []
    readonly property var adapter: provider && adapters.indexOf(provider.defaultAdapter) >= 0 ? provider.defaultAdapter : adapters.length > 0 ? adapters[0] : null
    readonly property var devices: adapter ? Connectivity.values(adapter.devices) : []
    readonly property bool available: adapter !== null
    readonly property bool radioEnabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool discovering: available && adapter.discovering
    readonly property bool pending: operation !== null || adapters.some(a => a.state === BluetoothAdapterState.Enabling || a.state === BluetoothAdapterState.Disabling) || devices.some(d => d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
    readonly property bool canCancel: operation !== null && operation.action === "pair" && devices.indexOf(operation.target) >= 0
    readonly property string status: {
        if (!available)
            return "Bluetooth adapter unavailable";
        switch (adapter.state) {
        case BluetoothAdapterState.Blocked:
            return "Bluetooth hardware blocked";
        case BluetoothAdapterState.Enabling:
            return "Bluetooth turning on";
        case BluetoothAdapterState.Disabling:
            return "Bluetooth turning off";
        case BluetoothAdapterState.Disabled:
            return "Bluetooth off";
        }
        if (devices.some(d => d.pairing))
            return "Bluetooth pairing";
        if (devices.some(d => d.state === BluetoothDeviceState.Connecting))
            return "Bluetooth connecting";
        if (devices.some(d => d.state === BluetoothDeviceState.Disconnecting))
            return "Bluetooth disconnecting";
        const connected = devices.filter(d => d.connected).length;
        return discovering ? "Bluetooth discovering" : connected > 0 ? "Bluetooth on, " + connected + " connected" : "Bluetooth on";
    }
    property string error: ""
    readonly property string pendingStatus: operation ? ({
            power: "Power change requested",
            discovery: "Discovery change requested",
            pair: "Pairing requested",
            connect: "Connection requested",
            disconnect: "Disconnection requested"
        })[operation.action] : pending ? "Bluetooth state is changing" : ""
    property var operation: null

    function clearError() {
        error = "";
    }
    function setEnabled(value) {
        if (typeof value !== "boolean" || !available || pending || blocked || value === radioEnabled)
            return false;
        return request("power", adapter, value);
    }
    function setDiscovering(value) {
        if (typeof value !== "boolean" || !available || !radioEnabled || blocked || pending || value === discovering)
            return false;
        return request("discovery", adapter, value);
    }
    function canAct(device) {
        return available && radioEnabled && !blocked && !pending && devices.indexOf(device) >= 0 && !device.blocked;
    }
    function pairDevice(device) {
        if (!canAct(device) || device.paired || device.pairing)
            return false;
        return request("pair", device, true);
    }
    function connectDevice(device) {
        if (!canAct(device) || !device.paired || device.connected)
            return false;
        return request("connect", device, true);
    }
    function disconnectDevice(device) {
        if (!canAct(device) || !device.connected)
            return false;
        return request("disconnect", device, false);
    }
    function request(action, target, value) {
        error = "";
        operation = {
            action: action,
            target: target,
            value: value,
            provider: provider,
            adapter: adapter,
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
        error = Connectivity.failure(category, true);
    }
    function cancel() {
        if (!canCancel)
            return false;
        const current = operation;
        operation = null;
        try {
            current.provider.cancel(current.action, current.target);
            error = "Pairing cancellation requested; state may still change.";
        } catch (_) {
            error = Connectivity.failure("unknown", true);
        }
        return true;
    }
    function reconcile() {
        const current = operation;
        if (!current)
            return;
        if (!available || provider !== current.provider || adapter !== current.adapter) {
            fail("unavailable");
            return;
        }
        if ((current.action === "power" || current.action === "discovery" ? adapters : devices).indexOf(current.target) < 0) {
            fail("disappeared");
            return;
        }
        if ((current.action === "pair" || current.action === "connect" || current.action === "discovery" && current.value) && (!radioEnabled || blocked)) {
            fail("disabled");
            return;
        }
        const target = current.target;
        let complete = false;
        switch (current.action) {
        case "power":
            complete = target.enabled === current.value && target.state === (current.value ? BluetoothAdapterState.Enabled : BluetoothAdapterState.Disabled);
            break;
        case "discovery":
            complete = target.discovering === current.value;
            break;
        case "pair":
            complete = target.paired && !target.pairing;
            break;
        case "connect":
            complete = target.connected && target.state === BluetoothDeviceState.Connected;
            break;
        case "disconnect":
            complete = !target.connected && target.state === BluetoothDeviceState.Disconnected;
            break;
        }
        if (complete) {
            operation = null;
        } else if (Date.now() - current.started >= actionTimeoutMs) {
            if (canCancel)
                cancel();
            fail("timeout");
        }
    }

    Item {
        id: nativeProvider
        readonly property var adapters: Bluetooth.adapters.values
        readonly property var defaultAdapter: Bluetooth.defaultAdapter
        // The pin has no native operation-error signal. Timeouts remain honest.
        signal failed(string category)
        function request(action, target, value) {
            switch (action) {
            case "power":
                target.enabled = value;
                break;
            case "discovery":
                target.discovering = value;
                break;
            case "pair":
                target.pair();
                break;
            case "connect":
                target.connect();
                break;
            case "disconnect":
                target.disconnect();
                break;
            }
        }
        function cancel(action, target) {
            if (action === "pair")
                target.cancelPair();
        }
    }
    Connections {
        target: root.provider
        function onFailed(category) {
            root.fail(category);
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: root.operation !== null
        onTriggered: root.reconcile()
    }
}
