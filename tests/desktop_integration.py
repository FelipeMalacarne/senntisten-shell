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
Scope {
    property var screen
    property bool previewMode: false
    signal launcherRequested()
    signal appearanceRequested()
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

    def test_preview_is_explicit_and_quit_only_stops_its_instance(self):
        shell = self.launch(preview=True)
        self.assertTrue(shell.status()["preview"])
        shell.call("quit")
        self.assertEqual(shell.process.wait(timeout=5), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
