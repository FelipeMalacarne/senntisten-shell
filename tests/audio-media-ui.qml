import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import "desktop"
import "components"
import "services"

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 300
        implicitHeight: 740
        color: Theme.colors.surface
        AudioNode {
            id: outputA
            name: "a"
            description: "Fixture speakers"
        }
        AudioNode {
            id: outputB
            name: "b"
            description: "Very long fixture headphones device name"
        }
        AudioNode {
            id: mic
            isSink: false
            description: "Fixture microphone"
        }
        AudioNode {
            id: otherMic
            isSink: false
            description: "Other fixture microphone"
        }
        AudioNode {
            id: stream
            isStream: true
        }
        AudioNode {
            id: video
            audio: null
        }
        QtObject {
            id: pipewire
            property bool ready: true
            property var nodes: QtObject {
                property var values: []
            }
            property var defaultAudioSink: outputA
            property var defaultAudioSource: mic
            property var preferredDefaultAudioSink: null
            property int defaultWrites: 0
            onPreferredDefaultAudioSinkChanged: defaultWrites++
        }
        QtObject {
            id: compositor
            property var monitors: QtObject {
                property var values: []
            }
            property var workspaces: QtObject {
                property var values: []
            }
            property var activeToplevel: null
        }
        QtObject {
            id: tray
            property var items: QtObject {
                property var values: []
            }
        }
        Player {
            id: playerA
        }
        Player {
            id: playerB
            dbusName: "org.mpris.MediaPlayer2.b"
            identity: "Second fixture player"
        }
        QtObject {
            id: mpris
            property var players: QtObject {
                property var values: []
            }
        }

        Loader {
            id: audioService
        }
        Loader {
            id: mediaService
        }
        Loader {
            id: nativeAudio
        }
        Loader {
            id: nativeMedia
        }
        Item {
            id: panel
            x: 24
            y: 24
            width: window.contentItem.width - 48
            height: window.contentItem.height - 48
            ShellScrollView {
                id: scroll
                anchors.fill: parent
                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: 12
                    ShellLabel {
                        text: "Audio/media test fixtures"
                        Layout.fillWidth: true
                    }
                    Loader {
                        id: devices
                        Layout.fillWidth: true
                    }
                    Loader {
                        id: microphone
                        Layout.fillWidth: true
                    }
                    Loader {
                        id: media
                        Layout.fillWidth: true
                    }
                }
            }
        }
        TestCase {
            name: "AudioMedia"
            when: window.visible && Theme.ready
            property var executed: []
            property string phase: ""
            function init() {
                phase = "setup";
                executed = executed.concat([qtest_results.functionName]);
                devices.source = "";
                microphone.source = "";
                media.source = "";
                mediaService.source = "";
                nativeAudio.source = "";
                nativeMedia.source = "";
                resize(300, 740);
                pipewire.ready = true;
                for (const node of [outputA, outputB, mic, otherMic]) {
                    node.ready = true;
                    node.audio.volume = 0.42;
                    node.audio.muted = false;
                    node.writes = 0;
                }
                pipewire.nodes.values = [outputB, stream, mic, video, outputA, otherMic];
                pipewire.defaultAudioSink = outputA;
                pipewire.defaultAudioSource = mic;
                pipewire.preferredDefaultAudioSink = null;
                pipewire.defaultWrites = 0;
                audioService.setSource("desktop/BarServices.qml", {
                    pipewire: pipewire,
                    compositor: compositor,
                    tray: tray
                });
                tryCompare(audioService, "status", Loader.Ready);
                for (const player of [playerA, playerB]) {
                    player.isPlaying = false;
                    player.canControl = true;
                    player.canPlay = true;
                    player.canPause = true;
                    player.canTogglePlaying = true;
                    player.canGoNext = true;
                    player.canGoPrevious = true;
                    player.trackArtUrl = "";
                    player.trackTitle = "Fixture track, not live playback";
                    player.actions = [];
                    player.failAction = false;
                }
                mpris.players.values = [playerB, playerA];
                scroll.contentItem.contentY = 0;
            }
            function cleanup() {
                if (qtest_results.failed)
                    checkpoint("FAILED " + qtest_results.functionName + " / " + phase);
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_AUDIO_MEDIA_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }
            function loadMedia() {
                mediaService.setSource("desktop/MediaService.qml", {
                    mpris: mpris
                });
                tryCompare(mediaService, "status", Loader.Ready);
                return mediaService.item;
            }
            function loadUi() {
                const service = loadMedia();
                devices.setSource("desktop/AudioDevices.qml", {
                    services: audioService.item
                });
                microphone.setSource("desktop/MicrophoneControls.qml", {
                    services: audioService.item
                });
                media.setSource("desktop/MediaControls.qml", {
                    service: service
                });
                for (const loader of [devices, microphone, media])
                    tryCompare(loader, "status", Loader.Ready);
                waitForRendering(panel);
            }
            function checkpoint(label, controls) {
                console.log("AUDIO_MEDIA_CHECKPOINT " + JSON.stringify({
                    label: label,
                    outputWrites: [outputA.writes, outputB.writes],
                    microphoneWrites: [mic.writes, otherMic.writes],
                    defaultWrites: pipewire.defaultWrites,
                    effectiveOutput: audioService.item.outputName,
                    effectiveMicrophone: audioService.item.microphoneName,
                    playerActions: [playerA.actions, playerB.actions],
                    controls: (controls || []).map(item => {
                        const point = item.mapToItem(panel, 0, 0);
                        return {
                            name: item.objectName,
                            accessibleName: item.Accessible.name,
                            enabled: item.enabled,
                            visible: item.visible,
                            focus: item.activeFocus,
                            geometry: [point.x, point.y, item.width, item.height],
                            inViewport: point.x >= -0.1 && point.y >= -0.1 && point.x + item.width <= panel.width + 0.1 && point.y + item.height <= panel.height + 0.1
                        };
                    })
                }));
            }
            function capture(name) {
                waitForRendering(panel);
                const output = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
                if (output)
                    grabImage(window.contentItem).save(output + "/" + name + ".png");
            }
            function resize(width, height) {
                window.contentItem.Window.window.width = width;
                window.contentItem.Window.window.height = height;
                tryCompare(window.contentItem, "width", width);
                tryCompare(window.contentItem, "height", height);
            }
            function test_audio_devices_use_preferred_default_and_follow_external_changes() {
                const service = audioService.item;
                verify(service.outputs !== undefined, "Expose native available output references");
                compare(service.outputs.length, 2);
                verify(service.outputs.includes(outputA) && service.outputs.includes(outputB));
                verify(service.selectOutput(outputB));
                compare(pipewire.preferredDefaultAudioSink, outputB);
                compare(pipewire.defaultWrites, 1);
                compare(service.sink, outputA, "Selection must not fabricate the effective default");
                pipewire.defaultAudioSink = outputB;
                tryCompare(service, "outputName", outputB.description);
                outputB.audio.volume = 0.77;
                outputB.audio.muted = true;
                tryCompare(service, "volumePercent", 77);
                tryCompare(service, "muted", true);
                outputB.ready = false;
                tryVerify(() => !service.outputs.includes(outputB));
                verify(!service.selectOutput(outputB));
                outputB.ready = true;
                const model = pipewire.nodes;
                pipewire.nodes = null;
                const selectedWithoutCatalog = service.selectOutput(outputB);
                pipewire.nodes = model;
                compare(selectedWithoutCatalog, false, "No output catalog must not allow arbitrary default writes");
                checkpoint("external-default-and-output-readiness");
            }
            function test_audio_removed_nodes_reject_writes_at_dispatch_time() {
                const service = audioService.item;
                verify(typeof service.selectOutput === "function");
                pipewire.nodes.values = [mic];
                compare(service.setVolume(0.9), false);
                compare(service.toggleMute(), false);
                compare(service.selectOutput(outputB), false);
                compare(service.selectOutput(stream), false);
                compare(service.selectOutput(mic), false);
                compare(service.selectOutput(null), false);
                compare(outputA.writes, 0);
                compare(outputB.writes, 0);
                compare(pipewire.defaultWrites, 0);
                tryCompare(service, "audioAvailable", false);
                checkpoint("removed-output-no-writes");
            }
            function test_missing_audio_catalog_rejects_all_device_writes() {
                const service = audioService.item;
                const model = pipewire.nodes;
                pipewire.nodes = null;
                const available = [service.audioAvailable, service.microphoneAvailable];
                const accepted = [service.setVolume(0.9), service.toggleMute(), service.setMicrophoneVolume(0.9), service.toggleMicrophoneMute(), service.selectOutput(outputB)];
                pipewire.nodes = model;
                compare(available, [false, false]);
                compare(accepted, [false, false, false, false, false]);
                compare(outputA.writes, 0);
                compare(mic.writes, 0);
                compare(pipewire.defaultWrites, 0);
                checkpoint("missing-catalog-no-writes");
            }
            function test_microphone_is_live_bounded_and_does_not_unmute() {
                const service = audioService.item;
                compare(service.source, mic);
                compare(service.microphoneAvailable, true);
                mic.audio.muted = true;
                verify(service.setMicrophoneVolume(2));
                compare(mic.audio.volume, 1);
                compare(mic.audio.muted, true);
                verify(service.setMicrophoneVolume(-2));
                compare(mic.audio.volume, 0);
                for (const bad of [NaN, Infinity, -Infinity, "0.5", null, undefined])
                    compare(service.setMicrophoneVolume(bad), false);
                verify(service.toggleMicrophoneMute());
                compare(mic.audio.muted, false);
                pipewire.defaultAudioSource = otherMic;
                otherMic.audio.volume = 0.63;
                otherMic.audio.muted = true;
                tryCompare(service, "microphoneName", otherMic.description);
                tryCompare(service, "microphoneVolumePercent", 63);
                tryCompare(service, "microphoneMuted", true);
                otherMic.writes = 0;
                pipewire.nodes.values = [outputA];
                compare(service.setMicrophoneVolume(0.3), false);
                compare(service.toggleMicrophoneMute(), false);
                compare(otherMic.writes, 0);
                checkpoint("removed-microphone-no-writes");
            }
            function test_output_volume_preserves_existing_bounds_and_mute_contract() {
                const service = audioService.item;
                outputA.audio.muted = true;
                verify(service.setVolume(3));
                compare(outputA.audio.volume, 1);
                verify(service.setVolume(-1));
                compare(outputA.audio.volume, 0);
                compare(outputA.audio.muted, true);
                for (const bad of [NaN, Infinity, "0.5", null, undefined])
                    compare(service.setVolume(bad), false);
                verify(service.toggleMute());
                compare(outputA.audio.muted, false);
            }
            function test_media_selection_is_deterministic_sticky_and_survives_removal() {
                const service = loadMedia();
                compare(service.player, playerA);
                playerB.isPlaying = true;
                tryCompare(service, "player", playerB);
                verify(service.selectPlayer(playerA));
                mpris.players.values = [playerA, playerB];
                compare(service.player, playerA);
                mpris.players.values = [playerB];
                tryCompare(service, "player", playerB);
                compare(service.selectPlayer(playerA), false);
                mpris.players.values = [];
                tryCompare(service, "available", false);
                verify(service.status.length > 0);
                compare(service.title, "");
                checkpoint("players-disappeared");
            }
            function test_media_metadata_is_live_and_network_artwork_is_rejected() {
                const service = loadMedia();
                compare(service.title, playerA.trackTitle);
                compare(service.artist, playerA.trackArtist);
                compare(service.album, playerA.trackAlbum);
                playerA.trackTitle = "External provider metadata";
                tryCompare(service, "title", playerA.trackTitle);
                for (const url of ["https://example.invalid/art.png", "http://example.invalid/a", "file://remote-host/art.png", "//remote/art", "data:image/svg+xml,unsafe", "ftp://example.invalid/a", "relative.png"]) {
                    playerA.trackArtUrl = url;
                    tryCompare(service, "artwork", "");
                }
                for (const url of ["file:///tmp/provider-art.png", "image://provider/art", "qrc:/art.png"]) {
                    playerA.trackArtUrl = url;
                    tryCompare(service, "artwork", url);
                }
            }
            function test_media_capability_changes_and_stale_targets_never_dispatch() {
                const service = loadMedia();
                verify(service.togglePlaying());
                verify(service.next());
                verify(service.previous());
                compare(playerA.actions.join(","), "toggle,next,previous");
                playerA.actions = [];
                playerA.canGoNext = false;
                playerA.canGoPrevious = false;
                playerA.canTogglePlaying = false;
                compare(service.next(), false);
                compare(service.previous(), false);
                compare(service.togglePlaying(), false);
                playerA.canTogglePlaying = true;
                playerA.canPlay = false;
                compare(service.togglePlaying(), false);
                playerA.isPlaying = true;
                playerA.canPause = false;
                compare(service.togglePlaying(), false);
                playerA.canControl = false;
                compare(service.togglePlaying(), false);
                mpris.players.values = [playerB];
                compare(service.next(playerA), false);
                compare(service.previous(playerA), false);
                compare(service.togglePlaying(playerA), false);
                compare(playerA.actions.length, 0);
                compare(playerB.actions.length, 0);
                checkpoint("unsupported-and-stale-media-no-dispatch");
            }
            function test_media_synchronous_errors_are_visible_and_retryable() {
                const service = loadMedia();
                playerA.failAction = true;
                compare(service.next(), false);
                verify(service.status.includes("Fixture action failure"));
                playerA.failAction = false;
                verify(service.next());
                compare(service.error, "");
            }
            function test_audio_readiness_and_media_empty_capabilities_are_visible() {
                const service = audioService.item;
                mic.ready = false;
                tryCompare(service, "microphoneAvailable", false);
                compare(service.microphoneStatus, "Connecting to microphone");
                compare(service.setMicrophoneVolume(0.2), false);
                compare(service.toggleMicrophoneMute(), false);
                compare(mic.writes, 0);
                pipewire.defaultAudioSource = null;
                tryCompare(service, "microphoneStatus", "No microphone");
                pipewire.defaultAudioSink = null;
                tryCompare(service, "audioStatus", "No audio output");
                const playback = loadMedia();
                playback.mpris = null;
                compare(playback.available, false);
                compare(playback.status, "Media provider unavailable");
                compare(playback.selectPlayer(playerA), false);
                compare(playback.next(), false);
                playback.mpris = mpris;
                playerA.trackTitle = "";
                tryCompare(playback, "status", "No track metadata from player");
                playerA.trackTitle = "Genuine fixture metadata";
                playerA.canControl = false;
                tryCompare(playback, "status", "Player does not support playback controls");
                compare(playback.togglePlaying(), false);
                compare(playerA.actions.length, 0);
                checkpoint("unready-microphone-and-unavailable-media-no-writes");
            }
            function test_native_missing_endpoints_start_without_writes() {
                nativeAudio.setSource("desktop/BarServices.qml", {
                    compositor: compositor,
                    tray: tray
                });
                nativeMedia.setSource("desktop/MediaService.qml");
                tryCompare(nativeAudio, "status", Loader.Ready);
                tryCompare(nativeMedia, "status", Loader.Ready);
                const audio = nativeAudio.item;
                const media = nativeMedia.item;
                tryCompare(audio, "audioAvailable", false);
                compare(audio.outputs.length, 0);
                compare(audio.microphoneAvailable, false);
                verify(audio.audioStatus.length > 0 && audio.microphoneStatus.length > 0);
                compare(audio.setVolume(0.8), false);
                compare(audio.toggleMute(), false);
                compare(audio.selectOutput(outputA), false);
                compare(audio.setMicrophoneVolume(0.8), false);
                compare(audio.toggleMicrophoneMute(), false);
                tryCompare(media, "available", false);
                verify(media.status.length > 0);
                compare(media.next(), false);
                compare(media.togglePlaying(), false);
                checkpoint("native-unavailable-endpoints");
            }
            function test_ui_artwork_loads_locally_and_never_passes_remote_urls_to_image() {
                loadUi();
                const image = findChild(media.item, "mediaArtwork");
                const status = findChild(media.item, "mediaStatus");
                playerA.trackArtUrl = Quickshell.env("SENNTISTEN_ARTWORK_URL");
                tryCompare(image, "status", Image.Ready);
                verify(image.visible);
                capture("audio-media-local-artwork");
                playerA.trackArtUrl = "https://example.invalid/network-artwork.png";
                tryCompare(image, "status", Image.Null);
                compare(image.source.toString(), "");
                verify(!image.visible);
                playerA.trackArtUrl = Quickshell.env("SENNTISTEN_ARTWORK_URL") + "-missing";
                tryCompare(image, "status", Image.Error);
                tryCompare(status, "text", "Artwork unavailable");
            }
            function test_ui_palette_geometry_keyboard_pointer_and_empty_states() {
                phase = "load components";
                loadUi();
                const slider = findChild(microphone.item, "microphoneVolume");
                const mute = findChild(microphone.item, "microphoneMute");
                const next = findChild(media.item, "mediaNext");
                const previous = findChild(media.item, "mediaPrevious");
                const toggle = findChild(media.item, "mediaToggle");
                let output = findChild(devices.item, "audioOutput-" + audioService.item.outputs.indexOf(outputB));
                verify(slider && mute && next && previous && toggle && output);
                for (const theme of ["catppuccin-mocha", "gruvbox"]) {
                    verify(Theme.selectTheme(theme));
                    verify(Theme.setReducedMotion(true));
                    tryCompare(Theme, "saveStatus", "saved");
                    compare(Theme.animationDuration, 0);
                    for (const width of [380, 300]) {
                        phase = theme + " geometry " + width;
                        resize(width, 740);
                        scroll.contentItem.contentY = 0;
                        waitForRendering(panel);
                        output = findChild(devices.item, "audioOutput-" + audioService.item.outputs.indexOf(outputB));
                        for (const item of [output, slider, mute, next, previous, toggle]) {
                            verify(item.Accessible.name.length > 0);
                            const p = item.mapToItem(panel, 0, 0);
                            verify(p.x >= -0.1 && p.x + item.width <= panel.width + 0.1, item.objectName + " fits panel");
                        }
                        compare(slider.background.color.toString(), Theme.colors.overlay);
                        compare(slider.handle.color.toString(), Theme.colors.accent);
                        phase = theme + " output click " + width;
                        mouseClick(output);
                        compare(pipewire.preferredDefaultAudioSink, outputB);
                        phase = theme + " microphone click " + width;
                        mouseClick(mute);
                        verify(mic.audio.muted);
                        slider.forceActiveFocus();
                        keyClick(Qt.Key_Right);
                        tryVerify(() => Math.abs(mic.audio.volume - 0.43) < 0.0001);
                        compare(slider.from, 0);
                        compare(slider.to, 1);
                        mic.audio.volume = 0.42;
                        tryCompare(slider, "value", 0.42);
                        mic.audio.muted = false;
                        mouseClick(findChild(media.item, "mediaPlayer-1"));
                        compare(mediaService.item.player, playerB);
                        mouseClick(findChild(media.item, "mediaPlayer-0"));
                        compare(mediaService.item.player, playerA);
                        mouseClick(toggle);
                        verify(playerA.actions.includes("toggle"));
                        mouseClick(previous);
                        verify(playerA.actions.includes("previous"));
                        capture("audio-media-" + theme + "-" + (width === 380 ? "wide" : "narrow"));
                    }
                    resize(300, 240);
                    phase = theme + " short Tab";
                    scroll.contentItem.contentY = 0;
                    const first = findChild(devices.item, "audioOutput-0");
                    mouseClick(first);
                    let reachedNext = false;
                    let reachedMute = false;
                    for (let i = 0; i < 20; i++) {
                        keyClick(Qt.Key_Tab);
                        wait(20);
                        const focus = window.contentItem.Window.window.activeFocusItem;
                        if (!focus || !focus.objectName)
                            continue;
                        if (focus === mute)
                            reachedMute = true;
                        if (focus === next)
                            reachedNext = true;
                        const p = focus.mapToItem(panel, 0, 0);
                        phase = theme + " short Tab " + focus.objectName + " at " + p.y;
                        verify(p.y >= -0.1 && p.y + focus.height <= panel.height + 0.1, focus.objectName + " revealed by real Tab");
                        if (focus === mute)
                            checkpoint(theme + "-microphone-tab", [mute]);
                        if (reachedNext)
                            break;
                    }
                    verify(reachedMute && reachedNext, "Real Tab must reach microphone and media controls");
                    keyClick(Qt.Key_Space);
                    verify(playerA.actions.includes("next"));
                    checkpoint(theme + "-short-tab", [mute, next]);
                    capture("audio-media-" + theme + "-short-focus");
                    resize(300, 740);
                    scroll.contentItem.contentY = 0;
                    playerA.canGoNext = false;
                    tryCompare(next, "enabled", false);
                    const actionsBefore = playerA.actions.length;
                    mouseClick(next);
                    compare(playerA.actions.length, actionsBefore, "Disabled native button must not dispatch");
                    pipewire.ready = false;
                    mpris.players.values = [];
                    tryCompare(slider, "enabled", false);
                    verify(findChild(microphone.item, "microphoneStatus").text.length > 0);
                    verify(findChild(media.item, "mediaStatus").text.length > 0);
                    capture("audio-media-" + theme + "-unavailable");
                    pipewire.ready = true;
                    mpris.players.values = [playerA, playerB];
                    playerA.canGoNext = true;
                    playerA.failAction = true;
                    compare(mediaService.item.next(), false);
                    tryVerify(() => findChild(media.item, "mediaStatus").text.includes("Fixture action failure"));
                    capture("audio-media-" + theme + "-error");
                    playerA.failAction = false;
                    verify(mediaService.item.next());
                }
            }
        }
    }

    component AudioNode: QtObject {
        property bool ready: true
        property bool isSink: true
        property bool isStream: false
        property string name: "fixture-node"
        property string description: "Fixture output"
        property string nickname: ""
        property int writes: 0
        property var audio: QtObject {
            property real volume: 0.42
            property bool muted: false
            onVolumeChanged: writes++
            onMutedChanged: writes++
        }
    }

    component Player: QtObject {
        property string dbusName: "org.mpris.MediaPlayer2.a"
        property string identity: "Fixture player"
        property string trackTitle: "Fixture track, not live playback"
        property string trackArtist: "Fixture artist"
        property string trackAlbum: "Fixture album"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property bool canControl: true
        property bool canPlay: true
        property bool canPause: true
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property var actions: []
        property bool failAction: false
        function record(action) {
            if (failAction)
                throw new Error("Fixture action failure");
            actions = actions.concat([action]);
        }
        function togglePlaying() {
            record("toggle");
        }
        function next() {
            record("next");
        }
        function previous() {
            record("previous");
        }
    }
}
