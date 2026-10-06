import QtQuick
import QtTest
import Quickshell
import "desktop"
import "services"

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 380
        implicitHeight: 560
        color: Theme.colors.background

        QtObject {
            id: services
            property bool audioAvailable: true
            property real volume: 0.42
            readonly property int volumePercent: Math.round(volume * 100)
            property bool muted: false
            property string outputName: "Isolated test output"
            readonly property string audioStatus: audioAvailable ? "" : "PipeWire unavailable"
            function setVolume(value) {
                if (!audioAvailable)
                    return false;
                volume = Math.max(0, Math.min(1, value));
                return true;
            }
            function toggleMute() {
                if (!audioAvailable)
                    return false;
                muted = !muted;
                return true;
            }
        }
        AudioPanel {
            id: panel
            x: 20
            y: 20
            width: parent.width - 40
            services: services
        }
        TestCase {
            name: "OrbitQuickControls"
            when: window.visible && Theme.ready
            property var executed: []
            property string checkpoint: ""
            SignalSpy {
                id: settingsSpy
                target: panel
                signalName: "settingsRequested"
            }
            SignalSpy {
                id: closeSpy
                target: panel
                signalName: "closeRequested"
            }
            function init() {
                executed = executed.concat([qtest_results.functionName]);
                window.contentItem.width = 380;
                panel.height = Qt.binding(() => panel.implicitHeight);
                services.audioAvailable = true;
                services.volume = 0.42;
                services.muted = false;
                panel.focusInitial(false);
                settingsSpy.clear();
                closeSpy.clear();
            }
            function cleanup() {
                if (qtest_results.failed) {
                    const settings = findChild(panel, "quickSettings");
                    const point = settings ? settings.mapToItem(panel, 0, 0) : Qt.point(0, 0);
                    console.log("CONTROLS_FAILED_CASE " + JSON.stringify({
                        name: qtest_results.functionName,
                        checkpoint: checkpoint,
                        panel: [panel.width, panel.height],
                        settings: settings ? [point.x, point.y, settings.width, settings.height] : []
                    }));
                }
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_CONTROLS_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }
            function test_settings_entry_is_keyboard_accessible_and_appearance_is_separate() {
                const settings = findChild(panel, "quickSettings");
                verify(settings !== null, "Quick Controls needs a separate Settings entry");
                compare(settings.Accessible.name, "Open Settings");
                settings.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(settingsSpy.count, 1);
                verify(findChild(panel, "theme-gruvbox") === null);
                verify(findChild(panel, "reducedMotionSwitch") === null);
                const network = findChild(panel, "quickNetwork");
                const bluetooth = findChild(panel, "quickBluetooth");
                verify(network !== null && bluetooth !== null);
                verify(!network.enabled && !bluetooth.enabled);
                verify(network.Accessible.name.indexOf("Planned") !== -1);
                keyClick(Qt.Key_Escape);
                compare(closeSpy.count, 1);
            }
            function test_mouse_focus_does_not_look_pressed_and_tab_focus_remains_visible() {
                for (const theme of ["catppuccin-mocha", "gruvbox"]) {
                    verify(Theme.selectTheme(theme));
                    tryCompare(Theme, "saveStatus", "saved");
                    for (const name of ["audioDecrease", "audioIncrease", "quickSettings"]) {
                        checkpoint = "pointer " + theme + " " + name;
                        const button = findChild(panel, name);
                        mouseClick(button);
                        mouseMove(window.contentItem, 5, 5);
                        tryCompare(button, "hovered", false);
                        compare(button.down, false);
                        verify(button.activeFocus && !button.visualFocus);
                        wait(Theme.animationDuration + 30);
                        checkpoint += " idle background";
                        if (button.quiet)
                            tryVerify(() => button.background.color.a === 0);
                        else
                            tryCompare(button.background, "color", Theme.colors.surface);
                    }
                    const mute = findChild(panel, "audioMute");
                    mouseClick(mute);
                    mouseMove(window.contentItem, 5, 5);
                    verify(mute.selected);
                    tryCompare(mute.background, "color", Theme.colors.accent);
                    services.muted = false;
                    panel.focusInitial(false);
                    for (const name of ["audioDecrease", "audioMute", "audioIncrease", "quickSettings"]) {
                        checkpoint = "Tab " + theme + " " + name;
                        keyClick(Qt.Key_Tab);
                        const button = findChild(panel, name);
                        tryCompare(button, "activeFocus", true);
                        verify(button.visualFocus);
                        tryCompare(button.background, "color", Theme.colors.overlay);
                    }
                }
            }
            function test_audio_remains_live_and_unavailable_state_is_honest() {
                const slider = findChild(panel, "audioVolume");
                slider.forceActiveFocus();
                keyClick(Qt.Key_Right);
                tryVerify(() => Math.abs(services.volume - 0.43) < 0.0001);
                services.volume = 0.8;
                tryCompare(slider, "value", 0.8);
                mouseClick(findChild(panel, "audioMute"));
                compare(services.muted, true);
                services.audioAvailable = false;
                tryCompare(slider, "enabled", false);
                verify(findChild(panel, "audioStatus").visible);
                compare(findChild(panel, "audioPercentage").text, "—");
                verify(findChild(panel, "quickSettings").enabled);
            }
            function test_orbit_geometry_and_live_palette_pixels() {
                const surface = panel.background;
                compare(surface.radius, 21);
                compare(panel.padding, 24);
                for (const width of [340, 280]) {
                    checkpoint = "layout " + width;
                    window.contentItem.width = width + 40;
                    tryCompare(panel, "width", width);
                    const settings = findChild(panel, "quickSettings");
                    tryVerify(() => settings.width > 0);
                    tryVerify(() => {
                        const point = settings.mapToItem(panel, 0, 0);
                        return point.x >= 0 && point.x + settings.width <= panel.width && point.y + settings.height <= panel.height;
                    });
                }
                window.contentItem.width = 380;
                for (const theme of ["catppuccin-mocha", "gruvbox"]) {
                    checkpoint = "render " + theme;
                    verify(Theme.selectTheme(theme));
                    tryCompare(Theme, "saveStatus", "saved");
                    wait(180);
                    const image = grabImage(panel);
                    compare(image.pixel(15, 30), Theme.colors.surface);
                    const output = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
                    if (output)
                        image.save(output + "/orbit-controls-" + theme + ".png");
                }
            }
            function test_slider_thumb_and_close_control_match_orbit() {
                const slider = findChild(panel, "audioVolume");
                compare(slider.background.height, 6, "The audio track must not stretch to the control height");
                compare(slider.handle.width, 18);
                compare(slider.handle.height, 18);
                const close = findChild(panel, "audioClose");
                compare(close.width, 32);
                compare(close.background.border.width, 0);
                compare(close.contentItem.name, "close");
                compare(panel.implicitWidth, 300);
                services.audioAvailable = false;
                tryCompare(findChild(panel, "audioOutputName"), "visible", false, 1000, "Unavailable output must not advertise a stale device");
            }
            function test_short_controls_scroll_and_tab_reveals_enabled_actions() {
                panel.height = 280;
                const scroll = findChild(panel, "quickControlsScroll");
                verify(scroll !== null, "Short screens need a real scroll viewport");
                tryVerify(() => scroll.contentItem.contentHeight > scroll.contentItem.height);
                panel.focusInitial(false);
                compare(findChild(panel, "audioVolume").activeFocus, true);
                for (const name of ["audioDecrease", "audioMute", "audioIncrease", "quickSettings", "audioClose"]) {
                    keyClick(Qt.Key_Tab);
                    const control = findChild(panel, name);
                    tryCompare(control, "activeFocus", true);
                    tryVerify(() => {
                        const viewport = name === "audioClose" ? panel : scroll.contentItem;
                        const p = control.mapToItem(viewport, 0, 0);
                        return p.y >= 0 && p.y + control.height <= viewport.height + 1;
                    }, 1000, name + " must be revealed by Tab");
                }
                panel.height = Qt.binding(() => panel.implicitHeight);
            }
        }
    }
}
