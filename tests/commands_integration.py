"""Real command dispatch in a shared disposable runtime, never a live display."""
import json
import subprocess
import unittest

from desktop_integration import prepare_desktop
from integration import QS, ROOT, RunningShell


class PidShell(RunningShell):
    # Path IPC silently picks one instance when identities collide. Tests must not.
    def call(self, function, *arguments):
        result = subprocess.run(
            [QS, "ipc", "--pid", str(self.process.pid), "call", self.target, function,
             *(str(argument) for argument in arguments)],
            env=self.env, capture_output=True, text=True, timeout=3,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout.strip()


class CommandsIntegration(unittest.TestCase):
    def launch(self, shared=None, same_identity=False, preview=False, playground=False, no_screens=False):
        shell = PidShell()
        self.addCleanup(shell.close)
        if not playground:
            prepare_desktop(shell, preview)
            self.assertEqual((shell.source / "Desktop.qml").read_bytes(), (ROOT / "shell/Desktop.qml").read_bytes())
        if shared:
            shell.env["XDG_RUNTIME_DIR"] = shared.env["XDG_RUNTIME_DIR"]
        if same_identity:
            shell.entry = shared.entry
        if no_screens:
            config = shell.base / "offscreen.json"
            config.write_text(json.dumps({"screens": []}))
            shell.env["QT_QPA_PLATFORM"] = "offscreen:configfile=" + str(config)
        shell.start()
        return shell

    def dispatch(self, shell, *arguments, source=None):
        env = {**shell.env, "SENNTISTEN_SOURCE_DIR": str(source or shell.entry.parent),
               "SENNTISTEN_QUICKSHELL": QS,
               "QS_CONFIG_PATH": str(shell.base / "must-not-select.qml"),
               "SENNTISTEN_STATE_DIR": str(shell.base / "dispatch-state"),
               "HOME": str(shell.base / "dispatch-home"),
               "XDG_STATE_HOME": str(shell.base / "dispatch-xdg-state")}
        before = {path.name: path.read_bytes() for path in shell.state.iterdir() if path.is_file()}
        result = subprocess.run([str(ROOT / "bin/senntisten-shell"), *arguments],
                                env=env, capture_output=True, text=True, timeout=8)
        for name in ("dispatch-state", "dispatch-home", "dispatch-xdg-state"):
            self.assertFalse((shell.base / name).exists(), f"Dispatch initialized {name}")
        self.assertEqual(before, {path.name: path.read_bytes() for path in shell.state.iterdir() if path.is_file()})
        return result

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_default_toggles_only_the_current_identity_with_two_instances(self):
        current = self.launch()
        other = self.launch(shared=current, preview=True)
        original_other = other.status()
        for action, field in [("launcher", "launcherOpen"), ("dashboard", "dashboardOpen"),
                              ("settings", "appearanceOpen")]:
            self.assert_success(self.dispatch(current, action))
            current.wait_for(lambda state: state[field])
            self.assertEqual(other.status(), original_other)
            self.assert_success(self.dispatch(current, action))
            current.wait_for(lambda state: not state[field])
        self.assertIsNone(current.process.poll())
        self.assertIsNone(other.process.poll())
        instances = subprocess.run([QS, "list", "--all", "--json"], env=current.env,
                                   capture_output=True, text=True, check=True)
        self.assertEqual({entry["pid"] for entry in json.loads(instances.stdout)},
                         {current.process.pid, other.process.pid})

    def test_explicit_pid_targets_preview_of_another_build_not_the_default(self):
        current = self.launch()
        older = self.launch(shared=current, preview=True)
        self.assert_success(self.dispatch(current, "dashboard", "--pid", str(older.process.pid)))
        older.wait_for(lambda state: state["dashboardOpen"])
        self.assertFalse(current.status()["dashboardOpen"])
        self.assertFalse(older.status()["appearanceOpen"])
        self.assert_success(self.dispatch(current, "settings", "--pid", str(older.process.pid),
                                          source=current.base / "nonexistent-package"))
        older.wait_for(lambda state: state["appearanceOpen"])
        self.assertFalse(current.status()["appearanceOpen"])

    def test_same_identity_is_ambiguous_unless_a_pid_is_supplied(self):
        first = self.launch()
        second = self.launch(shared=first, same_identity=True)
        result = self.dispatch(first, "launcher")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertRegex(result.stderr, r"ambiguous|multiple")
        self.assertFalse(first.status()["launcherOpen"])
        self.assertFalse(second.status()["launcherOpen"])
        self.assert_success(self.dispatch(first, "launcher", "--pid", str(second.process.pid)))
        second.wait_for(lambda state: state["launcherOpen"])
        self.assertFalse(first.status()["launcherOpen"])

    def test_missing_wrong_mode_and_unconfigured_commands_do_not_start_a_shell(self):
        shell = self.launch(playground=True)
        for arguments, pattern in [
            (("launcher",), r"no.*instance|not running"),
            (("launcher", "--pid", str(shell.process.pid)), r"desktop|mode|controller"),
            (("launcher", "--pid", "2147483647"), r"not running|no.*instance"),
            (("session",), r"unconfigured.*007|007.*unconfigured"),
            (("lock",), r"unconfigured.*007|007.*unconfigured"),
            (("quit",), r"action|usage"),
        ]:
            result = self.dispatch(shell, *arguments)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertRegex(result.stderr, pattern)
        self.assertTrue(shell.status()["visible"])
        self.assertIsNone(shell.process.poll())

    def test_empty_runtime_has_no_instance_and_dispatch_does_not_create_one(self):
        shell = PidShell()
        self.addCleanup(shell.close)
        prepare_desktop(shell)
        result = self.dispatch(shell, "launcher")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertRegex(result.stderr, r"no.*instance|not running")
        discovery = subprocess.run([QS, "list", "--all", "--json"], env=shell.env,
                                   capture_output=True, text=True, check=True)
        self.assertEqual(discovery.stdout.strip(), "No running instances.")

    def test_real_controller_returns_false_without_screens_and_dispatch_reports_it(self):
        shell = self.launch(no_screens=True)
        self.assertEqual(shell.status()["screenCount"], 0)
        for action in ("launcher", "dashboard", "settings"):
            self.assertEqual(shell.call(action), "false", "Transport success is not action success")
            result = self.dispatch(shell, action)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertRegex(result.stderr, r"screen|rejected")

    def test_foreign_ipc_target_with_an_action_does_not_count_as_a_desktop_controller(self):
        shell = PidShell()
        self.addCleanup(shell.close)
        shell.entry = shell.source / "Foreign.qml"
        shell.entry.write_text('''import Quickshell
import Quickshell.Io
ShellRoot {
    property int calls: 0
    IpcHandler {
        target: "senntisten"
        function status(): string { return JSON.stringify({ mode: "desktop", ready: true, calls: calls }); }
        function launcher(): bool { calls++; return true; }
    }
}
''')
        shell.start()
        result = self.dispatch(shell, "launcher", "--pid", str(shell.process.pid))
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertRegex(result.stderr, r"foreign|controller")
        self.assertEqual(shell.status()["calls"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
