"""Real Orbit Quick Controls, isolated from every live desktop provider."""
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import unittest

from integration import ROOT, QS, RunningShell


class QuickControlsIntegration(unittest.TestCase):
    def test_real_quick_controls(self):
        self.assertTrue(QS, "Run inside nix develop")
        shell = RunningShell()
        self.addCleanup(shell.close)
        shell.env.update({
            "HOME": str(shell.base / "home"),
            "XDG_DATA_HOME": str(shell.base / "data"),
            "XDG_DATA_DIRS": str(shell.base / "data-dirs"),
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(shell.base / "no-bus"),
            "PIPEWIRE_REMOTE": str(shell.base / "no-pipewire"),
        })
        shell.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        harness = ROOT / "tests/quick-controls-ui.qml"
        entry = shell.source / "QuickControlsTest.qml"
        shutil.copyfile(harness, entry)
        proc = subprocess.run(
            [QS, "--no-color", "--path", str(entry)], env=shell.env,
            capture_output=True, text=True, timeout=35,
        )
        output = proc.stdout + proc.stderr
        self.assertEqual(proc.returncode, 0, output)
        match = re.search(r"SENNTISTEN_CONTROLS_RESULT (\{.*\})", output)
        self.assertIsNotNone(match, output)
        result = json.loads(match.group(1))
        self.assertEqual(result["failed"], 0, output)
        self.assertEqual(result["skipped"], 0, output)
        expected = re.findall(r"function (test_\w+)\(", harness.read_text())
        self.assertEqual(sorted(result["executed"]), sorted(expected), output)
        self.assertGreater(result["passed"], 0, output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        capture_dir = os.environ.get("SENNTISTEN_CAPTURE_DIR")
        if capture_dir:
            for theme in ("catppuccin-mocha", "gruvbox"):
                image = Path(capture_dir) / f"orbit-controls-{theme}.png"
                self.assertTrue(image.is_file(), image)
                data = image.read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                width, height = struct.unpack(">II", data[16:24])
                self.assertEqual(width, 340)
                self.assertGreater(height, 340)
        print(f"  Quick Controls QtTest: {len(expected)} real-control/render cases passed", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
