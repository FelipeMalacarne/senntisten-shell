"""Native connectivity services/controls with no reachable desktop providers."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
QS = os.environ.get("SENNTISTEN_QUICKSHELL") or shutil.which("quickshell")


class ConnectivityIntegration(unittest.TestCase):
    def test_services_and_real_controls(self):
        self.assertTrue(QS, "Run inside nix develop")
        assert QS is not None
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S-%fZ")
        artifacts = ROOT / "artifacts" / "connectivity" / stamp
        artifacts.mkdir(parents=True)
        # Keep native IPC socket paths below Unix's 108-byte limit.
        with tempfile.TemporaryDirectory(prefix=".ct-", dir=ROOT) as temporary:
            base = Path(temporary)
            source = base / "shell"
            shutil.copytree(ROOT / "shell", source)
            entry = source / "ConnectivityTest.qml"
            shutil.copyfile(ROOT / "tests/connectivity-ui.qml", entry)
            env = os.environ.copy()
            for key in list(env):
                if key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET") or key.startswith("HYPRLAND"):
                    env.pop(key)
            for key, leaf in {
                "HOME": "home", "XDG_STATE_HOME": "state", "XDG_CONFIG_HOME": "config",
                "XDG_CONFIG_DIRS": "config-dirs", "XDG_DATA_HOME": "data",
                "XDG_DATA_DIRS": "data-dirs", "XDG_CACHE_HOME": "cache",
                "XDG_RUNTIME_DIR": "r", "SENNTISTEN_STATE_DIR": "appearance",
            }.items():
                directory = base / leaf
                directory.mkdir(mode=0o700)
                env[key] = str(directory)
            env.update({
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(base / "no-session-bus"),
                "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(base / "no-system-bus"),
                "PIPEWIRE_REMOTE": str(base / "no-pipewire"),
                "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                "QT_QUICK_CONTROLS_STYLE": "Basic", "NO_COLOR": "1",
                "SENNTISTEN_CONNECTIVITY_CAPTURE_DIR": str(artifacts),
            })
            process = subprocess.run(
                [QS, "--no-color", "--path", str(entry)], env=env,
                capture_output=True, text=True, timeout=60,
            )
            output = process.stdout + process.stderr
            messages = "\n".join(line for line in output.splitlines() if "CONNECTIVITY_CHECKPOINT" not in line)
            (artifacts / "quickshell.log").write_text(output)
            for record in re.findall(r"SENNTISTEN_CONNECTIVITY_CHECKPOINT (\{[^\n]*\})", output):
                checkpoint = json.loads(record)
                (artifacts / (checkpoint["name"] + ".json")).write_text(json.dumps(checkpoint, indent=2))
            print(f"  Connectivity artifacts: {artifacts}", flush=True)
            self.assertEqual(process.returncode, 0, messages)
            match = re.search(r"SENNTISTEN_CONNECTIVITY_RESULT (\{.*\})", output)
            self.assertIsNotNone(match, messages)
            assert match is not None
            result = json.loads(match.group(1))
            (artifacts / "result.json").write_text(json.dumps(result, indent=2))
            self.assertEqual(result["failed"], 0, messages)
            self.assertEqual(result["skipped"], 0, messages)
            expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/connectivity-ui.qml").read_text())
            self.assertEqual(sorted(result["executed"]), sorted(expected), messages)
            # This exact native diagnostic is expected with the intentionally dead bus.
            diagnostics = output.replace(
                "ERROR quickshell.network: Network will not work. Could not find an available backend.", ""
            )
            self.assertNotRegex(diagnostics, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR")
            images = list(artifacts.glob("*.png"))
            self.assertGreaterEqual(len(images), 10)
            for image in images:
                data = image.read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n", image)
                width, height = struct.unpack(">II", data[16:24])
                self.assertIn(width, (252, 340), image)
                if image.stem.endswith("-340"):
                    self.assertEqual(width, 340, image)
                evidence = json.loads(image.with_suffix(".json").read_text())
                self.assertGreater(len(evidence["controls"]), 0, image)
                self.assertGreater(height, 0, image)
            print(f"  Connectivity QtTest: {len(expected)} behavioral cases, {len(images)} PNGs", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
