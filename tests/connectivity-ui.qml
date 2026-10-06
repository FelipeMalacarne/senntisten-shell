import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import "desktop"
import "components"
import "services"

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 252
        implicitHeight: 760
        color: Theme.colors.background

        QtObject {
            id: wifi
            property string name: "Test Wi-Fi adapter"
            property int type: DeviceType.Wifi
            property bool connected: false
            property int state: ConnectionState.Disconnected
            property bool scannerEnabled: false
            property var networks: ({
                    values: [openNetwork, securedNetwork]
                })
        }
        QtObject {
            id: wired
            property string name: "Test Ethernet"
            property int type: DeviceType.Wired
            property bool connected: false
            property int state: ConnectionState.Disconnected
            property var networks: ({
                    values: [wiredNetwork]
                })
        }
        QtObject {
            id: openNetwork
            property string name: "Fixture cafe"
            property var device: wifi
            property bool connected: false
            property bool known: false
            property int state: ConnectionState.Disconnected
            readonly property bool stateChanging: state === ConnectionState.Connecting || state === ConnectionState.Disconnecting
            property int security: WifiSecurityType.Open
            property real signalStrength: 0.72
            signal connectionFailed(int reason)
        }
        QtObject {
            id: securedNetwork
            property string name: "Fixture secured"
            property var device: wifi
            property bool connected: false
            property bool known: false
            property int state: ConnectionState.Disconnected
            readonly property bool stateChanging: state === ConnectionState.Connecting || state === ConnectionState.Disconnecting
            property int security: WifiSecurityType.Wpa2Psk
            property real signalStrength: 0.45
            signal connectionFailed(int reason)
        }
        QtObject {
            id: wiredNetwork
            property string name: "Fixture wired profile"
            property var device: wired
            property bool connected: false
            property bool known: true
            property int state: ConnectionState.Disconnected
            readonly property bool stateChanging: state === ConnectionState.Connecting || state === ConnectionState.Disconnecting
            signal connectionFailed(int reason)
        }
        QtObject {
            id: networkProvider
            property bool backendAvailable: true
            property var devices: [wifi, wired]
            property bool wifiEnabled: true
            property bool wifiHardwareEnabled: true
            property int calls: 0
            property int cancellations: 0
            property string lastAction: ""
            property bool reject: false
            signal failed(string category)
            function request(action, target, value) {
                calls++;
                lastAction = action;
                if (reject)
                    throw new Error("Opaque provider diagnostic must not be retained");
            }
            function cancel(action, target) {
                cancellations++;
            }
        }
        QtObject {
            id: adapter
            property string name: "Fixture Bluetooth"
            property bool enabled: true
            property int state: BluetoothAdapterState.Enabled
            property bool discovering: false
            property var devices: ({
                    values: [headphones, keyboard]
                })
        }
        QtObject {
            id: headphones
            property string name: "Fixture headphones"
            property string address: "00:00:00:00:00:01"
            property bool connected: false
            property bool paired: true
            property bool pairing: false
            property bool blocked: false
            property int state: BluetoothDeviceState.Disconnected
        }
        QtObject {
            id: keyboard
            property string name: "Fixture keyboard"
            property string address: "00:00:00:00:00:02"
            property bool connected: false
            property bool paired: false
            property bool pairing: false
            property bool blocked: false
            property int state: BluetoothDeviceState.Disconnected
        }
        QtObject {
            id: bluetoothProvider
            property var adapters: [adapter]
            property var defaultAdapter: adapter
            property int calls: 0
            property int cancellations: 0
            property string lastAction: ""
            property bool reject: false
            signal failed(string category)
            function request(action, target, value) {
                calls++;
                lastAction = action;
                if (reject)
                    throw new Error("Opaque provider diagnostic must not be retained");
            }
            function cancel(action, target) {
                cancellations++;
            }
        }
        NetworkService {
            id: network
            provider: networkProvider
            actionTimeoutMs: 400
        }
        BluetoothService {
            id: bluetooth
            provider: bluetoothProvider
            actionTimeoutMs: 400
        }
        NetworkService {
            id: nativeNetwork
        }
        BluetoothService {
            id: nativeBluetooth
        }
        Component {
            id: transientNetwork
            QtObject {
                property string name: "Transient fixture"
                property var device: wifi
                property bool connected: false
                property bool known: true
                property int state: ConnectionState.Disconnected
                property bool stateChanging: false
                signal connectionFailed(int reason)
            }
        }

        ShellScrollView {
            id: scroll
            anchors.fill: parent
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12
                ShellButton {
                    id: start
                    objectName: "fixtureStart"
                    text: "Fixture focus start"
                    Layout.fillWidth: true
                }
                NetworkControls {
                    id: networkControls
                    service: network
                    Layout.fillWidth: true
                }
                BluetoothControls {
                    id: bluetoothControls
                    service: bluetooth
                    Layout.fillWidth: true
                }
            }
        }

        TestCase {
            name: "Connectivity"
            when: window.visible && Theme.ready
            property var executed: []
            property string checkpoint: ""
            function cleanup() {
                if (qtest_results.failed)
                    console.log("CONNECTIVITY_FAILED " + JSON.stringify({
                        name: qtest_results.functionName,
                        checkpoint: checkpoint,
                        network: network.status,
                        networkError: network.error,
                        networkPending: network.pending,
                        bluetooth: bluetooth.status,
                        bluetoothError: bluetooth.error,
                        bluetoothPending: bluetooth.pending,
                        focus: window.contentItem.Window.window.activeFocusItem ? window.contentItem.Window.window.activeFocusItem.objectName : "none"
                    }));
            }
            function init() {
                executed = executed.concat([qtest_results.functionName]);
                network.cancel();
                bluetooth.cancel();
                network.actionTimeoutMs = 400;
                bluetooth.actionTimeoutMs = 400;
                networkProvider.backendAvailable = true;
                networkProvider.devices = [wifi, wired];
                networkProvider.wifiEnabled = true;
                networkProvider.wifiHardwareEnabled = true;
                networkProvider.calls = 0;
                networkProvider.cancellations = 0;
                networkProvider.reject = false;
                wifi.networks = {
                    values: [openNetwork, securedNetwork]
                };
                wifi.connected = false;
                wifi.state = ConnectionState.Disconnected;
                wifi.scannerEnabled = false;
                wired.connected = false;
                wired.state = ConnectionState.Disconnected;
                for (const n of [openNetwork, securedNetwork, wiredNetwork]) {
                    n.connected = false;
                    n.state = ConnectionState.Disconnected;
                }
                securedNetwork.known = false;
                bluetoothProvider.adapters = [adapter];
                bluetoothProvider.defaultAdapter = adapter;
                bluetoothProvider.calls = 0;
                bluetoothProvider.cancellations = 0;
                bluetoothProvider.reject = false;
                adapter.devices = {
                    values: [headphones, keyboard]
                };
                adapter.enabled = true;
                adapter.state = BluetoothAdapterState.Enabled;
                adapter.discovering = false;
                for (const d of [headphones, keyboard]) {
                    d.connected = false;
                    d.pairing = false;
                    d.blocked = false;
                    d.state = BluetoothDeviceState.Disconnected;
                }
                headphones.paired = true;
                keyboard.paired = false;
                network.clearError();
                bluetooth.clearError();
                resize(252, 760);
                scroll.contentItem.contentY = 0;
                start.forceActiveFocus();
                wait(30);
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_CONNECTIVITY_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }
            function capture(name) {
                wait(160);
                const out = Quickshell.env("SENNTISTEN_CONNECTIVITY_CAPTURE_DIR");
                if (out)
                    grabImage(window.contentItem).save(out + "/" + name + ".png");
                console.log("SENNTISTEN_CONNECTIVITY_CHECKPOINT " + JSON.stringify({
                    name: name,
                    theme: Theme.settings.theme,
                    geometry: [window.contentItem.width, window.contentItem.height],
                    network: {
                        available: network.available,
                        status: network.status,
                        error: network.error,
                        pending: network.pending,
                        networks: network.networks.length
                    },
                    bluetooth: {
                        available: bluetooth.available,
                        status: bluetooth.status,
                        error: bluetooth.error,
                        pending: bluetooth.pending,
                        devices: bluetooth.devices.length
                    },
                    controls: controlEvidence(window.contentItem)
                }));
            }
            function resize(width, height) {
                const native = window.contentItem.Window.window;
                native.width = width;
                native.height = height;
                tryCompare(window.contentItem, "width", width);
                tryCompare(window.contentItem, "height", height);
                wait(30);
            }
            function controlEvidence(item) {
                let result = [];
                if (typeof item.clicked === "function" && item.down !== undefined) {
                    const point = item.mapToItem(window.contentItem, 0, 0);
                    const viewport = item.mapToItem(scroll.contentItem, 0, 0);
                    result.push({
                        objectName: item.objectName,
                        accessibleName: item.Accessible.name,
                        visible: item.visible,
                        enabled: item.enabled,
                        activeFocus: item.activeFocus,
                        visualFocus: item.visualFocus,
                        geometry: [point.x, point.y, item.width, item.height],
                        inViewport: viewport.y >= 0 && viewport.y + item.height <= scroll.contentItem.height + 1
                    });
                }
                for (const child of item.children)
                    result = result.concat(controlEvidence(child));
                return result;
            }
            function test_native_providers_are_safe_and_unavailable_on_isolated_buses() {
                compare(nativeNetwork.available, false);
                compare(nativeBluetooth.available, false);
                verify(nativeNetwork.status.length > 0);
                verify(nativeBluetooth.status.length > 0);
                compare(nativeNetwork.connectNetwork(openNetwork), false);
                compare(nativeBluetooth.connectDevice(headphones), false);
            }
            function test_network_states_live_models_and_external_busy() {
                compare(network.devices.length, 2);
                compare(network.networks.length, 3);
                compare(network.status, "Disconnected");
                wired.connected = true;
                wired.state = ConnectionState.Connected;
                tryVerify(() => network.status.indexOf("Wired") >= 0);
                wired.connected = false;
                wired.state = ConnectionState.Disconnected;
                wifi.connected = true;
                wifi.state = ConnectionState.Connected;
                openNetwork.connected = true;
                openNetwork.state = ConnectionState.Connected;
                tryVerify(() => network.status.indexOf("Fixture cafe") >= 0);
                openNetwork.state = ConnectionState.Connecting;
                tryCompare(network, "pending", true);
                compare(network.connectNetwork(securedNetwork), false);
                openNetwork.state = ConnectionState.Disconnected;
                openNetwork.connected = false;
                wifi.connected = false;
                wifi.state = ConnectionState.Disconnected;
                wifi.networks = {
                    values: []
                };
                tryCompare(network, "networks", [wiredNetwork]);
                networkProvider.devices = [];
                tryCompare(network, "available", false);
                verify(network.status.indexOf("unavailable") >= 0);
            }
            function test_network_deliberate_connect_duplicate_disconnect_and_cancel() {
                compare(network.connectNetwork(openNetwork), true);
                compare(network.pending, true);
                compare(network.connectNetwork(openNetwork), false);
                compare(networkProvider.calls, 1);
                compare(openNetwork.connected, false, "No optimistic connection");
                compare(network.canCancel, true);
                compare(network.cancel(), true);
                compare(networkProvider.cancellations, 1);
                compare(network.pending, false);
                verify(network.error.indexOf("cancel") >= 0);
                compare(network.connectNetwork(openNetwork), true);
                openNetwork.connected = true;
                openNetwork.state = ConnectionState.Connected;
                tryCompare(network, "pending", false);
                compare(network.error, "");
                compare(network.disconnectNetwork(openNetwork), true);
                compare(networkProvider.lastAction, "disconnect");
                openNetwork.connected = false;
                openNetwork.state = ConnectionState.Disconnected;
                tryCompare(network, "pending", false);
            }
            function test_network_authentication_failure_is_visible_and_secret_free() {
                compare(network.canConnect(securedNetwork), false);
                compare(network.connectNetwork(securedNetwork), false);
                compare(networkProvider.calls, 0);
                verify(network.error.indexOf("agent") >= 0);
                securedNetwork.known = true;
                compare(network.connectNetwork(securedNetwork), true);
                securedNetwork.connectionFailed(ConnectionFailReason.NoSecrets);
                tryCompare(network, "pending", false);
                verify(network.error.indexOf("Authentication") >= 0);
                verify(findChild(networkControls, "networkError").visible);
                compare(network.connectNetwork(openNetwork), true);
                networkProvider.failed("permission");
                compare(network.pending, false);
                verify(network.error.indexOf("Permission") >= 0);
            }
            function test_network_timeout_disappearance_and_provider_loss() {
                network.actionTimeoutMs = 80;
                compare(network.connectNetwork(openNetwork), true);
                tryCompare(network, "pending", false);
                verify(network.error.indexOf("timed out") >= 0);
                compare(network.connectNetwork(openNetwork), true);
                wifi.networks = {
                    values: [securedNetwork]
                };
                tryCompare(network, "pending", false);
                verify(network.error.indexOf("disappeared") >= 0);
                compare(network.connectNetwork(wiredNetwork), true);
                networkProvider.backendAvailable = false;
                tryCompare(network, "pending", false);
                compare(network.available, false);
                verify(network.error.indexOf("unavailable") >= 0);
            }
            function test_network_pending_target_can_be_destroyed_on_hotplug() {
                const transient = transientNetwork.createObject(window.contentItem);
                wifi.networks = {
                    values: [transient]
                };
                verify(network.connectNetwork(transient));
                wifi.networks = {
                    values: []
                };
                transient.destroy();
                wait(10);
                network.reconcile();
                compare(network.pending, false);
                verify(network.error.indexOf("disappeared") >= 0);
            }
            function test_network_radio_and_scan_are_deliberate_and_hardware_blocked() {
                compare(networkProvider.calls, 0);
                compare(network.setWifiEnabled(false), true);
                compare(networkProvider.lastAction, "wifi");
                compare(network.setScanning(true), false);
                networkProvider.wifiEnabled = false;
                tryCompare(network, "pending", false);
                networkProvider.wifiHardwareEnabled = false;
                compare(network.setWifiEnabled(true), false);
                verify(network.status.indexOf("blocked") >= 0);
                networkProvider.wifiHardwareEnabled = true;
                networkProvider.wifiEnabled = true;
                compare(network.setScanning(true), true);
                compare(networkProvider.lastAction, "scan");
                wifi.scannerEnabled = true;
                tryCompare(network, "pending", false);
                compare(network.scanning, true);
                compare(network.setScanning(false), true);
                wifi.scannerEnabled = false;
                tryCompare(network, "pending", false);
            }
            function test_bluetooth_live_adapter_states_and_models() {
                compare(bluetooth.devices.length, 2);
                compare(bluetooth.status, "Bluetooth on");
                adapter.state = BluetoothAdapterState.Blocked;
                tryVerify(() => bluetooth.status.indexOf("blocked") >= 0);
                compare(bluetooth.setEnabled(true), false);
                adapter.state = BluetoothAdapterState.Enabling;
                tryCompare(bluetooth, "pending", true);
                adapter.state = BluetoothAdapterState.Disabled;
                adapter.enabled = false;
                tryCompare(bluetooth, "status", "Bluetooth off");
                compare(bluetooth.connectDevice(headphones), false);
                adapter.devices = {
                    values: []
                };
                tryCompare(bluetooth, "devices", []);
                bluetoothProvider.defaultAdapter = null;
                bluetoothProvider.adapters = [];
                tryCompare(bluetooth, "available", false);
            }
            function test_bluetooth_power_discovery_pair_connect_disconnect() {
                compare(bluetoothProvider.calls, 0);
                compare(bluetooth.setEnabled(false), true);
                compare(bluetooth.setDiscovering(true), false);
                adapter.enabled = false;
                adapter.state = BluetoothAdapterState.Disabled;
                tryCompare(bluetooth, "pending", false);
                compare(bluetooth.setEnabled(true), true);
                adapter.enabled = true;
                adapter.state = BluetoothAdapterState.Enabled;
                tryCompare(bluetooth, "pending", false);
                compare(bluetooth.setDiscovering(true), true);
                adapter.discovering = true;
                tryCompare(bluetooth, "pending", false);
                compare(bluetooth.pairDevice(keyboard), true);
                compare(bluetooth.pairDevice(keyboard), false);
                compare(keyboard.paired, false);
                keyboard.pairing = true;
                compare(bluetooth.canCancel, true);
                keyboard.paired = true;
                keyboard.pairing = false;
                tryCompare(bluetooth, "pending", false);
                compare(bluetooth.connectDevice(keyboard), true);
                keyboard.connected = true;
                keyboard.state = BluetoothDeviceState.Connected;
                tryCompare(bluetooth, "pending", false);
                compare(bluetooth.disconnectDevice(keyboard), true);
                keyboard.connected = false;
                keyboard.state = BluetoothDeviceState.Disconnected;
                tryCompare(bluetooth, "pending", false);
            }
            function test_bluetooth_cancel_timeout_permission_auth_and_disappearance() {
                compare(bluetooth.pairDevice(keyboard), true);
                compare(bluetooth.cancel(), true);
                compare(bluetoothProvider.cancellations, 1);
                compare(bluetooth.pending, false);
                verify(bluetooth.error.indexOf("cancel") >= 0);
                compare(bluetooth.connectDevice(headphones), true);
                compare(bluetooth.canCancel, false, "Native connect has no cancel API");
                bluetoothProvider.failed("permission");
                verify(bluetooth.error.indexOf("Permission") >= 0);
                compare(bluetooth.pairDevice(keyboard), true);
                bluetoothProvider.failed("authentication");
                verify(bluetooth.error.indexOf("Authentication") >= 0);
                bluetooth.actionTimeoutMs = 80;
                compare(bluetooth.pairDevice(keyboard), true);
                tryCompare(bluetooth, "pending", false);
                verify(bluetooth.error.indexOf("timed out") >= 0);
                compare(bluetoothProvider.cancellations, 2);
                compare(bluetooth.connectDevice(headphones), true);
                adapter.devices = {
                    values: [keyboard]
                };
                tryCompare(bluetooth, "pending", false);
                verify(bluetooth.error.indexOf("disappeared") >= 0);
                compare(bluetooth.pairDevice(keyboard), true);
                bluetoothProvider.defaultAdapter = null;
                bluetoothProvider.adapters = [];
                tryCompare(bluetooth, "pending", false);
                verify(bluetooth.error.indexOf("unavailable") >= 0);
            }
            function test_bluetooth_external_changes_block_duplicate_actions() {
                headphones.state = BluetoothDeviceState.Connecting;
                tryCompare(bluetooth, "pending", true);
                compare(bluetooth.pairDevice(keyboard), false);
                headphones.state = BluetoothDeviceState.Connected;
                headphones.connected = true;
                tryCompare(bluetooth, "pending", false);
                verify(bluetooth.status.indexOf("1 connected") >= 0);
                keyboard.blocked = true;
                compare(bluetooth.pairDevice(keyboard), false);
                compare(bluetoothProvider.calls, 0);
            }
            function test_bluetooth_radio_state_does_not_disable_the_provider_item() {
                adapter.enabled = false;
                adapter.state = BluetoothAdapterState.Disabled;
                compare(bluetooth.radioEnabled, false);
                compare(bluetooth.enabled, true, "The provider's Item remains enabled");
                compare(bluetooth.setEnabled(true), true);
                adapter.enabled = true;
                adapter.state = BluetoothAdapterState.Enabled;
                tryCompare(bluetooth, "pending", false);
            }
            function test_pending_actions_end_when_radios_are_externally_disabled() {
                network.actionTimeoutMs = 5000;
                bluetooth.actionTimeoutMs = 5000;
                compare(network.connectNetwork(openNetwork), true);
                networkProvider.wifiEnabled = false;
                tryCompare(network, "pending", false, 200);
                verify(network.error.indexOf("turned off") >= 0);
                compare(bluetooth.connectDevice(headphones), true);
                adapter.enabled = false;
                adapter.state = BluetoothAdapterState.Disabled;
                tryCompare(bluetooth, "pending", false, 200);
                verify(bluetooth.error.indexOf("turned off") >= 0);
            }
            function test_provider_diagnostics_are_discarded_and_rejections_do_not_succeed() {
                networkProvider.reject = true;
                compare(network.connectNetwork(openNetwork), false);
                compare(network.pending, false);
                compare(network.error, "Network action failed. Check system authorization.");
                bluetoothProvider.reject = true;
                compare(bluetooth.pairDevice(keyboard), false);
                compare(bluetooth.pending, false);
                compare(bluetooth.error, "Bluetooth action failed. Check system authorization and the pairing agent.");
                networkProvider.failed("Opaque provider diagnostic must not be retained");
                bluetoothProvider.failed("Opaque provider diagnostic must not be retained");
                verify(network.error.indexOf("Opaque") < 0);
                verify(bluetooth.error.indexOf("Opaque") < 0);
            }
            function buttonByName(root, name) {
                for (const child of root.children) {
                    if (child.Accessible.name === name)
                        return child;
                    const match = buttonByName(child, name);
                    if (match)
                        return match;
                }
                return null;
            }
            function reveal(control) {
                scroll.reveal(control);
                wait(30);
                const point = control.mapToItem(scroll.contentItem, 0, 0);
                verify(control.visible && control.enabled);
                verify(point.y >= 0 && point.y + control.height <= scroll.contentItem.height + 1);
            }
            function test_ui_selection_and_cancellation_use_real_pointer_events() {
                network.actionTimeoutMs = 1000;
                bluetooth.actionTimeoutMs = 1000;
                const open = buttonByName(networkControls, "Connect to network Fixture cafe");
                const secured = buttonByName(networkControls, "Connect to network Fixture secured");
                const pair = buttonByName(bluetoothControls, "Pair Bluetooth device Fixture keyboard");
                verify(open && secured && pair);
                compare(secured.enabled, false);
                reveal(open);
                mouseClick(open);
                compare(networkProvider.lastAction, "connect");
                tryCompare(open, "enabled", false);
                const cancelNetwork = findChild(networkControls, "networkCancel");
                tryCompare(cancelNetwork, "visible", true);
                reveal(cancelNetwork);
                capture("selection-network-pending");
                mouseClick(cancelNetwork);
                compare(networkProvider.cancellations, 1);
                reveal(pair);
                mouseClick(pair);
                compare(bluetoothProvider.lastAction, "pair");
                const cancelBluetooth = findChild(bluetoothControls, "bluetoothCancel");
                tryCompare(cancelBluetooth, "visible", true);
                reveal(cancelBluetooth);
                capture("selection-bluetooth-pending");
                mouseClick(cancelBluetooth);
                compare(bluetoothProvider.cancellations, 1);
            }
            function test_ui_pointer_keyboard_pending_accessibility_and_short_scroll() {
                for (const theme of ["catppuccin-mocha", "gruvbox"]) {
                    verify(Theme.selectTheme(theme));
                    tryCompare(Theme, "saveStatus", "saved");
                    resize(252, 760);
                    networkProvider.wifiEnabled = true;
                    wifi.scannerEnabled = false;
                    adapter.enabled = true;
                    adapter.state = BluetoothAdapterState.Enabled;
                    start.forceActiveFocus();
                    const wifiButton = findChild(networkControls, "networkWifi");
                    const scan = findChild(networkControls, "networkScan");
                    const power = findChild(bluetoothControls, "bluetoothPower");
                    checkpoint = "control names";
                    verify(wifiButton && scan && power);
                    compare(wifiButton.Accessible.name, "Turn Wi-Fi off");
                    checkpoint = "first Tab";
                    keyClick(Qt.Key_Tab);
                    tryCompare(wifiButton, "activeFocus", true);
                    verify(wifiButton.visualFocus);
                    capture(theme + "-keyboard-focus");
                    checkpoint = "second Tab";
                    keyClick(Qt.Key_Tab);
                    tryCompare(scan, "activeFocus", true);
                    checkpoint = "pointer scan";
                    mouseClick(scan);
                    compare(networkProvider.lastAction, "scan");
                    compare(scan.enabled, false);
                    compare(wifiButton.enabled, false);
                    wifi.scannerEnabled = true;
                    tryCompare(network, "pending", false);
                    resize(252, 200);
                    start.forceActiveFocus();
                    checkpoint = "short Tab traversal";
                    let reached = false;
                    for (let i = 0; i < 30; i++) {
                        keyClick(Qt.Key_Tab);
                        wait(20);
                        const control = window.contentItem.Window.window.activeFocusItem;
                        if (control === power) {
                            reached = true;
                            break;
                        }
                    }
                    verify(reached, "Bluetooth must be reachable by normal Tab traversal");
                    checkpoint = "power reveal";
                    tryVerify(() => {
                        const p = power.mapToItem(scroll.contentItem, 0, 0);
                        return p.y >= 0 && p.y + power.height <= scroll.contentItem.height + 1;
                    });
                    capture(theme + "-short-keyboard-focus");
                    checkpoint = "pointer power";
                    mouseClick(power);
                    compare(bluetoothProvider.lastAction, "power");
                    compare(power.enabled, false);
                    adapter.enabled = false;
                    adapter.state = BluetoothAdapterState.Disabled;
                    tryCompare(bluetooth, "pending", false);
                    capture(theme + "-short-pointer-focus");
                }
            }
            function test_ui_palette_geometry_empty_unavailable_and_failure_images() {
                for (const theme of ["catppuccin-mocha", "gruvbox"]) {
                    verify(Theme.selectTheme(theme));
                    tryCompare(Theme, "saveStatus", "saved");
                    for (const width of [252, 340]) {
                        resize(width, 760);
                        tryVerify(() => networkControls.width <= width);
                        tryVerify(() => bluetoothControls.width <= width);
                        for (const controls of [networkControls, bluetoothControls]) {
                            for (const name of controls === networkControls ? ["networkWifi", "networkScan"] : ["bluetoothPower", "bluetoothScan"]) {
                                const button = findChild(controls, name);
                                verify(button.Accessible.name.length > 0);
                                const p = button.mapToItem(window.contentItem, 0, 0);
                                verify(p.x >= 0 && p.x + button.width <= width + 1, name + " fits");
                            }
                        }
                        capture(theme + "-" + width);
                    }
                    resize(252, 760);
                    networkProvider.devices = [];
                    bluetoothProvider.adapters = [];
                    bluetoothProvider.defaultAdapter = null;
                    tryCompare(findChild(networkControls, "networkWifi"), "enabled", false);
                    tryCompare(findChild(bluetoothControls, "bluetoothPower"), "enabled", false);
                    capture(theme + "-unavailable");
                    networkProvider.devices = [wifi];
                    wifi.networks = {
                        values: []
                    };
                    bluetoothProvider.adapters = [adapter];
                    bluetoothProvider.defaultAdapter = adapter;
                    adapter.devices = {
                        values: []
                    };
                    capture(theme + "-empty");
                    wifi.networks = {
                        values: [openNetwork, securedNetwork]
                    };
                    adapter.devices = {
                        values: [headphones, keyboard]
                    };
                    compare(network.connectNetwork(openNetwork), true);
                    networkProvider.failed("permission");
                    compare(bluetooth.pairDevice(keyboard), true);
                    bluetoothProvider.failed("authentication");
                    capture(theme + "-errors");
                    network.clearError();
                    bluetooth.clearError();
                }
            }
        }
    }
}
