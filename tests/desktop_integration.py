"""Desktop composition tests; replace only Wayland surfaces in offscreen runs."""
import unittest

from integration import ROOT, RunningShell


class DesktopIntegration(unittest.TestCase):
    def launch(self, preview=False):
        self.assertTrue((ROOT / "shell/Desktop.qml").is_file(), "A real desktop composition root is required")
        shell = RunningShell()
        self.addCleanup(shell.close)
        shell.entry = shell.source / "shell.qml"
        shell.env["SENNTISTEN_PREVIEW"] = "1" if preview else "0"
        surface_dir = shell.source / "desktop"
        surface_dir.mkdir(exist_ok=True)
        # No compositor mutations here. Bar/launcher content have separate real UI tests;
        # this fixture isolates desktop wiring, IPC, and the genuine appearance service.
        (surface_dir / "Bar.qml").write_text('''import Quickshell
import Quickshell.Io
Scope {
    id: bar
    property var screen
    property bool previewMode: false
    property bool dashboardOpen: false
    property bool restoredSettingsFocus: false
    signal launcherRequested()
    signal appearanceRequested()
    signal dashboardRequested()
    signal settingsRequested()
    function openDashboard(restoreSettingsFocus) {
        dashboardOpen = true;
        restoredSettingsFocus = !!restoreSettingsFocus;
    }
    function closeDashboard() { dashboardOpen = false; }
    IpcHandler {
        target: "test-bar"
        function openSettings(): void { bar.settingsRequested(); }
        function status(): string {
            return JSON.stringify({ ready: true, restoredSettingsFocus: bar.restoredSettingsFocus });
        }
    }
}
''')
        (surface_dir / "Launcher.qml").write_text('''import Quickshell
Scope {
    property var screen
    property bool opened: false
    signal dismissed()
    function resetSearch() {}
}
''')
        shell.start()
        return shell

    def test_desktop_owns_launcher_and_appearance_actions(self):
        shell = self.launch()
        state = shell.status()
        self.assertEqual(state["mode"], "desktop")
        self.assertFalse(state["preview"])
        self.assertFalse(state["launcherOpen"])
        self.assertFalse(state["appearanceOpen"])
        shell.call("launcher")
        shell.wait_for(lambda state: state["launcherOpen"])
        shell.call("launcher")
        shell.wait_for(lambda state: not state["launcherOpen"])
        shell.call("settings")
        shell.wait_for(lambda state: state["appearanceOpen"])
        shell.call("settings")
        shell.wait_for(lambda state: not state["appearanceOpen"])
        self.assertIsNone(shell.process.poll())

    def test_desktop_uses_the_shared_persistent_theme(self):
        shell = self.launch()
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda state: state["saveStatus"] == "saved")
        self.assertEqual(state["theme"], "gruvbox")
        self.assertTrue(shell.state_file.is_file())
        shell.stop()
        restored = shell.start()
        self.assertEqual(restored["theme"], "gruvbox")

    def test_dashboard_is_separate_and_surface_actions_close_it(self):
        shell = self.launch()
        self.assertFalse(shell.status().get("dashboardOpen", False))
        self.assertEqual(shell.call("dashboard"), "true")
        shell.wait_for(lambda state: state["dashboardOpen"])
        self.assertFalse(shell.status()["appearanceOpen"])
        self.assertFalse(shell.status()["launcherOpen"])
        self.assertEqual(shell.call("dashboard"), "true")
        shell.wait_for(lambda state: not state["dashboardOpen"])
        shell.call("dashboard")
        shell.call("launcher")
        state = shell.wait_for(lambda state: state["launcherOpen"])
        self.assertFalse(state["dashboardOpen"])
        shell.call("dashboard")
        state = shell.wait_for(lambda state: state["dashboardOpen"])
        self.assertFalse(state["launcherOpen"])
        shell.call("settings")
        state = shell.wait_for(lambda state: state["appearanceOpen"])
        self.assertFalse(state["dashboardOpen"])
        self.assertIsNone(shell.process.poll())

    def test_settings_from_dashboard_returns_to_its_entry_point(self):
        shell = self.launch()
        shell.call("dashboard")
        shell.target = "test-bar"
        shell.call("openSettings")
        shell.target = "senntisten"
        state = shell.wait_for(lambda state: state["appearanceOpen"])
        self.assertFalse(state["dashboardOpen"])
        shell.call("settings")
        state = shell.wait_for(lambda state: not state["appearanceOpen"])
        self.assertTrue(state["dashboardOpen"])
        shell.target = "test-bar"
        self.assertTrue(shell.status()["restoredSettingsFocus"])
        self.assertIsNone(shell.process.poll())

    def test_preview_is_explicit_and_quit_only_stops_its_instance(self):
        shell = self.launch(preview=True)
        self.assertTrue(shell.status()["preview"])
        shell.call("quit")
        self.assertEqual(shell.process.wait(timeout=5), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
