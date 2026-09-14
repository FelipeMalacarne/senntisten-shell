#!/usr/bin/env python3
"""Exercise real launcher controls and native DesktopEntry execution offscreen.

The normal-window harness is intentional: layer-shell surfaces require a real
Wayland compositor and are not asserted to run on Qt's offscreen platform.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
QS = os.environ.get("SENNTISTEN_QUICKSHELL") or shutil.which("quickshell")


class LauncherSandbox:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senntisten-launcher-test-")
        self.base = Path(self.temp.name)
        self.source = self.base / "shell"
        shutil.copytree(ROOT / "shell", self.source)
        self.harness = self.source / "LauncherUiTest.qml"
        shutil.copyfile(ROOT / "tests/launcher-ui.qml", self.harness)
        for name in ("home", "state", "runtime", "cache", "config", "data", "data-dirs", "config-dirs", "work"):
            (self.base / name).mkdir(mode=0o700)
        self.applications = self.base / "data/applications"
        self.applications.mkdir()
        self.marker = self.base / "executed.jsonl"
        self.clear_entries = self.base / "clear_entries.py"
        self.clear_entries.write_text(
            "from pathlib import Path\n"
            f"for entry in Path({str(self.applications)!r}).glob('senntisten-test-*.desktop'):\n"
            "    entry.unlink()\n"
        )
        self.recorder = self.base / "record launch.py"
        self.recorder.write_text(
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "with Path(sys.argv[1]).open('a') as output:\n"
            "    output.write(json.dumps({'id': sys.argv[2], 'cwd': os.getcwd(), "
            "'dataHome': os.environ['XDG_DATA_HOME']}) + '\\n')\n"
        )
        self.icon = self.base / "test-icon.svg"
        self.icon.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                             '<rect width="32" height="32" fill="#00aa77"/></svg>')
        self.entry("alpha", "Alpha Browser", "Web Browser", "internet;web;")
        self.entry("beta", "Beta Notes", "Text Editor", "journal;writing;")
        self.entry("gamma", "Gamma Console", "Terminal Emulator", "console;")
        for index in range(10):
            self.entry(f"utility-{index:02}", f"Utility {index:02}")
        self.entry("hidden", "Hidden Fixture", extra="Hidden=true\n")
        self.entry("nodisplay", "Private Fixture", extra="NoDisplay=true\n")
        self.env = os.environ.copy()
        self.env.update({
            "HOME": str(self.base / "home"),
            "SENNTISTEN_STATE_DIR": str(self.base / "state"),
            "SENNTISTEN_LAUNCHER_MARKER": str(self.marker),
            "SENNTISTEN_LAUNCHER_ICON": str(self.icon),
            "SENNTISTEN_TEST_PYTHON": sys.executable,
            "SENNTISTEN_TEST_CLEAR_ENTRIES": str(self.clear_entries),
            "XDG_STATE_HOME": str(self.base / "state"),
            "XDG_RUNTIME_DIR": str(self.base / "runtime"),
            "XDG_CACHE_HOME": str(self.base / "cache"),
            "XDG_CONFIG_HOME": str(self.base / "config"),
            "XDG_CONFIG_DIRS": str(self.base / "config-dirs"),
            "XDG_DATA_HOME": str(self.base / "data"),
            # Nonempty: empty falls back to the host's /usr/share applications.
            "XDG_DATA_DIRS": str(self.base / "data-dirs"),
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QUICK_BACKEND": "software",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "NO_COLOR": "1",
        })
        for name in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE",
                     "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST", "SENNTISTEN_CAPTURE_DIR"):
            self.env.pop(name, None)

    def entry(self, identifier, name, generic="", keywords="", extra=""):
        # Desktop-entry argument quoting, not a shell command or shell eval.
        arguments = [sys.executable, str(self.recorder), str(self.marker), identifier]
        command = " ".join('"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"' for value in arguments)
        (self.applications / f"senntisten-test-{identifier}.desktop").write_text(
            f"[Desktop Entry]\nType=Application\nName={name}\nGenericName={generic}\n"
            f"Keywords={keywords}\nIcon={self.icon}\nExec={command}\n"
            f"Path={self.base / 'work'}\nTerminal=false\n{extra}"
        )

    def run(self):
        result = subprocess.run([QS, "--no-color", "--path", str(self.harness)],
                                env=self.env, capture_output=True, text=True, timeout=40)
        return result, result.stdout + result.stderr

    def close(self):
        self.temp.cleanup()


class LauncherIntegration(unittest.TestCase):
    def test_layer_wrapper_source_contract_not_runtime(self):
        # PanelWindow has no backend on offscreen Qt, including at compile time.
        # This wiring guard is explicitly not a compositor/layer-surface test.
        source = (ROOT / "shell/desktop/Launcher.qml").read_text()
        for declaration in (
            "PanelWindow {", "property bool opened: false", "signal dismissed()",
            "visible: opened", "exclusionMode: ExclusionMode.Ignore",
            'WlrLayershell.namespace: "senntisten-launcher"',
            "WlrLayershell.layer: WlrLayer.Overlay",
            "WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
            "function resetSearch()", "content.resetSearch()", "onDismissed: root.dismissed()",
        ):
            self.assertIn(declaration, source)
        self.assertNotRegex(source, r"property\s+\w+\s+screen\b|opened\s*=\s*(true|false)")

    def test_real_launcher_controls(self):
        self.assertTrue(QS, "Run this inside nix develop")
        sandbox = LauncherSandbox()
        self.addCleanup(sandbox.close)
        process, output = sandbox.run()
        self.assertEqual(process.returncode, 0, output)
        matches = re.findall(r"SENNTISTEN_LAUNCHER_UI_RESULT (\{.*\})", output)
        self.assertEqual(len(matches), 1, output)
        result = json.loads(matches[0])
        self.assertEqual(result["failed"], 0, output)
        self.assertEqual(result["skipped"], 0, output)
        self.assertGreater(result["passed"], 0, output)
        expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/launcher-ui.qml").read_text())
        self.assertEqual(sorted(result["executed"]), sorted(expected), output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        self.assertTrue(sandbox.marker.exists(), "Native DesktopEntry.execute() must create a marker\n" + output)
        launches = [json.loads(line) for line in sandbox.marker.read_text().splitlines()]
        self.assertEqual([entry["id"] for entry in launches], ["beta", "alpha", "gamma"])
        for entry in launches:
            self.assertEqual(entry["cwd"], str(sandbox.base / "work"))
            self.assertEqual(entry["dataHome"], str(sandbox.base / "data"))
        print("  Native execute marker: " + json.dumps(launches), flush=True)
        print("  " + json.dumps(result), flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
