#!/usr/bin/env python3
"""Run existing native UI checks and collect fresh, offscreen/software evidence."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from ui_artifacts import ROOT, fresh_output, write_report

# Capture contracts come from the corresponding QML and Python integration tests.
SUITES = {
    "bar": {
        "tests": ["bar_integration.BarIntegration.test_real_bar_controls"],
        "images": [{"path": name, "width": 1100, "height": 44} for name in (
            "bar-catppuccin.png", "bar-populated-default.png", "bar-populated-catppuccin.png",
        )],
    },
    "launcher": {
        "tests": ["launcher_integration.LauncherIntegration.test_real_launcher_controls"],
        "images": [{"path": f"launcher-{theme}.png", "width": 900, "height": 720}
                   for theme in ("catppuccin-mocha", "gruvbox")],
    },
    "controls": {
        "tests": ["quick_controls_integration.QuickControlsIntegration.test_real_quick_controls"],
        # AudioPanel has an intrinsic, font-dependent height, not the host height.
        "images": [{"path": f"orbit-controls-{theme}.png", "width": 340, "min_height": 341}
                   for theme in ("catppuccin-mocha", "gruvbox")],
    },
    "settings": {
        "tests": ["settings_integration.SettingsIntegration." + method for method in (
            "test_real_settings_controls_and_rendered_layout",
            "test_failed_save_is_visible_wrapped_and_can_be_retried",
            "test_newer_schema_disables_preferences_and_is_never_overwritten",
            "test_corrupt_state_is_visible_and_only_explicit_changes_replace_it",
            "test_preferences_survive_restart_and_window_close_does_not_quit",
        )],
        "images": [{"path": f"settings-{name}.png", "width": width, "height": height}
                   for name, width, height in (
                       ("catppuccin-mocha-wide", 860, 650),
                       ("catppuccin-mocha-narrow", 320, 360),
                       ("gruvbox-wide", 860, 650), ("gruvbox-narrow", 320, 360),
                       ("narrow-scrolled", 320, 360),
                       ("save-failure-narrow", 320, 360), ("newer-schema-narrow", 320, 360),
                   )],
    },
    "playground": {
        "tests": ["integration.ShellIntegration.test_real_qml_controls"],
        "images": [{"path": name, "width": width, "height": height}
                   for name, width, height in (
                       ("catppuccin-mocha.png", 1080, 820), ("gruvbox.png", 1080, 820),
                       ("compact.png", 660, 540), ("compact-scrolled.png", 660, 540),
                   )],
    },
}
QT_MARKER = re.compile(
    r"\b(SENNTISTEN_(?:(?:BAR|LAUNCHER_UI|CONTROLS|SETTINGS|UI)_RESULT"
    r"|SETTINGS_QT_EXECUTED)) (\{[^\n]*\})"
)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New evidence directory (must not already exist)")
    parser.add_argument("--suite", choices=SUITES, action="append", help="Repeat to select suites; default: all")
    args = parser.parse_args(argv)
    suites = list(dict.fromkeys(args.suite or SUITES))
    try:
        output = fresh_output(args.output)
    except OSError as error:
        print(f"Cannot create fresh evidence directory: {error}", file=sys.stderr)
        return 1
    env = os.environ.copy()
    env.update({"SENNTISTEN_CAPTURE_DIR": str(output), "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software", "QT_QUICK_CONTROLS_STYLE": "Basic", "NO_COLOR": "1"})
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE",
                "HYPRLAND_CMD", "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS",
                "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST", "PYTHONPATH"):
        env.pop(key, None)
    checks = []
    for suite in suites:
        command = [sys.executable, "-m", "unittest", "-v", *SUITES[suite]["tests"]]
        check = {"name": suite, "argv": command, "cwd": str(ROOT / "tests"),
                 "returncode": None, "status": "error", "log": f"{suite}.log", "qt_results": []}
        started = time.monotonic()
        with (output / check["log"]).open("w", encoding="utf-8") as log:
            try:
                with subprocess.Popen(
                    command, cwd=ROOT / "tests", env=env, stdout=log, stderr=subprocess.STDOUT,
                    start_new_session=True,
                ) as process:
                    try:
                        check["returncode"] = process.wait(timeout=300)
                        check["status"] = "passed" if check["returncode"] == 0 else "failed"
                    except subprocess.TimeoutExpired:
                        # Kill Qt children too; never leave an orphaned test shell.
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        check["returncode"] = process.wait()
                        check["status"] = "timeout"
                        log.write("\nEvidence runner timed out after 300 seconds.\n")
            except OSError as error:
                log.write(f"\nEvidence runner could not execute command: {error}\n")
        check["duration_seconds"] = round(time.monotonic() - started, 3)
        # Some successful Python tests keep their QML stdout private. Record only
        # markers actually visible in saved logs, never inferred Qt case counts.
        for path in sorted(output.glob(f"{suite}*.log")):
            for match in QT_MARKER.finditer(path.read_text(encoding="utf-8", errors="replace")):
                try:
                    result = json.loads(match[2])
                except ValueError:
                    continue
                check["qt_results"].append({"marker": match[1], "result": result, "log": path.name})
        checks.append(check)
        print(f"{suite}: {check['status']} (log: {output / check['log']})", flush=True)
    metadata = {
        "kind": "check", "success": all(check["status"] == "passed" for check in checks),
        "suites": suites, "checks": checks,
        "expected_images": [image for suite in suites for image in SUITES[suite]["images"]],
    }
    try:
        report = write_report(output, metadata)
    except (OSError, ValueError) as error:
        print(f"Evidence validation/report failed: {error}\nReport directory: {output}", file=sys.stderr)
        return 1
    print(f"Report: {output / 'index.html'}", flush=True)
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
