#!/usr/bin/env python3
"""Real dedicated Settings QML and persistence, isolated from the live session."""
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import unittest

from integration import QS, ROOT, RunningShell


SETTINGS_HOST = '''import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "services"
ShellRoot {
    App { id: app; standalone: false }
    IpcHandler {
        target: "settings-test"
        function status(): string {
            const view = app.settingsView;
            const label = view ? view.feedbackLabel : null;
            return JSON.stringify({
                ready: Theme.ready, visible: app.visible,
                uiAvailable: view !== undefined, theme: Theme.settings.theme,
                reducedMotion: Theme.settings.reducedMotion,
                saveStatus: Theme.saveStatus, message: Theme.message,
                writable: Theme.writable,
                feedback: label ? label.text : "",
                feedbackVisible: label ? label.visible : false,
                feedbackHeight: label ? label.height : 0,
                feedbackLines: label ? label.lineCount : 0,
                feedbackWrapped: label ? label.wrapMode === Text.Wrap && label.elide === Text.ElideNone : false,
                editable: view ? view.preferencesEnabled : false
            });
        }
        function theme(id: string): bool { return Theme.selectTheme(id); }
        function motion(value: bool): bool { return Theme.setReducedMotion(value); }
        function closeSettings(): void { app.visible = false; app.closed(); }
        function showSettings(): void { app.visible = true; }
        function narrow(): void {
            app.contentItem.Window.window.width = 320;
            app.contentItem.Window.window.height = 360;
        }
        function capture(name: string): void {
            const directory = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
            if (directory && app.settingsView)
                app.settingsView.grabToImage(result => result.saveToFile(directory + "/settings-" + name + ".png"));
        }
    }
}
'''


def safe_runner(initial_state=None):
    shell = RunningShell(initial_state)
    for name in ("home", "data", "data-dirs", "config-dirs"):
        (shell.base / name).mkdir(mode=0o700, exist_ok=True)
    for name in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE",
                 "HYPRLAND_CMD", "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS",
                 "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"):
        shell.env.pop(name, None)
    shell.env.update({
        "HOME": str(shell.base / "home"),
        "XDG_STATE_HOME": str(shell.state),
        "XDG_DATA_HOME": str(shell.base / "data"),
        "XDG_DATA_DIRS": str(shell.base / "data-dirs"),
        "XDG_CONFIG_DIRS": str(shell.base / "config-dirs"),
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(shell.base / "no-session-bus"),
        "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(shell.base / "no-system-bus"),
        "PIPEWIRE_REMOTE": str(shell.base / "no-pipewire"),
    })
    return shell


class SettingsIntegration(unittest.TestCase):
    def setUp(self):
        self.assertTrue(QS, "Run inside nix develop")
        capture = os.environ.get("SENNTISTEN_CAPTURE_DIR")
        if capture:
            Path(capture).mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        result = getattr(self, "_outcome").result
        failed = any(test is self for test, _ in result.failures + result.errors)
        print("SENNTISTEN_SETTINGS_PY_CASE " + json.dumps({
            "name": self._testMethodName, "executed": True,
            "passed": not failed, "failed": failed,
        }), flush=True)

    def launch(self, initial_state=None):
        shell = safe_runner(initial_state)
        self.addCleanup(shell.close)
        shell.entry = shell.source / "SettingsHost.qml"
        shell.entry.write_text(SETTINGS_HOST)
        shell.target = "settings-test"
        state = shell.start()
        self.assertTrue(state["uiAvailable"], "App must expose settingsView\n" + shell.output())
        return shell

    def evidence(self, shell, name):
        capture = os.environ.get("SENNTISTEN_CAPTURE_DIR")
        if capture:
            image = Path(capture) / ("settings-" + name + ".png")
            image.unlink(missing_ok=True)
            shell.call("capture", name)
            shell.wait_for(lambda _: image.is_file() and image.stat().st_size >= 24)
            self.assert_png(image, 320, 360)
            (Path(capture) / ("settings-" + name + ".log")).write_text(shell.output())

    def assert_png(self, image, width, height):
        self.assertTrue(image.is_file(), str(image))
        with image.open("rb") as stream:
            header = stream.read(24)
        self.assertEqual(len(header), 24, str(image))
        self.assertEqual(header[:8], b"\x89PNG\r\n\x1a\n", str(image))
        self.assertEqual(header[8:16], b"\x00\x00\x00\rIHDR", str(image))
        self.assertEqual(struct.unpack(">II", header[16:24]), (width, height), str(image))

    def assert_feedback(self, state):
        self.assertTrue(state["feedbackVisible"], state)
        self.assertTrue(state["feedbackWrapped"], state)
        self.assertGreater(state["feedbackHeight"], 0, state)
        self.assertNotIn("saved", state["feedback"].lower(), state)

    def test_capture_validation_rejects_bad_png_headers_and_dimensions(self):
        shell = safe_runner()
        self.addCleanup(shell.close)
        image = shell.base / "capture.png"
        header = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR" + struct.pack(">II", 320, 360)
        for invalid in (b"not PNG\n" + header[8:], header[:20],
                        header[:12] + b"nope" + header[16:],
                        header[:16] + struct.pack(">II", 860, 650)):
            image.write_bytes(invalid)
            with self.assertRaises(AssertionError, msg=repr(invalid)):
                self.assert_png(image, 320, 360)
        image.write_bytes(header)
        self.assert_png(image, 320, 360)

    def test_real_settings_controls_and_rendered_layout(self):
        shell = safe_runner()
        self.addCleanup(shell.close)
        shutil.copyfile(ROOT / "tests/settings-ui.qml", shell.source / "SettingsUiTest.qml")
        capture = os.environ.get("SENNTISTEN_CAPTURE_DIR")
        captures = (
            ("catppuccin-mocha-wide", 860, 650),
            ("catppuccin-mocha-narrow", 320, 360),
            ("gruvbox-wide", 860, 650),
            ("gruvbox-narrow", 320, 360),
            ("narrow-scrolled", 320, 360),
        )
        if capture:
            for name, _, _ in captures:
                (Path(capture) / ("settings-" + name + ".png")).unlink(missing_ok=True)
        assert QS is not None
        try:
            process = subprocess.run(
                [QS, "--no-color", "--path", str(shell.source / "SettingsUiTest.qml")],
                env=shell.env, capture_output=True, text=True, timeout=45,
            )
        except subprocess.TimeoutExpired as error:
            output = "".join(value.decode() if isinstance(value, bytes) else value or ""
                             for value in (error.stdout, error.stderr))
            self.fail("Settings QtTest timed out:\n" + output)
        output = process.stdout + process.stderr
        if capture:
            (Path(capture) / "settings-qttest.log").write_text(output)
        matches = re.findall(r"SENNTISTEN_SETTINGS_RESULT (\{.*\})", output)
        self.assertEqual(len(matches), 1, output)
        result = json.loads(matches[0])
        print("SENNTISTEN_SETTINGS_QT_EXECUTED " + json.dumps(result), flush=True)
        expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/settings-ui.qml").read_text())
        self.assertEqual(sorted(result["executed"]), sorted(expected), output)
        self.assertEqual(result["failed"], 0, output)
        self.assertEqual(result["skipped"], 0, output)
        self.assertGreater(result["passed"], 0, output)
        self.assertEqual(process.returncode, 0, output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        if capture:
            for name, width, height in captures:
                self.assert_png(Path(capture) / ("settings-" + name + ".png"), width, height)

    def test_failed_save_is_visible_wrapped_and_can_be_retried(self):
        shell = self.launch()
        shell.state_file.mkdir()
        (shell.state_file / "keep").write_text("existing data")
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda current: current["saveStatus"] == "error")
        shell.call("narrow")
        state = shell.wait_for(lambda current: current["feedbackLines"] > 1)
        self.assert_feedback(state)
        self.assertIn("Could not save", state["feedback"])
        self.assertEqual((shell.state_file / "keep").read_text(), "existing data")
        self.evidence(shell, "save-failure-narrow")
        (shell.state_file / "keep").unlink()
        shell.state_file.rmdir()
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda current: current["saveStatus"] == "saved")
        self.assertEqual(state["feedback"], "Appearance saved.")
        self.assertEqual(json.loads(shell.state_file.read_text())["theme"], "gruvbox")

    def test_newer_schema_disables_preferences_and_is_never_overwritten(self):
        original = json.dumps({"schemaVersion": 9, "theme": "future", "extra": "keep"})
        shell = self.launch(original)
        shell.call("narrow")
        state = shell.wait_for(lambda current: current["feedbackLines"] > 1)
        self.assertEqual(state["saveStatus"], "blocked")
        self.assertFalse(state["writable"])
        self.assertFalse(state["editable"])
        self.assert_feedback(state)
        self.assertIn("newer", state["feedback"])
        self.assertEqual(shell.call("theme", "gruvbox"), "false")
        self.assertEqual(shell.call("motion", True), "false")
        self.assertEqual(shell.state_file.read_text(), original)
        self.evidence(shell, "newer-schema-narrow")

    def test_corrupt_state_is_visible_and_only_explicit_changes_replace_it(self):
        shell = self.launch("{incomplete")
        state = shell.status()
        self.assertEqual(state["saveStatus"], "recovered")
        self.assert_feedback(state)
        self.assertIn("Invalid appearance", state["feedback"])
        self.assertEqual(shell.state_file.read_text(), "{incomplete")
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        shell.wait_for(lambda current: current["saveStatus"] == "saved")
        self.assertEqual(json.loads(shell.state_file.read_text())["theme"], "gruvbox")

    def test_preferences_survive_restart_and_window_close_does_not_quit(self):
        shell = self.launch()
        self.assertFalse(shell.state_file.exists(), "Opening Settings must not silently save defaults")
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        self.assertEqual(shell.call("motion", True), "true")
        shell.wait_for(lambda current: current["saveStatus"] == "saved")
        self.assertEqual(json.loads(shell.state_file.read_text()), {
            "schemaVersion": 1, "theme": "gruvbox", "reducedMotion": True,
        })
        shell.call("closeSettings")
        shell.wait_for(lambda current: not current["visible"])
        assert shell.process is not None
        self.assertIsNone(shell.process.poll())
        shell.call("showSettings")
        shell.wait_for(lambda current: current["visible"])
        shell.stop()
        state = shell.start()
        self.assertEqual(state["theme"], "gruvbox")
        self.assertTrue(state["reducedMotion"])
        self.assertEqual(state["saveStatus"], "saved")

    def test_standalone_playground_behavior_is_preserved(self):
        shell = safe_runner()
        self.addCleanup(shell.close)
        state = shell.start()
        self.assertIn("Theme playground", state["title"])
        self.assertTrue(state["visible"])
        self.assertEqual(state["width"], 1080)
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda current: current["saveStatus"] == "saved")
        self.assertEqual(state["background"], "#1d2021")
        assert shell.process is not None
        self.assertIsNone(shell.process.poll())


if __name__ == "__main__":
    unittest.main(verbosity=2)
