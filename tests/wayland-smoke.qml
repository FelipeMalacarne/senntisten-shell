//@ pragma UseQApplication
import QtQuick
import QtTest
import Quickshell
import "."
import "services"

ShellRoot {
    Desktop {
        id: desktop
    }
    TestCase {
        name: "SenntistenWayland"
        when: Theme.ready && desktop.barsUnderTest.instances.length > 0
        property var executed: []
        property string checkpoint: ""
        function init() {
            executed = executed.concat([qtest_results.functionName]);
            desktop.launcherUnderTest.opened = false;
            desktop.settingsUnderTest.visible = false;
            desktop.closeDashboards();
        }
        function cleanup() {
            console.log("WAYLAND_CASE " + JSON.stringify({
                name: qtest_results.functionName,
                failed: qtest_results.failed,
                checkpoint: checkpoint,
                launcherOpen: desktop.launcherUnderTest.opened,
                settingsOpen: desktop.settingsUnderTest.visible
            }));
            desktop.launcherUnderTest.opened = false;
            desktop.settingsUnderTest.visible = false;
            desktop.closeDashboards();
        }
        onCompletedChanged: if (completed) {
            console.log("SENNTISTEN_WAYLAND_RESULT " + JSON.stringify({
                passed: qtest_results.passCount,
                failed: qtest_results.failCount,
                skipped: qtest_results.skipCount,
                executed: executed
            }));
        }
        function bar() {
            return desktop.barsUnderTest.instances[0];
        }
        function button(name) {
            const item = findChild(bar().contentItem, name);
            verify(item !== null, name);
            return item;
        }
        function test_real_bar_mouse_opens_the_native_launcher() {
            checkpoint = "click launcher on non-focusable layer bar";
            const launcher = desktop.launcherUnderTest;
            mouseClick(button("barLauncher"));
            tryCompare(launcher, "opened", true);
            tryCompare(launcher, "visible", true);
            const field = findChild(launcher.contentItem, "launcherSearch");
            tryVerify(() => field.activeFocus && field.width > 0);
            wait(150);
            verify(launcher.opened, "Opening click must not dismiss the launcher");
            keyClick(Qt.Key_Escape);
            tryCompare(launcher, "opened", false);
        }
        function test_real_bar_mouse_opens_settings_and_keeps_desktop_alive() {
            checkpoint = "click Settings on non-focusable layer bar";
            const settings = desktop.settingsUnderTest;
            mouseClick(button("barAppearance"));
            tryCompare(settings, "visible", true);
            tryVerify(() => settings.settingsView.visible);
            const close = findChild(settings.contentItem, "themeClose");
            mouseClick(close);
            tryCompare(settings, "visible", false);
            verify(bar().visible);
        }
        function test_real_bar_mouse_opens_quick_controls_and_routes_settings() {
            checkpoint = "click Quick Controls on layer bar";
            mouseClick(button("barAudio"));
            tryCompare(bar(), "dashboardOpen", true);
            const panel = bar().controlsUnderTest;
            const settings = findChild(panel, "quickSettings");
            checkpoint = "Quick Controls to Settings";
            mouseClick(settings);
            tryCompare(desktop.settingsUnderTest, "visible", true);
            tryCompare(bar(), "dashboardOpen", false);
            mouseClick(findChild(desktop.settingsUnderTest.contentItem, "themeClose"));
            tryCompare(desktop.settingsUnderTest, "visible", false);
            tryCompare(bar(), "dashboardOpen", true);
            tryCompare(settings, "activeFocus", true);
        }
    }
}
