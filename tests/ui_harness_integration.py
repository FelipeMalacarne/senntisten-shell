"""Behavioral contract for agent-driven, real-QML inspection, never a live display."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from integration import ROOT


class UiHarnessIntegration(unittest.TestCase):
    def run_scene(self, scene, actions=(), *options):
        temporary = tempfile.TemporaryDirectory(prefix="senntisten-inspect-test-")
        self.addCleanup(temporary.cleanup)
        base = Path(temporary.name)
        script = base / "actions.json"
        script.write_text(json.dumps(list(actions)))
        output = base / "evidence"
        env = os.environ.copy()
        # Deliberately hostile inherited values must not escape the sandbox.
        env.update({"WAYLAND_DISPLAY": "do-not-connect", "DISPLAY": ":invalid",
                    "SENNTISTEN_STATE_DIR": str(base / "live-state"),
                    "QT_QPA_PLATFORM": "wayland"})
        process = subprocess.run(
            [sys.executable, str(ROOT / "tests/ui_harness.py"), "--scene", scene,
             "--actions", str(script), "--output", str(output), *options],
            env=env, capture_output=True, text=True, timeout=45,
        )
        self.assertFalse((base / "live-state").exists(), "Never use inherited state")
        return process, output

    def snapshot(self, output, index, operation):
        return json.loads((output / f"{index:03}-{operation}.json").read_text())

    def control(self, snapshot, name):
        matches = [control for control in snapshot["controls"] if control["objectName"] == name]
        self.assertEqual(len(matches), 1, name)
        return matches[0]

    def test_launcher_keyboard_mouse_and_safe_native_execution(self):
        process, output = self.run_scene("launcher", [
            {"op": "type", "target": "launcherSearch", "text": "journal"},
            {"op": "expect", "target": "launcherCount", "property": "text", "value": "1 match"},
            {"op": "key", "key": "Tab"},
            {"op": "key", "key": "Return"},
            {"op": "reset"},
            {"op": "type", "target": "launcherSearch", "text": "Alpha"},
            {"op": "click", "target": "Alpha Browser, Web Browser"},
        ])
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        initial = self.snapshot(output, 0, "initial")
        self.assertTrue(self.control(initial, "launcherSearch")["activeFocus"])
        typed = self.snapshot(output, 1, "type")
        self.assertEqual(self.control(typed, "launcherSearch")["text"], "journal")
        tabbed = self.snapshot(output, 3, "key")
        self.assertTrue(any(item["activeFocus"] and item.get("text") == "Beta Notes"
                            for item in tabbed["controls"]))
        launches = json.loads((output / "launches.json").read_text())
        self.assertEqual([launch["id"] for launch in launches], ["beta", "alpha"])
        manifest = json.loads((output / "manifest.json").read_text())
        self.assertTrue(manifest["success"])
        self.assertEqual(len(manifest["images"]), 8)
        self.assertTrue((output / "index.html").is_file())

    def test_settings_pointer_and_keyboard_changes_persist_in_isolated_state(self):
        process, output = self.run_scene("settings", [
            {"op": "click", "target": "theme-gruvbox"},
            {"op": "expect", "target": "theme-gruvbox", "property": "selected", "value": True},
            {"op": "focus", "target": "reducedMotionSwitch"},
            {"op": "key", "key": "Space"},
        ])
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        final = self.snapshot(output, 4, "key")
        self.assertEqual(final["theme"], "gruvbox")
        self.assertTrue(final["reducedMotion"])
        self.assertEqual(json.loads((output / "appearance.json").read_text()), {
            "schemaVersion": 1, "theme": "gruvbox", "reducedMotion": True,
        })

    def test_controls_drag_and_connectivity_disclosure_are_observable(self):
        process, output = self.run_scene("controls", [
            {"op": "drag", "target": "audioVolume", "fromX": 0.3, "toX": 0.75},
            {"op": "click", "target": "audioMute"},
            {"op": "expect", "target": "audioMute", "property": "text", "value": "Unmute"},
            {"op": "click", "target": "quickNetwork"},
            {"op": "expect", "target": "quickNetworkDetails", "property": "visible", "value": True},
        ])
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        final = self.snapshot(output, 5, "expect")
        self.assertTrue(self.control(final, "quickNetworkDetails")["visible"])
        dragged = self.snapshot(output, 1, "drag")
        self.assertGreater(self.control(dragged, "audioVolume")["value"], 0.6)

    def test_disabled_target_failures_are_observable(self):
        process, output = self.run_scene("controls", [
            {"op": "click", "target": "audioMute"},
        ], "--unavailable")
        self.assertNotEqual(process.returncode, 0, process.stdout + process.stderr)
        final = self.snapshot(output, 1, "click")
        self.assertIn("disabled", final["error"].lower())
        self.assertTrue((output / "001-click.png").is_file(), "Keep failure screenshot")
        self.assertFalse(json.loads((output / "manifest.json").read_text())["success"])

    def test_bar_fixture_signals_and_narrow_geometry(self):
        process, output = self.run_scene("bar", [
            {"op": "click", "target": "barLauncher"},
            {"op": "click", "target": "workspace-2"},
            {"op": "resize", "width": 360, "height": 44},
            {"op": "wheel", "target": "barWorkspaceViewport", "dy": -120},
        ])
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        final = self.snapshot(output, 4, "wheel")
        self.assertEqual(final["events"]["launcher"], 1)
        self.assertEqual(final["events"]["workspace"], 2)
        self.assertEqual(final["viewport"], {"width": 360, "height": 44})
        self.assertTrue(self.control(final, "barAppearance")["inViewport"])

    def test_unknown_target_and_wrong_expectation_fail_with_evidence(self):
        for action in (
            {"op": "click", "target": "missing-control"},
            {"op": "expect", "target": "launcherCount", "property": "text", "value": "not true"},
        ):
            with self.subTest(action=action):
                process, output = self.run_scene("launcher", [action])
                self.assertNotEqual(process.returncode, 0)
                snapshot = self.snapshot(output, 1, action["op"])
                self.assertTrue(snapshot["error"])
                self.assertTrue((output / "quickshell.log").is_file())

    def test_clipped_controls_are_not_silently_force_clicked(self):
        process, output = self.run_scene("settings", [
            {"op": "click", "target": "reducedMotionSwitch"},
        ], "--width", "320", "--height", "360")
        self.assertNotEqual(process.returncode, 0)
        snapshot = self.snapshot(output, 1, "click")
        self.assertIn("clipped", snapshot["error"].lower())

    def test_unavailable_and_empty_catalog_are_explicit_visual_states(self):
        process, output = self.run_scene("controls", [], "--unavailable")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        snapshot = self.snapshot(output, 0, "initial")
        self.assertFalse(self.control(snapshot, "audioVolume")["enabled"])
        self.assertEqual(self.control(snapshot, "audioVolume")["value"], 0)
        self.assertEqual(self.control(snapshot, "audioStatus")["text"], "PipeWire unavailable")
        self.assertFalse(self.control(snapshot, "microphoneVolume")["enabled"])
        self.assertEqual(self.control(snapshot, "microphoneVolume")["value"], 0)
        self.assertEqual(self.control(snapshot, "microphoneMute")["text"], "Mute microphone")
        process, output = self.run_scene("launcher", [], "--empty-catalog")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        snapshot = self.snapshot(output, 0, "initial")
        self.assertEqual(self.control(snapshot, "launcherEmpty")["text"], "No applications found")

    def test_query_text_that_looks_like_diagnostics_is_not_a_runtime_error(self):
        process, output = self.run_scene("launcher", [
            {"op": "type", "target": "launcherSearch", "text": "TypeError ERROR:"},
        ])
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        self.assertTrue(json.loads((output / "manifest.json").read_text())["success"])

    def test_controls_use_the_production_panel_size_not_a_stretched_window(self):
        process, output = self.run_scene("controls", [], "--height", "1200")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        snapshot = self.snapshot(output, 0, "initial")
        panel = snapshot["controls"][0]["geometry"]
        self.assertEqual((panel["x"], panel["y"], panel["width"]), (20, 20, 300))
        self.assertLess(panel["height"], snapshot["viewport"]["height"] - 40)
        process, output = self.run_scene("controls", [], "--width", "340", "--height", "320")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        snapshot = self.snapshot(output, 0, "initial")
        self.assertEqual(snapshot["controls"][0]["geometry"]["height"], 280)
        self.assertFalse(self.control(snapshot, "quickSettings")["inViewport"])

    def test_save_failure_is_injected_after_load_and_remains_visible(self):
        process, output = self.run_scene("settings", [
            {"op": "click", "target": "theme-gruvbox"},
            {"op": "resize", "width": 320, "height": 360},
        ], "--state", "save-failure")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        final = self.snapshot(output, 2, "resize")
        self.assertEqual(final["saveStatus"], "error")
        self.assertIn("Could not save", final["message"])
        self.assertTrue(self.control(final, "themeSaveStatus")["inViewport"])

    def test_documented_replays_remain_runnable(self):
        for scene, replay in (("launcher", "launcher"), ("settings", "settings"),
                              ("controls", "controls"), ("controls", "connectivity"),
                              ("bar", "bar")):
            with self.subTest(scene=scene, replay=replay):
                actions = json.loads((ROOT / f"tests/ui-actions/{replay}.json").read_text())
                process, _ = self.run_scene(scene, actions)
                self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        actions = json.loads((ROOT / "tests/ui-actions/controls-short.json").read_text())
        process, _ = self.run_scene("controls", actions, "--width", "340", "--height", "320")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)

    def test_missing_executable_retains_a_failure_report(self):
        with mock.patch.dict(os.environ, {"SENNTISTEN_QUICKSHELL": "/no-senntisten-test-executable"}):
            process, output = self.run_scene("launcher")
        self.assertNotEqual(process.returncode, 0)
        self.assertTrue((output / "quickshell.log").is_file())
        self.assertFalse(json.loads((output / "manifest.json").read_text())["success"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
