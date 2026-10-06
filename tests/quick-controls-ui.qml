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
                services.audioAvailable = true;
                services.volume = 0.42;
                services.muted = false;
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
        }
    }
}
