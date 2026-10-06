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

from commands_integration import PidShell
from desktop_integration import prepare_desktop

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
                discovery = subprocess.run([quickshell, "list", "--all", "--json"],
                                           env=env, capture_output=True, text=True, check=True)
                installed_entry = Path(next(entry["config_path"] for entry in json.loads(discovery.stdout)
                                            if entry["pid"] == process.pid))
                self.assertEqual(installed_entry.name, "PlaygroundRoot.qml")
                self._exercise_dispatch(executable, quickshell, env, installed_entry.parent, process.pid)
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

    def _exercise_dispatch(self, executable, quickshell, env, installed_source, playground_pid):
        shells = []
        for preview in (False, True):
            shell = PidShell()
            self.addCleanup(shell.close)
            # Exercise this build's actual controller, without mapping its layer wrappers.
            shutil.rmtree(shell.source)
            shutil.copytree(installed_source, shell.source, copy_function=shutil.copyfile)
            prepare_desktop(shell, preview)
            shell.env["XDG_RUNTIME_DIR"] = env["XDG_RUNTIME_DIR"]
            shell.start()
            shells.append(shell)
        current, other = shells
        command_state = current.base / "uncreated-command-state"
        command_home = current.base / "uncreated-command-home"
        command_env = {**env, "SENNTISTEN_STATE_DIR": str(command_state), "HOME": str(command_home)}

        def dispatch(*arguments, source=None):
            dispatch_env = command_env.copy()
            if source:
                dispatch_env["SENNTISTEN_SOURCE_DIR"] = str(source)
            result = subprocess.run([str(executable), *arguments], env=dispatch_env,
                                    capture_output=True, text=True, timeout=8)
            self.assertFalse(command_state.exists(), "Installed dispatch initialized state")
            self.assertFalse(command_home.exists(), "Installed dispatch initialized HOME")
            for shell in shells:
                self.assertFalse(shell.state_file.exists(), "Dispatch wrote appearance state")
                self.assertIsNone(shell.process.poll())
            return result

        for arguments, pattern in [
            (("launcher",), r"no.*instance|not running"),
            (("launcher", "--pid", str(playground_pid)), r"desktop|controller|mode"),
            (("session",), r"unconfigured.*007|007.*unconfigured"),
            (("lock",), r"unconfigured.*007|007.*unconfigured"),
            (("settings", "--pid", "0"), r"PID|pid"),
        ]:
            result = dispatch(*arguments)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertRegex(result.stderr, pattern)
        for action, field in [("launcher", "launcherOpen"), ("dashboard", "dashboardOpen"),
                              ("settings", "appearanceOpen")]:
            for expected in (True, False):
                result = dispatch(action, source=current.source)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                current.wait_for(lambda state: state[field] == expected)
                self.assertFalse(other.status()[field])
        result = dispatch("dashboard", "--pid", str(other.process.pid))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        other.wait_for(lambda state: state["dashboardOpen"])
        self.assertFalse(current.status()["dashboardOpen"])
        self.assertFalse(other.status()["appearanceOpen"])
        discovery = subprocess.run([quickshell, "list", "--all", "--json"], env=env,
                                   capture_output=True, text=True, check=True)
        self.assertEqual({entry["pid"] for entry in json.loads(discovery.stdout)},
                         {playground_pid, current.process.pid, other.process.pid})

    @staticmethod
    def _output(process):
        if process.stdout and process.poll() is not None:
            return process.stdout.read()
        return ""


if __name__ == "__main__":
    unittest.main(verbosity=2)
