#!/usr/bin/env python3
"""Run the real Quickshell MVP against isolated, disposable state and source."""
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
QS = os.environ.get("SENNTISTEN_QUICKSHELL") or shutil.which("quickshell")


class RunningShell:
    def __init__(self, initial_state=None):
        self.temp = tempfile.TemporaryDirectory(prefix="senntisten-test-")
        self.base = Path(self.temp.name)
        self.source = self.base / "shell"
        self.entry = self.source / "PlaygroundRoot.qml"
        self.target = "senntisten"
        shutil.copytree(ROOT / "shell", self.source)
        self.state = self.base / "state"
        self.state.mkdir(mode=0o700)
        self.state_file = self.state / "appearance.json"
        if initial_state is not None:
            self.state_file.write_text(initial_state)
        self.runtime = self.base / "runtime"
        self.runtime.mkdir(mode=0o700)
        (self.base / "home").mkdir(mode=0o700)
        self.env = os.environ.copy()
        self.env.update({
            "HOME": str(self.base / "home"),
            "SENNTISTEN_STATE_DIR": str(self.state),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "XDG_CACHE_HOME": str(self.base / "cache"),
            "XDG_CONFIG_HOME": str(self.base / "config"),
            "XDG_CONFIG_DIRS": str(self.base / "config-dirs"),
            "XDG_DATA_HOME": str(self.base / "data"),
            "XDG_DATA_DIRS": str(self.base / "data-dirs"),
            "XDG_STATE_HOME": str(self.state),
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(self.base / "no-session-bus"),
            "PIPEWIRE_REMOTE": str(self.base / "no-pipewire"),
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QUICK_BACKEND": "software",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "NO_COLOR": "1",
        })
        self.env.pop("WAYLAND_DISPLAY", None)
        self.env.pop("DISPLAY", None)
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        self.process = None
        self.log = None

    def start(self):
        self.log = (self.base / "quickshell.log").open("w+")
        self.process = subprocess.Popen(
            [QS, "--no-color", "--path", str(self.entry)],
            env=self.env, stdout=self.log, stderr=subprocess.STDOUT,
        )
        return self.wait_for(lambda state: state.get("ready"))

    def output(self):
        if self.log:
            self.log.flush()
        return (self.base / "quickshell.log").read_text()

    def call(self, function, *arguments):
        result = subprocess.run(
            [QS, "ipc", "--path", str(self.entry), "call", self.target, function,
             *(str(argument).lower() if isinstance(argument, bool) else str(argument)
               for argument in arguments)],
            env=self.env, capture_output=True, text=True, timeout=3,
        )
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        return result.stdout.strip()

    def status(self):
        reply = self.call("status")
        try:
            return json.loads(reply)
        except ValueError as error:
            raise RuntimeError(f"Invalid status reply: {reply!r}") from error

    def wait_for(self, predicate, timeout=10):
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError("Quickshell exited before becoming ready:\n" + self.output())
            try:
                last = self.status()
                if predicate(last):
                    return last
            except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
                last = str(error)
            time.sleep(0.06)
        raise AssertionError(f"Quickshell readiness timed out: {last}\n{self.output()}")

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=3)
        if self.log:
            self.log.close()
            self.log = None

    def close(self):
        self.stop()
        self.temp.cleanup()


class ShellIntegration(unittest.TestCase):
    def launch(self, initial_state=None):
        self.assertTrue(QS, "Quickshell must be available: run this inside nix develop")
        self.assertTrue((ROOT / "shell/PlaygroundRoot.qml").is_file(), "The standalone QML entry point must exist")
        shell = RunningShell(initial_state)
        self.addCleanup(shell.close)
        shell.start()
        return shell

    def test_theme_switch_updates_the_window_and_survives_restart(self):
        shell = self.launch()
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda value: value["saveStatus"] == "saved")
        self.assertEqual(state["theme"], "gruvbox")
        self.assertEqual(state["background"], "#1d2021")
        self.assertEqual(json.loads(shell.state_file.read_text()), {
            "schemaVersion": 1, "theme": "gruvbox", "reducedMotion": False,
        })
        shell.stop()
        restored = shell.start()
        self.assertEqual(restored["theme"], "gruvbox")
        self.assertEqual(restored["background"], "#1d2021")
        self.assertEqual(restored["saveStatus"], "saved")

    def test_failed_save_is_reported_and_existing_data_is_not_destroyed(self):
        shell = self.launch()
        shell.state_file.mkdir()
        (shell.state_file / "keep").write_text("existing data")
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        state = shell.wait_for(lambda value: value["saveStatus"] == "error", timeout=3)
        self.assertIn("save", state["message"].lower())
        self.assertEqual((shell.state_file / "keep").read_text(), "existing data")
        self.assertEqual(state["theme"], "gruvbox", "An unsaved preview may remain visible")

    def test_real_qml_controls(self):
        self.assertTrue(QS, "Run this inside nix develop")
        shell = RunningShell()
        self.addCleanup(shell.close)
        shutil.copyfile(ROOT / "tests/ui.qml", shell.source / "UiTest.qml")
        result = subprocess.run(
            [QS, "--no-color", "--path", str(shell.source / "UiTest.qml")],
            env=shell.env, capture_output=True, text=True, timeout=25,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        match = re.search(r"SENNTISTEN_UI_RESULT (\{.*\})", output)
        self.assertIsNotNone(match, output)
        result = json.loads(match.group(1))
        self.assertEqual(result["failed"], 0, output)
        self.assertEqual(result["skipped"], 0, output)
        self.assertGreater(result["passed"], 0, output)
        expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/ui.qml").read_text())
        self.assertEqual(sorted(result["executed"]), sorted(expected), output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        print(f"  QtTest: {len(result['executed'])} real-control/render cases passed", flush=True)

    def test_selecting_the_saved_theme_again_does_not_get_stuck_saving(self):
        shell = self.launch()
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        shell.wait_for(lambda state: state["saveStatus"] == "saved")
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        shell.wait_for(lambda state: state["saveStatus"] == "saved", timeout=2)

    def test_qml_edits_hot_reload_without_restarting_the_process(self):
        shell = self.launch()
        original_pid = shell.process.pid
        shell.call("theme", "gruvbox")
        shell.wait_for(lambda state: state["saveStatus"] == "saved")
        app = shell.source / "App.qml"
        source = app.read_text()
        self.assertEqual(source.count("Senntisten · Theme playground"), 1)
        app.write_text(source.replace("Senntisten · Theme playground", "Senntisten · Reload verified"))
        state = shell.wait_for(lambda state: state.get("title") == "Senntisten · Reload verified")
        self.assertEqual(shell.process.pid, original_pid)
        self.assertEqual(state["theme"], "gruvbox")
        self.assertEqual(state["background"], "#1d2021")

    def test_newer_state_is_preserved_and_cannot_be_downgraded(self):
        original = json.dumps({"schemaVersion": 2, "theme": "future-theme", "extra": "preserve"})
        shell = self.launch(original)
        self.assertEqual(shell.status()["saveStatus"], "blocked")
        self.assertEqual(shell.call("theme", "gruvbox"), "false")
        self.assertEqual(shell.state_file.read_text(), original)

    def test_corrupt_state_is_only_replaced_after_an_explicit_selection(self):
        shell = self.launch("{incomplete")
        self.assertEqual(shell.status()["saveStatus"], "recovered")
        self.assertTrue(shell.status()["message"])
        self.assertEqual(shell.state_file.read_text(), "{incomplete")
        shell.call("theme", "gruvbox")
        shell.wait_for(lambda state: state["saveStatus"] == "saved")
        self.assertEqual(json.loads(shell.state_file.read_text())["theme"], "gruvbox")

    def test_existing_empty_state_is_reported_and_preserved_until_selection(self):
        original = "  \n\t"
        shell = self.launch(original)
        state = shell.status()
        self.assertEqual(state["saveStatus"], "recovered")
        self.assertTrue(state["message"])
        self.assertEqual(shell.state_file.read_text(), original)
        shell.call("theme", "gruvbox")
        shell.wait_for(lambda current: current["saveStatus"] == "saved")
        self.assertEqual(json.loads(shell.state_file.read_text())["theme"], "gruvbox")

    def test_unknown_theme_is_rejected_without_writing(self):
        shell = self.launch()
        self.assertEqual(shell.call("theme", "__proto__"), "false")
        self.assertEqual(shell.status()["theme"], "catppuccin-mocha")
        self.assertFalse(shell.state_file.exists())

    def test_failed_save_can_be_retried_after_the_cause_is_removed(self):
        shell = self.launch()
        shell.state_file.mkdir()
        shell.call("theme", "gruvbox")
        shell.wait_for(lambda state: state["saveStatus"] == "error")
        shell.state_file.rmdir()
        self.assertEqual(shell.call("theme", "gruvbox"), "true")
        shell.wait_for(lambda state: state["saveStatus"] == "saved", timeout=3)
        self.assertEqual(json.loads(shell.state_file.read_text())["theme"], "gruvbox")

    def test_embedded_appearance_close_keeps_its_host_running(self):
        shell = RunningShell()
        self.addCleanup(shell.close)
        shell.entry = shell.source / "SettingsHost.qml"
        shell.target = "test-host"
        shell.entry.write_text("""import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "services"
ShellRoot {
    App {
        id: appearance
        Component.onCompleted: if ("standalone" in appearance) appearance.standalone = false
    }
    IpcHandler {
        target: "test-host"
        function status(): string { return JSON.stringify({ ready: Theme.ready, visible: appearance.visible }); }
        function closeAppearance(): void { appearance.visible = false; appearance.closed(); }
        function showAppearance(): void { appearance.visible = true; }
    }
}
""")
        shell.start()
        shell.call("closeAppearance")
        shell.wait_for(lambda state: not state["visible"])
        shell.call("showAppearance")
        shell.wait_for(lambda state: state["visible"])
        self.assertIsNone(shell.process.poll())

    def test_first_launch_opens_a_themed_window_without_writing_state(self):
        shell = self.launch()
        state = shell.status()
        self.assertTrue(state["visible"])
        self.assertGreater(state["width"], 0)
        self.assertEqual(state["theme"], "catppuccin-mocha")
        self.assertEqual(state["background"], "#11111b")
        self.assertEqual(state["saveStatus"], "default")
        self.assertFalse(shell.state_file.exists(), "Starting the playground must not silently write defaults")


if __name__ == "__main__":
    unittest.main(verbosity=2)
