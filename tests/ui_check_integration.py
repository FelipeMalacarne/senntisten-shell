"""Behavioral tests for UI evidence tooling; no live desktop or duplicate Qt suite."""
from contextlib import redirect_stderr, redirect_stdout
import hashlib
import importlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import zlib


def png(width=2, height=3):
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data)))
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    pixels = (b"\0" + b"\0\0\0" * width) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


class UiArtifactsIntegration(unittest.TestCase):
    def setUp(self):
        self.artifacts = importlib.import_module("ui_artifacts")
        self.temp = tempfile.TemporaryDirectory(prefix="senntisten-artifacts-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)

    def test_existing_output_is_refused_without_touching_old_artifacts(self):
        old = self.base / "old"
        old.mkdir()
        marker = old / "manifest.json"
        marker.write_text("previous run")
        with self.assertRaises(FileExistsError):
            self.artifacts.fresh_output(old)
        self.assertEqual(marker.read_text(), "previous run")
        empty = self.base / "empty"
        empty.mkdir()
        with self.assertRaises(FileExistsError):
            self.artifacts.fresh_output(empty)
        link = self.base / "broken-link"
        link.symlink_to(self.base / "missing")
        with self.assertRaises(FileExistsError):
            self.artifacts.fresh_output(link)

    def test_default_outputs_are_unique_and_explicit_paths_can_have_new_parents(self):
        with mock.patch.object(self.artifacts, "ROOT", self.base):
            first = self.artifacts.fresh_output()
            second = self.artifacts.fresh_output()
        self.assertNotEqual(first, second)
        self.assertEqual(first.parent, self.base / "artifacts/ui")
        self.assertTrue(first.is_dir())
        explicit = self.artifacts.fresh_output(self.base / "new parent/run")
        self.assertTrue(explicit.is_dir())

    def test_report_inventories_native_images_snapshots_and_logs(self):
        output = self.artifacts.fresh_output(self.base / "report")
        data = png()
        (output / "capture.png").write_bytes(data)
        (output / "state.json").write_text('{"focus": "search"}')
        (output / "runner.log").write_text("actual output")
        metadata = {"kind": "inspect", "success": True, "scene": "launcher",
                    "steps": [{"action": "key", "key": "Tab"}]}
        report = self.artifacts.write_report(output, metadata)
        self.assertEqual(report["images"], [{
            "path": "capture.png", "width": 2, "height": 3,
            "sha256": hashlib.sha256(data).hexdigest(),
        }])
        self.assertEqual([item["path"] for item in report["snapshots"]], ["state.json"])
        self.assertEqual([item["path"] for item in report["logs"]], ["runner.log"])
        self.assertEqual(json.loads((output / "manifest.json").read_text()), report)
        self.assertNotIn("images", metadata, "Caller metadata must not be mutated")
        html = (output / "index.html").read_text()
        for text in ("capture.png", "state.json", "runner.log", "Native QML screenshots",
                     "HTML report", "compositor", "GPU"):
            self.assertIn(text, html)
        self.assertNotIn("https://", html)
        self.assertEqual(report["environment"], {"platform": "offscreen", "renderer": "software"})
        self.assertIn("revision", report["git"])
        self.assertIn("tracked_dirty", report["git"])

    def test_html_escapes_metadata_and_encodes_local_artifact_links(self):
        output = self.artifacts.fresh_output(self.base / "escaped")
        name = 'native <img onerror="bad">.png'
        (output / name).write_bytes(png())
        (output / 'log "quoted".log').write_text("log")
        self.artifacts.write_report(output, {
            "kind": "inspect", "success": True, "scene": "<script>bad()</script>",
            "steps": [{"text": '<input onfocus="bad"> & text'}],
        })
        html = (output / "index.html").read_text()
        self.assertNotIn("<script>", html)
        self.assertNotIn('<input onfocus="bad">', html)
        self.assertIn("&lt;script&gt;bad()&lt;/script&gt;", html)
        self.assertIn("native%20%3Cimg%20onerror%3D%22bad%22%3E.png", html)
        self.assertIn("log%20%22quoted%22.log", html)

    def test_corrupt_png_headers_and_nonpositive_sizes_are_rejected_with_failure_report(self):
        valid = png()
        invalid = (
            b"not a PNG", valid[:20], valid[:12] + b"nope" + valid[16:],
            valid[:8] + struct.pack(">I", 12) + valid[12:],
            valid[:16] + struct.pack(">II", 0, 3) + valid[24:],
            valid[:-4], valid[:29] + b"\0\0\0\0" + valid[33:],
        )
        for index, data in enumerate(invalid):
            with self.subTest(index=index):
                output = self.artifacts.fresh_output(self.base / f"bad-{index}")
                (output / "capture.png").write_bytes(data)
                with self.assertRaises(ValueError):
                    self.artifacts.write_report(output, {"kind": "inspect", "success": True})
                report = json.loads((output / "manifest.json").read_text())
                self.assertFalse(report["success"])
                self.assertTrue(report["artifact_errors"])
                self.assertTrue((output / "index.html").exists())

    def test_missing_expected_image_and_wrong_dimensions_are_rejected(self):
        output = self.artifacts.fresh_output(self.base / "missing")
        metadata = {"kind": "check", "success": True, "expected_images": [
            {"path": "required.png", "width": 2, "height": 3},
        ]}
        with self.assertRaisesRegex(ValueError, "required.png"):
            self.artifacts.write_report(output, metadata)
        (output / "required.png").write_bytes(png(1, 3))
        with self.assertRaisesRegex(ValueError, "dimensions"):
            self.artifacts.write_report(output, metadata)

    def test_success_without_images_is_rejected_but_failed_run_can_be_reported(self):
        output = self.artifacts.fresh_output(self.base / "empty-report")
        with self.assertRaises(ValueError):
            self.artifacts.write_report(output, {"kind": "inspect", "success": True})
        report = self.artifacts.write_report(output, {"kind": "inspect", "success": False})
        self.assertFalse(report["success"])
        self.assertEqual(report["images"], [])

    def test_missing_step_capture_is_rejected_even_when_another_image_exists(self):
        output = self.artifacts.fresh_output(self.base / "missing-step")
        (output / "initial.png").write_bytes(png())
        with self.assertRaisesRegex(ValueError, "clicked.png"):
            self.artifacts.write_report(output, {
                "kind": "inspect", "success": True,
                "steps": [{"image": "initial.png"}, {"image": "clicked.png"}],
            })

    def test_old_or_external_capture_symlinks_are_not_native_evidence(self):
        old = self.base / "old.png"
        old.write_bytes(png())
        output = self.artifacts.fresh_output(self.base / "linked")
        (output / "capture.png").symlink_to(old)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.artifacts.write_report(output, {"kind": "inspect", "success": True})

    def test_git_metadata_is_tracked_only_and_environment_is_not_dumped(self):
        output = self.artifacts.fresh_output(self.base / "git-report")
        (output / "capture.png").write_bytes(png())
        with mock.patch.dict(os.environ, {"PRIVATE_TEST_TOKEN": "do-not-record"}), \
                mock.patch.object(self.artifacts.subprocess, "run", side_effect=[
                    subprocess.CompletedProcess([], 0, "abc123\n", ""),
                    subprocess.CompletedProcess([], 0, " M shell/App.qml\n", ""),
                ]) as run:
            report = self.artifacts.write_report(output, {"kind": "check", "success": True})
        self.assertEqual(report["git"], {"revision": "abc123", "tracked_dirty": True})
        self.assertIn("--untracked-files=no", run.call_args_list[1].args[0])
        self.assertNotIn("do-not-record", json.dumps(report))

    def test_git_unavailability_does_not_prevent_report(self):
        output = self.artifacts.fresh_output(self.base / "no-git")
        (output / "capture.png").write_bytes(png())
        with mock.patch.object(self.artifacts.subprocess, "run", side_effect=FileNotFoundError):
            report = self.artifacts.write_report(output, {"kind": "inspect", "success": True})
        self.assertEqual(report["git"], {"revision": None, "tracked_dirty": None})


class UiCheckIntegration(unittest.TestCase):
    def setUp(self):
        self.runner = importlib.import_module("ui_check")
        self.artifacts = importlib.import_module("ui_artifacts")
        self.temp = tempfile.TemporaryDirectory(prefix="senntisten-ui-check-test-")
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / "captures"
        self.enterContext(redirect_stdout(io.StringIO()))
        self.enterContext(redirect_stderr(io.StringIO()))
        git = mock.patch.object(self.artifacts, "_git_state", return_value={
            "revision": "test-revision", "tracked_dirty": False,
        })
        git.start()
        self.addCleanup(git.stop)

    def fake_command(self, returncode=0, captures=True, text="runner stdout\nrunner stderr\n",
                     timeout=False, wrong_size=False, corrupt=False):
        def start(argv, **kwargs):
            self.assertEqual(kwargs["env"]["QT_QPA_PLATFORM"], "offscreen")
            self.assertEqual(kwargs["env"]["QT_QUICK_BACKEND"], "software")
            for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE"):
                self.assertNotIn(key, kwargs["env"])
            self.assertTrue(kwargs["start_new_session"])
            self.assertEqual(kwargs["stderr"], subprocess.STDOUT)
            suite = next(name for name, spec in self.runner.SUITES.items()
                         if spec["tests"][0] in argv)
            if captures:
                directory = Path(kwargs["env"]["SENNTISTEN_CAPTURE_DIR"])
                for image in self.runner.SUITES[suite]["images"]:
                    width = 1 if wrong_size else image["width"]
                    height = image.get("height", image.get("min_height", 1))
                    (directory / image["path"]).write_bytes(b"broken" if corrupt else png(width, height))
            kwargs["stdout"].write(text)
            kwargs["stdout"].flush()
            process = mock.MagicMock()
            process.__enter__.return_value = process
            process.pid = 12345
            process.wait.side_effect = [subprocess.TimeoutExpired(argv, 300), -9] if timeout else None
            process.wait.return_value = returncode
            return process
        return start

    def run_check(self, args, **fake_options):
        with mock.patch.object(self.runner.subprocess, "Popen", side_effect=self.fake_command(**fake_options)) as run:
            result = self.runner.main(["--output", str(self.output), *args])
        return result, run, json.loads((self.output / "manifest.json").read_text())

    def test_subset_invokes_only_selected_methods_and_saves_actual_argv_and_log(self):
        with mock.patch.dict(os.environ, {
            "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "rhi",
            "DISPLAY": ":live", "WAYLAND_DISPLAY": "live", "WAYLAND_SOCKET": "99",
            "HYPRLAND_INSTANCE_SIGNATURE": "live",
        }):
            code, run, report = self.run_check(["--suite", "launcher"])
        self.assertEqual(code, 0)
        self.assertEqual(run.call_count, 1)
        argv = run.call_args.args[0]
        self.assertIn("launcher_integration.LauncherIntegration.test_real_launcher_controls", argv)
        check = report["checks"][0]
        self.assertEqual(check["argv"], argv)
        self.assertEqual(check["status"], "passed")
        self.assertEqual(check["returncode"], 0)
        self.assertEqual((self.output / check["log"]).read_text(), "runner stdout\nrunner stderr\n")
        self.assertEqual(check["qt_results"], [], "Hidden QML result markers must not be invented")
        self.assertEqual(len(report["images"]), 2)

    def test_repeated_suite_filters_are_deduplicated_and_default_runs_all(self):
        code, run, report = self.run_check(["--suite", "bar", "--suite", "bar", "--suite", "controls"])
        self.assertEqual(code, 0)
        self.assertEqual(run.call_count, 2)
        self.assertEqual([check["name"] for check in report["checks"]], ["bar", "controls"])
        self.output = self.output.parent / "all"
        code, run, report = self.run_check([])
        self.assertEqual(code, 0)
        self.assertEqual(run.call_count, 5)
        self.assertEqual({check["name"] for check in report["checks"]},
                         {"bar", "launcher", "controls", "settings", "playground"})

    def test_settings_selection_includes_save_failure_newer_schema_and_corrupt_state(self):
        code, run, report = self.run_check(["--suite", "settings"])
        self.assertEqual(code, 0)
        argv = run.call_args.args[0]
        for method in ("test_real_settings_controls_and_rendered_layout",
                       "test_failed_save_is_visible_wrapped_and_can_be_retried",
                       "test_newer_schema_disables_preferences_and_is_never_overwritten",
                       "test_corrupt_state_is_visible_and_only_explicit_changes_replace_it",
                       "test_preferences_survive_restart_and_window_close_does_not_quit"):
            self.assertIn("settings_integration.SettingsIntegration." + method, argv)
        self.assertIn("settings-save-failure-narrow.png", [image["path"] for image in report["images"]])
        self.assertIn("settings-newer-schema-narrow.png", [image["path"] for image in report["images"]])

    def test_missing_expected_capture_fails_even_when_tests_pass(self):
        code, _, report = self.run_check(["--suite", "launcher"], captures=False)
        self.assertNotEqual(code, 0)
        self.assertFalse(report["success"])
        self.assertTrue(any("launcher-catppuccin-mocha.png" in error for error in report["artifact_errors"]))
        self.assertTrue((self.output / "index.html").exists())

    def test_wrong_dimensions_fail_even_when_tests_pass(self):
        code, _, report = self.run_check(["--suite", "launcher"], wrong_size=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(report["success"])
        self.assertTrue(any("dimensions" in error for error in report["artifact_errors"]))

    def test_failing_command_with_valid_captures_still_fails_and_continues(self):
        code, run, report = self.run_check(["--suite", "launcher", "--suite", "bar"], returncode=7)
        self.assertNotEqual(code, 0)
        self.assertEqual(run.call_count, 2)
        self.assertFalse(report["success"])
        self.assertTrue(report["images"])
        self.assertEqual(report["checks"][0]["returncode"], 7)
        self.assertEqual(report["checks"][0]["status"], "failed")

    def test_failing_command_and_corrupt_capture_both_remain_in_failure_report(self):
        code, _, report = self.run_check(["--suite", "launcher"], returncode=7, corrupt=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(report["success"])
        self.assertEqual(report["checks"][0]["returncode"], 7)
        self.assertEqual(report["checks"][0]["status"], "failed")
        self.assertTrue(any("invalid PNG" in error for error in report["artifact_errors"]))

    def test_timeout_retains_logs_and_captures_but_fails_and_kills_the_process_group(self):
        with mock.patch.object(self.runner.os, "killpg") as kill:
            code, _, report = self.run_check(["--suite", "bar"], timeout=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(report["success"])
        self.assertEqual(report["checks"][0]["status"], "timeout")
        kill.assert_called_once()
        self.assertIn("runner stdout", (self.output / "bar.log").read_text())

    def test_command_launch_error_and_screenshot_error_do_not_hide_runner_failure(self):
        with mock.patch.object(self.runner.subprocess, "Popen", side_effect=OSError("cannot execute")):
            code = self.runner.main(["--output", str(self.output), "--suite", "bar"])
        self.assertNotEqual(code, 0)
        report = json.loads((self.output / "manifest.json").read_text())
        self.assertEqual(report["checks"][0]["status"], "error")
        self.assertIsNone(report["checks"][0]["returncode"])
        self.assertTrue(report["artifact_errors"])
        self.assertIn("cannot execute", (self.output / "bar.log").read_text())

    def test_qt_markers_are_parsed_only_from_observed_output(self):
        marker = {"passed": 4, "failed": 0, "skipped": 0, "executed": ["test_real"]}
        code, _, report = self.run_check(["--suite", "bar"], text=(
            "qml: SENNTISTEN_BAR_RESULT " + json.dumps(marker) + "\n"))
        self.assertEqual(code, 0)
        observed = report["checks"][0]["qt_results"]
        self.assertEqual(len(observed), 1)
        self.assertEqual(observed[0]["marker"], "SENNTISTEN_BAR_RESULT")
        self.assertEqual(observed[0]["result"], marker)
        self.assertEqual(observed[0]["log"], "bar.log")

    def test_existing_output_and_invalid_suite_do_not_start_commands(self):
        self.output.mkdir()
        (self.output / "keep").write_text("old run")
        with mock.patch.object(self.runner.subprocess, "Popen") as run:
            self.assertNotEqual(self.runner.main(["--output", str(self.output), "--suite", "bar"]), 0)
            with self.assertRaises(SystemExit) as error:
                self.runner.main(["--suite", "desktop"])
            self.assertEqual(error.exception.code, 2)
        run.assert_not_called()
        self.assertEqual((self.output / "keep").read_text(), "old run")


if __name__ == "__main__":
    unittest.main(verbosity=2)
