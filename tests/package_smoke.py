#!/usr/bin/env python3
"""Smoke-test the built package and duplicate guard with real Quickshell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

PACKAGE = os.environ.get("SENNTISTEN_PACKAGE")
QS = shutil.which("quickshell")


class PackagedApplicationSmoke(unittest.TestCase):
    def test_built_playground_launches_and_refuses_a_duplicate(self):
        if not PACKAGE:
            self.fail("Set SENNTISTEN_PACKAGE to the built package output")
        if not QS:
            self.fail("Quickshell must be on PATH for local IPC verification")
        package = PACKAGE
        quickshell = QS
        executable = Path(package) / "bin/senntisten-shell"
        self.assertTrue(executable.is_file(), executable)
        with tempfile.TemporaryDirectory(prefix="senntisten-package-") as temporary:
            root = Path(temporary)
            for name in ("home", "state", "runtime", "cache", "config"):
                (root / name).mkdir(mode=0o700)
            env = os.environ.copy()
            env.update({
                "HOME": str(root / "home"),
                "SENNTISTEN_STATE_DIR": str(root / "state"),
                "XDG_STATE_HOME": str(root / "state"),
                "XDG_RUNTIME_DIR": str(root / "runtime"),
                "XDG_CACHE_HOME": str(root / "cache"),
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_CONFIG_DIRS": str(root / "config-dirs"),
                "XDG_DATA_HOME": str(root / "data"),
                "XDG_DATA_DIRS": str(root / "data-dirs"),
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(root / "no-session-bus"),
                "PIPEWIRE_REMOTE": str(root / "no-pipewire"),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "QT_QUICK_CONTROLS_STYLE": "Basic",
                "NO_COLOR": "1",
            })
            for name in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
                         "SENNTISTEN_SOURCE_DIR", "SENNTISTEN_QUICKSHELL", "SENNTISTEN_MODE",
                         "SENNTISTEN_PREVIEW", "SENNTISTEN_DISTRO_ID", "FONTCONFIG_FILE"):
                env.pop(name, None)
            command = [str(executable), "--playground", "--no-color"]
            process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            try:
                deadline = time.monotonic() + 15
                status = None
                last = ""
                while time.monotonic() < deadline:
                    self.assertIsNone(process.poll(), self._output(process))
                    result = subprocess.run(
                        [quickshell, "ipc", "--pid", str(process.pid), "call", "senntisten", "status"],
                        env=env, capture_output=True, text=True, timeout=3,
                    )
                    last = result.stdout + result.stderr
                    if result.returncode == 0:
                        try:
                            status = json.loads(result.stdout)
                            if status.get("ready"):
                                break
                        except ValueError:
                            pass
                    time.sleep(0.08)
                if status is None or not status.get("ready"):
                    self.fail(last + self._output(process))
                self.assertEqual(status["title"], "Senntisten · Theme playground")
                self.assertTrue(status["visible"])
                self.assertFalse((root / "state/appearance.json").exists())

                duplicate = subprocess.run(command, env=env, capture_output=True,
                                           text=True, timeout=10)
                self.assertEqual(duplicate.returncode, 0, duplicate.stdout + duplicate.stderr)
                self.assertIsNone(process.poll(), "Duplicate launch terminated the original instance")
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=3)
                if process.stdout:
                    process.stdout.close()

    @staticmethod
    def _output(process):
        if process.stdout and process.poll() is not None:
            return process.stdout.read()
        return ""


if __name__ == "__main__":
    unittest.main(verbosity=2)
