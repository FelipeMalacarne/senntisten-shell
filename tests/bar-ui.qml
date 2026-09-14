import QtQuick
import QtTest
import Quickshell
// Quickshell's static module scanner must see the directory loaded below.
import "desktop"
import "services"

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1100
        implicitHeight: 440
        color: Theme.colors.background

        Loader {
            id: barLoader
            width: parent.width
            height: 38
            source: "desktop/BarContent.qml"
        }
        Loader {
            id: audioLoader
            x: 10
            y: 50
            width: 340
            active: false
        }
        QtObject {
            id: sink
            property bool ready: true
            property string description: "Test output"
            property string nickname: ""
            property string name: "test-output"
            property var audio: QtObject {
                property real volume: 0.42
                property bool muted: false
            }
        }
        QtObject {
            id: pipewire
            property bool ready: true
            property var defaultAudioSink: sink
        }
        QtObject {
            id: tray
            property var items: QtObject {
                property var values: []
            }
            property int activations: 0
            property int secondaryActivations: 0
            property int menus: 0
            property var menuWindow: null
            property var menuPoint: null
            property int scrollDelta: 0
            property bool horizontalScroll: false
        }
        QtObject {
            id: compositor
            property var monitors: QtObject {
                property var values: [
                    {
                        name: "DP-1"
                    },
                    {
                        name: "HDMI-A-1"
                    }
                ]
            }
            property var workspaces: QtObject {
                property var values: []
            }
            property var activeToplevel: null
            property int activatedWorkspace: -1
        }
        TestCase {
            name: "SenntistenBar"
            when: Theme.ready && window.visible
            property var executed: []
            SignalSpy {
                id: launcherSpy
                target: barLoader.item
                signalName: "launcherRequested"
            }
            SignalSpy {
                id: appearanceSpy
                target: barLoader.item
                signalName: "appearanceRequested"
            }
            SignalSpy {
                id: audioSpy
                target: barLoader.item
                signalName: "audioRequested"
            }
            SignalSpy {
                id: closeAudioSpy
                target: audioLoader.item
                signalName: "closeRequested"
            }
            function init() {
                executed = executed.concat([qtest_results.functionName]);
                tryCompare(barLoader, "status", Loader.Ready);
                barLoader.width = 1100;
                compositor.monitors.values = [
                    {
                        name: "DP-1"
                    },
                    {
                        name: "HDMI-A-1"
                    }
                ];
                compositor.workspaces.values = [];
                compositor.activeToplevel = null;
                barLoader.item.services.compositor = compositor;
                barLoader.item.services.pipewire = pipewire;
                barLoader.item.services.tray = tray;
                barLoader.item.screenName = "DP-1";
                barLoader.item.popAbove = false;
                tray.items.values = [];
                tray.activations = 0;
                tray.secondaryActivations = 0;
                tray.menus = 0;
                audioLoader.active = false;
                launcherSpy.clear();
                appearanceSpy.clear();
                audioSpy.clear();
                closeAudioSpy.clear();
                sink.ready = true;
                sink.audio.volume = 0.42;
                sink.audio.muted = false;
                pipewire.ready = true;
                pipewire.defaultAudioSink = sink;
            }
            function cleanup() {
                if (qtest_results.failed)
                    console.log("BAR_FAILED_CASE " + qtest_results.functionName);
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_BAR_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }
            function workspace(id, monitor, active) {
                return {
                    id: id,
                    name: String(id),
                    monitor: {
                        name: monitor
                    },
                    active: active,
                    urgent: false,
                    activate: function () {
                        compositor.activatedWorkspace = id;
                    }
                };
            }
            function test_workspaces_are_live_screen_scoped_and_activate_native_objects() {
                const bar = barLoader.item;
                verify(bar.services !== undefined, "Bar must expose native service adapter");
                bar.services.compositor = compositor;
                bar.screenName = "DP-1";
                compositor.workspaces.values = [workspace(3, "DP-1", false), workspace(2, "HDMI-A-1", true), workspace(1, "DP-1", true)];
                tryCompare(bar, "workspaceCount", 2);
                const first = findChild(bar, "workspace-1");
                const third = findChild(bar, "workspace-3");
                verify(first !== null && third !== null);
                verify(findChild(bar, "workspace-2") === null);
                verify(first.selected && !third.selected);
                tryVerify(() => first.x < third.x, 1000, "Workspaces are ordered by numeric id");
                third.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(compositor.activatedWorkspace, 3);
                compositor.workspaces.values = [workspace(3, "DP-1", true)];
                tryCompare(bar, "workspaceCount", 1);
                tryVerify(() => findChild(bar, "workspace-1") === null);
                verify(findChild(bar, "workspace-3").selected);
                compositor.monitors.values = [];
                tryVerify(() => findChild(bar, "barWorkspaceStatus").visible);
                compare(findChild(bar, "barWorkspaceStatus").text, "Hyprland unavailable");
            }
            function test_clock_displays_system_time_and_updates_from_native_clock() {
                const bar = barLoader.item;
                const label = findChild(bar, "barClock");
                const clock = findChild(bar, "barClockSource");
                verify(label !== null && clock !== null);
                verify(clock.enabled);
                compare(label.text, Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm"));
                compare(Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm"), Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"));
                clock.precision = SystemClock.Seconds;
                const before = clock.date.getTime();
                tryVerify(() => clock.date.getTime() > before, 2000);
                clock.precision = SystemClock.Minutes;
            }
            function test_focused_title_tracks_the_screen_and_yields_space_on_narrow_bars() {
                const bar = barLoader.item;
                const title = findChild(bar, "barWindowTitle");
                verify(title !== null);
                bar.services.compositor = compositor;
                bar.screenName = "DP-1";
                compositor.activeToplevel = {
                    title: "Editor <main>",
                    monitor: {
                        name: "DP-1"
                    }
                };
                tryCompare(title, "text", "Editor <main>");
                verify(title.visible);
                compare(title.textFormat, Text.PlainText);
                compositor.activeToplevel = {
                    title: "Terminal",
                    monitor: {
                        name: "HDMI-A-1"
                    }
                };
                tryCompare(title, "text", "");
                compositor.activeToplevel = {
                    title: "Terminal",
                    monitor: {
                        name: "DP-1"
                    }
                };
                tryCompare(title, "text", "Terminal");
                barLoader.width = 480;
                tryCompare(title, "visible", false);
                barLoader.width = 1100;
                compositor.activeToplevel = null;
                tryCompare(title, "text", "");
            }
            function test_audio_panel_controls_native_volume_and_keeps_external_updates() {
                const bar = barLoader.item;
                verify(bar.services.pipewire !== undefined, "Native PipeWire provider required");
                bar.services.pipewire = pipewire;
                const trigger = findChild(bar, "barAudio");
                verify(trigger !== null);
                compare(trigger.text, "Vol 42%");
                mouseClick(trigger);
                compare(audioSpy.count, 1);
                audioLoader.setSource("desktop/AudioPanel.qml", {
                    services: bar.services
                });
                audioLoader.active = true;
                tryCompare(audioLoader, "status", Loader.Ready);
                const panel = audioLoader.item;
                const slider = findChild(panel, "audioVolume");
                const mute = findChild(panel, "audioMute");
                verify(slider !== null && mute !== null);
                compare(findChild(panel, "audioOutputName").text, "Test output");
                compare(slider.value, 0.42);
                slider.forceActiveFocus();
                keyClick(Qt.Key_Right);
                tryCompare(sink.audio, "volume", 0.43);
                sink.audio.volume = 0.8;
                tryCompare(slider, "value", 0.8);
                compare(trigger.text, "Vol 80%");
                mouseClick(mute);
                compare(sink.audio.muted, true);
                compare(mute.text, "Unmute");
                compare(trigger.text, "Muted");
                mute.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(sink.audio.muted, false);
                mouseClick(findChild(panel, "audioDecrease"));
                tryVerify(() => Math.abs(sink.audio.volume - 0.75) < 0.0001);
                mouseClick(findChild(panel, "audioIncrease"));
                tryVerify(() => Math.abs(sink.audio.volume - 0.8) < 0.0001);
                mouseClick(findChild(panel, "audioClose"));
                compare(closeAudioSpy.count, 1);
            }
            function test_audio_unavailability_is_visible_and_never_mutates_stale_nodes() {
                const services = barLoader.item.services;
                services.pipewire = pipewire;
                audioLoader.setSource("desktop/AudioPanel.qml", {
                    services: services
                });
                audioLoader.active = true;
                tryCompare(audioLoader, "status", Loader.Ready);
                const panel = audioLoader.item;
                const status = findChild(panel, "audioStatus");
                verify(status !== null);
                pipewire.ready = false;
                tryCompare(status, "text", "PipeWire unavailable");
                verify(status.visible);
                compare(findChild(panel, "audioVolume").enabled, false);
                compare(findChild(panel, "audioMute").enabled, false);
                compare(findChild(panel, "audioPercentage").text, "—");
                compare(services.setVolume(0.1), false);
                compare(services.toggleMute(), false);
                compare(sink.audio.volume, 0.42);
                compare(sink.audio.muted, false);
                pipewire.ready = true;
                pipewire.defaultAudioSink = null;
                tryCompare(status, "text", "No audio output");
                compare(services.toggleMute(), false);
                pipewire.defaultAudioSink = sink;
                sink.ready = false;
                tryCompare(status, "text", "Connecting to audio output");
                sink.ready = true;
                tryCompare(status, "visible", false);
                compare(findChild(panel, "audioVolume").enabled, true);
                closeAudioSpy.clear();
                findChild(panel, "audioVolume").forceActiveFocus();
                keyClick(Qt.Key_Escape);
                compare(closeAudioSpy.count, 1);
            }
            function test_audio_volume_is_bounded_and_invalid_values_are_rejected() {
                const services = barLoader.item.services;
                services.pipewire = pipewire;
                verify(services.setVolume(1.5));
                compare(sink.audio.volume, 1);
                verify(services.setVolume(-0.5));
                compare(sink.audio.volume, 0);
                for (const bad of [NaN, Infinity, -Infinity, "0.5", null, undefined]) {
                    compare(services.setVolume(bad), false);
                    compare(sink.audio.volume, 0);
                }
                sink.audio.muted = true;
                verify(services.setVolume(0.5));
                compare(sink.audio.muted, true, "Changing volume must not unmute unexpectedly");
            }
            function trayItem(onlyMenu) {
                return {
                    id: "test-tray",
                    title: "Tray app",
                    icon: "",
                    status: 1,
                    tooltipTitle: "Tray app",
                    tooltipDescription: "",
                    hasMenu: true,
                    onlyMenu: onlyMenu,
                    activate: function () {
                        tray.activations++;
                    },
                    secondaryActivate: function () {
                        tray.secondaryActivations++;
                    },
                    display: function (window, x, y) {
                        tray.menus++;
                        tray.menuWindow = window;
                        tray.menuPoint = Qt.point(x, y);
                    },
                    scroll: function (delta, horizontal) {
                        tray.scrollDelta = delta;
                        tray.horizontalScroll = horizontal;
                    }
                };
            }
            function test_tray_items_dispatch_real_item_actions_and_context_menus() {
                const bar = barLoader.item;
                verify(bar.services.tray !== undefined, "Native SystemTray provider required");
                bar.services.tray = tray;
                bar.hostWindow = window;
                tray.items.values = [trayItem(false)];
                tryCompare(bar, "trayCount", 1);
                const button = findChild(bar, "tray-test-tray");
                verify(button !== null);
                tryVerify(() => button.width > 0 && button.height > 0);
                compare(button.Accessible.name, "Tray app");
                tryVerify(() => {
                    const viewport = findChild(bar, "barTrayViewport");
                    const p = button.mapToItem(viewport, 0, 0);
                    return p.x >= 0 && p.x + button.width <= viewport.width;
                });
                mouseClick(button);
                compare(tray.activations, 1);
                mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton);
                compare(tray.menus, 1);
                compare(tray.menuWindow, window);
                verify(tray.menuPoint.x >= 0 && tray.menuPoint.y >= 0);
                mouseClick(button, button.width / 2, button.height / 2, Qt.MiddleButton);
                compare(tray.secondaryActivations, 1);
                mouseWheel(button, button.width / 2, button.height / 2, 0, 120);
                compare(tray.scrollDelta, 120);
                compare(tray.horizontalScroll, false);
                button.forceActiveFocus();
                keyClick(Qt.Key_Menu);
                compare(tray.menus, 2);
                tray.items.values = [trayItem(true)];
                tryVerify(() => findChild(bar, "tray-test-tray") !== button);
                const menuOnly = findChild(bar, "tray-test-tray");
                menuOnly.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(tray.activations, 1);
                compare(tray.menus, 3);
                tray.items.values = [];
                tryCompare(bar, "trayCount", 0);
                verify(findChild(bar, "barTrayStatus").visible);
                compare(findChild(bar, "barTrayStatus").text, "Tray —");
            }
            function test_panel_wrapper_compiles_without_constructing_wayland_surfaces() {
                const component = Qt.createComponent("desktop/Bar.qml");
                if (component.status === Component.Error)
                    console.log("BAR_COMPONENT_ERROR " + component.errorString());
                tryCompare(component, "status", Component.Ready);
                compare(component.errorString(), "");
            }
            function test_narrow_bars_reveal_keyboard_focused_workspaces_and_tray_items() {
                const bar = barLoader.item;
                bar.services.tray = tray;
                compositor.workspaces.values = Array.from({
                    length: 12
                }, (_, i) => workspace(i + 1, "DP-1", i === 0));
                tray.items.values = Array.from({
                    length: 6
                }, (_, i) => Object.assign(trayItem(false), {
                        id: "item" + i
                    }));
                barLoader.width = 480;
                tryCompare(bar, "workspaceCount", 12);
                tryCompare(bar, "trayCount", 6);
                for (const name of ["barLauncher", "barAudio", "barAppearance", "barClock"]) {
                    const item = findChild(bar, name);
                    tryVerify(() => {
                        const p = item.mapToItem(bar, 0, 0);
                        return p.x >= 0 && p.x + item.width <= bar.width && p.y >= 0 && p.y + item.height <= bar.height;
                    }, 1000, name + " must fit the bar");
                }
                const workspaceView = findChild(bar, "barWorkspaceViewport");
                const lastWorkspace = findChild(bar, "workspace-12");
                lastWorkspace.forceActiveFocus();
                tryVerify(() => {
                    const p = lastWorkspace.mapToItem(workspaceView, 0, 0);
                    return p.x >= -0.1 && p.x + lastWorkspace.width <= workspaceView.width + 0.1;
                }, 1000, "Keyboard focus must scroll to the workspace");
                const trayView = findChild(bar, "barTrayViewport");
                const lastTray = findChild(bar, "tray-item5");
                lastTray.forceActiveFocus();
                tryVerify(() => {
                    const p = lastTray.mapToItem(trayView, 0, 0);
                    return p.x >= -0.1 && p.x + lastTray.width <= trayView.width + 0.1;
                }, 1000, "Keyboard focus must scroll to the tray item");
            }
            function test_preview_indicator_is_explicit_and_uses_shared_theme_tokens() {
                const bar = barLoader.item;
                const preview = findChild(bar, "barPreview");
                verify(preview !== null);
                verify(!preview.visible);
                bar.popAbove = true;
                tryCompare(preview, "visible", true);
                compare(preview.text, "Preview");
                for (const theme of ["gruvbox", "catppuccin-mocha"]) {
                    verify(Theme.selectTheme(theme));
                    tryCompare(Theme, "saveStatus", "saved");
                    tryCompare(bar, "color", Theme.colors.background);
                    tryCompare(preview, "color", Theme.colors.warning);
                    const launcher = findChild(bar, "barLauncher");
                    tryCompare(launcher.background, "color", Theme.colors.accent);
                    compare(launcher.contentItem.font.family, "Noto Sans");
                }
                barLoader.width = 480;
                const appearance = findChild(bar, "barAppearance");
                tryVerify(() => appearance.x + appearance.width <= bar.width, 1000);
            }
            function test_selected_workspace_is_revealed_after_live_model_updates() {
                const bar = barLoader.item;
                barLoader.width = 480;
                compositor.workspaces.values = Array.from({
                    length: 12
                }, (_, i) => workspace(i + 1, "DP-1", i === 0));
                tryCompare(bar, "workspaceCount", 12);
                const viewport = findChild(bar, "barWorkspaceViewport");
                tryVerify(() => viewport.contentWidth > viewport.width && viewport.width <= bar.width * 0.35);
                viewport.contentX = 0;
                compositor.workspaces.values = Array.from({
                    length: 12
                }, (_, i) => workspace(i + 1, "DP-1", i === 11));
                tryVerify(() => {
                    const selected = findChild(bar, "workspace-12");
                    const p = selected.mapToItem(viewport, 0, 0);
                    return selected.x > viewport.width && selected.selected && p.x >= -0.1 && p.x + selected.width <= viewport.width + 0.1;
                }, 1000, "The live active workspace should not be clipped offscreen");
            }
            function test_nonfocused_monitors_keep_the_right_controls_right_aligned() {
                const bar = barLoader.item;
                compositor.activeToplevel = {
                    title: "Other screen's editor",
                    monitor: {
                        name: "HDMI-A-1"
                    }
                };
                const appearance = findChild(bar, "barAppearance");
                tryVerify(() => {
                    const p = appearance.mapToItem(bar, 0, 0);
                    return Math.abs(p.x + appearance.width - (bar.width - 8)) < 1;
                }, 1000, "A hidden foreign-monitor title must leave an expanding spacer");
            }
            function test_primary_actions_are_compact_and_keyboard_accessible() {
                const bar = barLoader.item;
                verify(bar.implicitHeight >= 30 && bar.implicitHeight <= 44);
                const launcher = findChild(bar, "barLauncher");
                const appearance = findChild(bar, "barAppearance");
                verify(launcher !== null && appearance !== null);
                mouseClick(launcher);
                compare(launcherSpy.count, 1);
                appearance.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(appearanceSpy.count, 1);
                verify(launcher.Accessible.name.length > 0);
                verify(appearance.Accessible.name.length > 0);
            }
        }
    }
}
