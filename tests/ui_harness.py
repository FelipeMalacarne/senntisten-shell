"""Replay agent actions against real QML controls in a disposable offscreen scene."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

from integration import QS, ROOT
from launcher_integration import LauncherSandbox
from ui_artifacts import fresh_output, write_report


SCENES = {"bar": (1100, 44), "launcher": (900, 720),
          "controls": (380, 560), "settings": (860, 650)}
OPERATIONS = {"click", "hover", "drag", "wheel", "focus", "type", "key",
              "resize", "expect", "reset", "wait"}


def validate_actions(actions):
    if not isinstance(actions, list) or len(actions) > 100:
        raise ValueError("Actions must be an array of at most 100 objects")
    for action in actions:
        if not isinstance(action, dict) or action.get("op") not in OPERATIONS:
            raise ValueError(f"Unknown action: {action!r}")
        if action["op"] in {"click", "hover", "drag", "wheel", "focus", "type", "expect"}:
            if not isinstance(action.get("target"), str) or not action["target"]:
                raise ValueError("This action requires a nonempty target")
        for key in ("x", "y", "fromX", "fromY", "toX", "toY"):
            if key in action and (type(action[key]) not in (int, float) or not 0 <= action[key] <= 1):
                raise ValueError(f"{key} must be a fraction between 0 and 1")
        if action["op"] == "type" and (not isinstance(action.get("text"), str) or len(action["text"]) > 256):
            raise ValueError("type requires text of at most 256 characters")
        if action["op"] == "key" and not isinstance(action.get("key"), str):
            raise ValueError("key requires a Qt key name, such as Tab or Return")
        if action["op"] == "expect" and (not isinstance(action.get("property"), str) or "value" not in action):
            raise ValueError("expect requires a property and value")
        if action["op"] == "resize":
            validate_size(action.get("width"), action.get("height"))
        for key in ("ms", "dx", "dy"):
            if key in action and (type(action[key]) is not int or abs(action[key]) > 3000):
                raise ValueError(f"{key} must be an integer between -3000 and 3000")
        if action.get("ms", 0) < 0:
            raise ValueError("Wait duration cannot be negative")
    return actions


def validate_size(width, height):
    if type(width) is not int or type(height) is not int or not 160 <= width <= 2560 or not 44 <= height <= 1440:
        raise ValueError("Viewport must be 160..2560 wide and 44..1440 high")


def run_scene(scene, output, actions, width, height, theme, state="normal", reduced_motion=False,
              unavailable=False, empty_catalog=False):
    metadata = {"kind": "inspect", "scene": scene, "success": False,
                "actions": actions, "steps": [], "checks": [],
                "configuration": {"width": width, "height": height, "theme": theme,
                                  "state": state, "reducedMotion": reduced_motion,
                                  "unavailable": unavailable, "emptyCatalog": empty_catalog}}
    sandbox = LauncherSandbox()
    try:
        entry = sandbox.source / "InspectUi.qml"
        shutil.copyfile(ROOT / "tests/inspect-ui.qml", entry)
        if empty_catalog:
            for desktop_entry in sandbox.applications.glob("*.desktop"):
                desktop_entry.unlink()
        state_file = sandbox.base / "state/appearance.json"
        initial = {"schemaVersion": 1, "theme": theme, "reducedMotion": reduced_motion}
        if state in ("normal", "save-failure"):
            state_file.write_text(json.dumps(initial))
        elif state == "corrupt":
            state_file.write_text("{incomplete")
        elif state == "newer":
            state_file.write_text(json.dumps({"schemaVersion": 9, "theme": "future", "extra": "keep"}))
        poison = sandbox.base / "poison_state.py"
        poison.write_text("from pathlib import Path\n"
                          f"path = Path({str(state_file)!r})\n"
                          "path.unlink()\npath.mkdir()\n")
        sandbox.env.update({
            "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
            "SENNTISTEN_CAPTURE_DIR": str(output),
            "SENNTISTEN_INSPECT_SCENE": scene,
            "SENNTISTEN_INSPECT_ACTIONS": json.dumps(actions, separators=(",", ":")),
            "SENNTISTEN_INSPECT_WIDTH": str(width), "SENNTISTEN_INSPECT_HEIGHT": str(height),
            "SENNTISTEN_INSPECT_UNAVAILABLE": "1" if unavailable else "0",
            "SENNTISTEN_INSPECT_EMPTY": "1" if empty_catalog else "0",
            "SENNTISTEN_INSPECT_POISON": str(poison) if state == "save-failure" else "",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(sandbox.base / "no-session-bus"),
            "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(sandbox.base / "no-system-bus"),
            "PIPEWIRE_REMOTE": str(sandbox.base / "no-pipewire"),
        })
        for name in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
                     "HYPRLAND_CMD", "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"):
            sandbox.env.pop(name, None)
        command = [QS, "--no-color", "--path", str(entry)]
        try:
            process = subprocess.run(command, env=sandbox.env, capture_output=True, text=True,
                                     timeout=30 + len(actions) * 4)
            log = process.stdout + process.stderr
            returncode = process.returncode
        except subprocess.TimeoutExpired as error:
            log = "".join(part.decode(errors="replace") if isinstance(part, bytes) else part or ""
                          for part in (error.stdout, error.stderr)) + "\nInspection timed out\n"
            returncode = 124
        except OSError as error:
            log = f"Cannot start Quickshell: {error}\n"
            returncode = 127
        (output / "quickshell.log").write_text(log)
        for match in re.finditer(r"SENNTISTEN_INSPECT_STEP (\{[^\n]*\})", log):
            snapshot = json.loads(match.group(1))
            name = snapshot["artifact"]
            (output / (name + ".json")).write_text(json.dumps(snapshot, indent=2) + "\n")
            metadata["steps"].append({"snapshot": name + ".json", "image": snapshot.get("image"),
                                      "action": snapshot["action"], "error": snapshot["error"]})
        results = re.findall(r"SENNTISTEN_INSPECT_RESULT (\{[^\n]*\})", log)
        result = json.loads(results[0]) if len(results) == 1 else {}
        diagnostics = "\n".join(line for line in log.splitlines() if "SENNTISTEN_INSPECT_" not in line)
        metadata["success"] = (returncode == 0 and result.get("failed") == 0
                               and result.get("skipped") == 0 and result.get("passed", 0) > 0
                               and len(metadata["steps"]) == len(actions) + 1
                               and not any(step["error"] for step in metadata["steps"])
                               and not re.search(r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:", diagnostics))
        for step in metadata["steps"]:
            if step["image"] and not (output / step["image"]).is_file():
                metadata["success"] = False
        if state_file.is_file():
            shutil.copyfile(state_file, output / "appearance.json")
        launches = [json.loads(line) for line in sandbox.marker.read_text().splitlines()] if sandbox.marker.exists() else []
        (output / "launches.json").write_text(json.dumps(launches, indent=2) + "\n")
        metadata["checks"].append({"name": "QtTest action replay", "returncode": returncode,
                                    "log": "quickshell.log", "result": result})
    finally:
        sandbox.close()
    return write_report(output, metadata)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", choices=SCENES, default="launcher")
    parser.add_argument("--actions", type=Path, help="JSON array of QtTest actions; omitted means capture initial state")
    parser.add_argument("--output", type=Path, help="Fresh artifact directory; existing directories are refused")
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--theme", choices=("catppuccin-mocha", "gruvbox"), default="catppuccin-mocha")
    parser.add_argument("--state", choices=("normal", "missing", "corrupt", "newer", "save-failure"), default="normal")
    parser.add_argument("--reduced-motion", action="store_true")
    parser.add_argument("--unavailable", action="store_true", help="Unavailable audio/compositor fixture")
    parser.add_argument("--empty-catalog", action="store_true", help="No launcher desktop entries")
    args = parser.parse_args()
    output = None
    try:
        if not QS:
            raise ValueError("Quickshell is required; run inside nix develop")
        actions = validate_actions(json.loads(args.actions.read_text()) if args.actions else [])
        default_width, default_height = SCENES[args.scene]
        width = args.width if args.width is not None else default_width
        height = args.height if args.height is not None else default_height
        validate_size(width, height)
        output = fresh_output(args.output)
        manifest = run_scene(args.scene, output, actions, width, height, args.theme, args.state,
                             args.reduced_motion, args.unavailable, args.empty_catalog)
    except (ValueError, OSError) as error:
        report = f"Report directory: {output}\n" if output else ""
        parser.exit(2, f"{error}\n{report}")
    print(f"{'PASS' if manifest['success'] else 'FAIL'}: {output / 'index.html'}")
    return 0 if manifest["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
