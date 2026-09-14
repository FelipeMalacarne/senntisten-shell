import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// Replace only these native providers in offscreen tests; never script-poll IPC.
Item {
    id: root
    property var compositor: Hyprland
    readonly property var monitors: compositor.monitors.values
    readonly property var workspaces: compositor.workspaces.values
    readonly property var activeToplevel: compositor.activeToplevel
    readonly property bool compositorAvailable: monitors.length > 0

    property var tray: SystemTray
    readonly property var trayItems: tray.items.values

    property var pipewire: Pipewire
    readonly property var sink: pipewire.defaultAudioSink
    readonly property bool audioAvailable: pipewire.ready && !!sink && sink.ready && !!sink.audio
    readonly property real volume: audioAvailable ? sink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: audioAvailable && sink.audio.muted
    readonly property string outputName: sink ? (sink.description || sink.nickname || sink.name) : ""
    readonly property string audioStatus: !pipewire.ready ? "PipeWire unavailable" : !sink ? "No audio output" : !audioAvailable ? "Connecting to audio output" : ""

    // PwNode.audio is not live until the native node is tracked.
    PwObjectTracker {
        objects: root.pipewire === Pipewire && root.sink ? [root.sink] : []
    }

    function setVolume(value) {
        if (!audioAvailable || typeof value !== "number" || !Number.isFinite(value))
            return false;
        // No accidental amplification above 100%; mute remains an explicit action.
        sink.audio.volume = Math.max(0, Math.min(1, value));
        return true;
    }
    function toggleMute() {
        if (!audioAvailable)
            return false;
        sink.audio.muted = !sink.audio.muted;
        return true;
    }
}
