#!/usr/bin/env python3
"""Exercise bar controls in a normal offscreen window, never a live desktop.

Only the native OS service boundary is replaced in interactive cases. Service
imports also execute against isolated, deliberately unavailable endpoints.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
QS = os.environ.get("SENNTISTEN_QUICKSHELL") or shutil.which("quickshell")


class BarIntegration(unittest.TestCase):
    def test_real_bar_controls(self):
        self.assertTrue(QS, "Run inside nix develop")
        with tempfile.TemporaryDirectory(prefix="senntisten-bar-test-") as temp:
            base = Path(temp)
            source = base / "shell"
            shutil.copytree(ROOT / "shell", source)
            shutil.copyfile(ROOT / "tests/bar-ui.qml", source / "BarTest.qml")
            # Offscreen never registers the generic PanelWindow factory. Compile
            # its pinned, concrete Wayland backend instead; do NOT instantiate it.
            bar = source / "desktop/Bar.qml"
            if bar.exists():
                text = bar.read_text()
                self.assertEqual(text.count("\nPanelWindow {"), 1)
                bar.write_text(text.replace("\nPanelWindow {", "\nWlrLayershell {", 1))
            for name in ("runtime", "state", "home"):
                (base / name).mkdir(mode=0o700)
            env = os.environ.copy()
            env.update({
                "HOME": str(base / "home"),
                "SENNTISTEN_STATE_DIR": str(base / "state"),
                "XDG_RUNTIME_DIR": str(base / "runtime"),
                "XDG_CACHE_HOME": str(base / "cache"),
                "XDG_CONFIG_HOME": str(base / "config"),
                "XDG_DATA_HOME": str(base / "data"),
                "XDG_STATE_HOME": str(base / "state"),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "QT_QUICK_CONTROLS_STYLE": "Basic",
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(base / "no-session-bus"),
                "PIPEWIRE_REMOTE": str(base / "no-pipewire"),
                "NO_COLOR": "1",
            })
            for key in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            proc = subprocess.run(
                [QS, "--no-color", "--path", str(source / "BarTest.qml")],
                env=env, capture_output=True, text=True, timeout=35,
            )
            output = proc.stdout + proc.stderr
            self.assertEqual(proc.returncode, 0, output)
            match = re.search(r"SENNTISTEN_BAR_RESULT (\{.*\})", output)
            self.assertIsNotNone(match, output)
            result = json.loads(match.group(1))
            self.assertEqual(result["failed"], 0, output)
            self.assertEqual(result["skipped"], 0, output)
            expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/bar-ui.qml").read_text())
            self.assertEqual(sorted(result["executed"]), sorted(expected), output)
            self.assertGreater(result["passed"], 0, output)
            self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
            print(f"  Bar QtTest: {len(expected)} real-control cases passed", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
