import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// Replace only these native providers in offscreen tests; never script-poll IPC.
Item {
    id: root
    readonly property var network: NetworkService {}
    readonly property var bluetooth: BluetoothService {}
    readonly property var media: MediaService {}
    property var compositor: Hyprland
    readonly property var monitors: compositor.monitors.values
    readonly property var workspaces: compositor.workspaces.values
    readonly property var activeToplevel: compositor.activeToplevel
    readonly property bool compositorAvailable: monitors.length > 0

    property var tray: SystemTray
    readonly property var trayItems: tray.items.values

    property var pipewire: Pipewire
    readonly property var sink: pipewire.defaultAudioSink || null
    readonly property var source: pipewire.defaultAudioSource || null
    // Track candidates before testing ready: native nodes only become ready while tracked.
    readonly property var audioNodes: pipewire.nodes ? pipewire.nodes.values.filter(node => node && !node.isStream && !!node.audio) : []
    readonly property var outputs: pipewire.ready ? audioNodes.filter(node => node.isSink && node.ready) : []
    readonly property bool audioAvailable: usableNode(sink, true)
    readonly property real volume: audioAvailable ? sink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: audioAvailable && sink.audio.muted
    readonly property string outputName: sink ? (sink.description || sink.nickname || sink.name) : ""
    readonly property string audioStatus: !pipewire.ready ? "PipeWire unavailable" : !sink || !audioNodes.includes(sink) ? "No audio output" : !audioAvailable ? "Connecting to audio output" : ""
    readonly property bool microphoneAvailable: usableNode(source, false)
    readonly property real microphoneVolume: microphoneAvailable ? source.audio.volume : 0
    readonly property int microphoneVolumePercent: Math.round(microphoneVolume * 100)
    readonly property bool microphoneMuted: microphoneAvailable && source.audio.muted
    readonly property string microphoneName: source ? (source.description || source.nickname || source.name) : ""
    readonly property string microphoneStatus: !pipewire.ready ? "PipeWire unavailable" : !source || !audioNodes.includes(source) ? "No microphone" : !microphoneAvailable ? "Connecting to microphone" : ""

    // PwNode.audio is not live until the native node is tracked.
    PwObjectTracker {
        objects: root.pipewire === Pipewire ? root.audioNodes : []
    }

    function usableNode(node, isSink) {
        if (!pipewire.ready || !node || !pipewire.nodes || !pipewire.nodes.values.includes(node) || node.isStream || node.isSink !== isSink)
            return false;
        return node.ready && !!node.audio;
    }
    function selectOutput(node) {
        if (!usableNode(node, true))
            return false;
        pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    function setVolume(value) {
        const node = pipewire.defaultAudioSink;
        if (!usableNode(node, true) || typeof value !== "number" || !Number.isFinite(value))
            return false;
        // No accidental amplification above 100%; mute remains an explicit action.
        node.audio.volume = Math.max(0, Math.min(1, value));
        return true;
    }
    function toggleMute() {
        const node = pipewire.defaultAudioSink;
        if (!usableNode(node, true))
            return false;
        node.audio.muted = !node.audio.muted;
        return true;
    }
    function setMicrophoneVolume(value) {
        const node = pipewire.defaultAudioSource;
        if (!usableNode(node, false) || typeof value !== "number" || !Number.isFinite(value))
            return false;
        node.audio.volume = Math.max(0, Math.min(1, value));
        return true;
    }
    function toggleMicrophoneMute() {
        const node = pipewire.defaultAudioSource;
        if (!usableNode(node, false))
            return false;
        node.audio.muted = !node.audio.muted;
        return true;
    }
}
