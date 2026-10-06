"""Opt-in real Wayland bar actions, using disposable state and provider endpoints.

Run explicitly inside nix develop with a Wayland display. This briefly creates
its own no-reservation preview surfaces; it never restarts an existing shell.
SENNTISTEN_WAYLAND_TEST_APPROVED=1 requires explicit approval for that display.
"""
import json
import os
from pathlib import Path
import re
import shutil
import socket
import struct
import subprocess
import time
import unittest
from unittest.mock import patch

from integration import ROOT, QS, RunningShell


class VirtualPointer:
    """Drive the compositor's standard virtual pointer without extra dependencies."""
    def __init__(self, display):
        self.connection = socket.socket(socket.AF_UNIX)
        self.connection.settimeout(3)
        self.connection.connect(str(display))
        self.buffer = b""
        self.next_id = 2
        self.globals = {}
        self.send(1, 1, struct.pack("=I", 2))
        self.roundtrip()
        name, version = self.globals["zwlr_virtual_pointer_manager_v1"]
        self.manager = self.allocate()
        interface = b"zwlr_virtual_pointer_manager_v1\0"
        payload = struct.pack("=II", name, len(interface)) + interface
        payload += b"\0" * (-len(interface) % 4)
        payload += struct.pack("=II", min(version, 1), self.manager)
        self.send(2, 0, payload)
        self.pointer = self.allocate()
        self.send(self.manager, 0, struct.pack("=II", 0, self.pointer))
        self.roundtrip()

    def allocate(self):
        self.next_id += 1
        return self.next_id

    def send(self, object_id, opcode, payload=b""):
        self.connection.sendall(struct.pack("=II", object_id, (8 + len(payload)) << 16 | opcode) + payload)

    def roundtrip(self):
        callback = self.allocate()
        self.send(1, 0, struct.pack("=I", callback))
        while True:
            while len(self.buffer) < 8:
                data = self.connection.recv(65536)
                if not data:
                    raise ConnectionError("Wayland connection closed")
                self.buffer += data
            object_id, header = struct.unpack("=II", self.buffer[:8])
            size, opcode = header >> 16, header & 0xffff
            while len(self.buffer) < size:
                data = self.connection.recv(65536)
                if not data:
                    raise ConnectionError("Wayland connection closed")
                self.buffer += data
            payload, self.buffer = self.buffer[8:size], self.buffer[size:]
            if object_id == 1 and opcode == 0:
                raise RuntimeError("Wayland protocol error: " + repr(payload))
            if object_id == 2 and opcode == 0:
                name, length = struct.unpack("=II", payload[:8])
                interface = payload[8:8 + length - 1].decode()
                version = struct.unpack("=I", payload[8 + (length + 3) // 4 * 4:][:4])[0]
                self.globals[interface] = (name, version)
            if object_id == callback and opcode == 0:
                return

    def move(self, x, y, width, height):
        timestamp = int(time.monotonic() * 1000) & 0xffffffff
        self.send(self.pointer, 1, struct.pack("=IIIII", timestamp, round(x), round(y), width, height))
        self.send(self.pointer, 4)
        self.roundtrip()

    def click(self, x, y, width, height):
        self.move(x, y, width, height)
        timestamp = int(time.monotonic() * 1000) & 0xffffffff
        self.send(self.pointer, 2, struct.pack("=III", timestamp, 272, 1))
        self.send(self.pointer, 4)
        try:
            self.roundtrip()
        finally:
            self.send(self.pointer, 2, struct.pack("=III", timestamp, 272, 0))
            self.send(self.pointer, 4)
            self.roundtrip()

    def close(self):
        self.connection.close()


POINTER_HOST = '''//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "services"
ShellRoot {
    property int frames: 0
    property int launcherClicks: 0
    property int settingsClicks: 0
    Desktop { id: desktop }
    Connections {
        target: desktop.barsUnderTest.instances.length ? desktop.barsUnderTest.instances[0].contentItem.Window.window : null
        function onFrameSwapped() { frames++; }
    }
    Connections {
        target: desktop.barsUnderTest.instances[0] || null
        function onLauncherRequested() { launcherClicks++; }
        function onAppearanceRequested() { settingsClicks++; }
    }
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const match = findItem(child, name);
            if (match) return match;
        }
        return null;
    }
    IpcHandler {
        target: "pointer-test"
        function status(): string {
            const bar = desktop.barsUnderTest.instances[0];
            const buttons = {};
            const buttonStates = {};
            const tooltips = {};
            if (bar) for (const name of ["barLauncher", "barAppearance", "barAudio"]) {
                const item = findItem(bar.contentItem, name);
                const point = item.mapToItem(bar.contentItem, item.width / 2, item.height / 2);
                buttons[name] = [point.x, point.y];
                buttonStates[name] = [item.hovered, item.pressed, item.activeFocus];
                tooltips[name] = false;
                for (const resource of item.resources) {
                    if (resource.objectName.endsWith("Tooltip"))
                        tooltips[name] = resource.visible;
                }
            }
            return JSON.stringify({
                ready: Theme.ready && !!bar && frames > 0, buttons: buttons,
                buttonStates: buttonStates, tooltips: tooltips, launcherClicks: launcherClicks, settingsClicks: settingsClicks,
                launcherOpen: desktop.launcherUnderTest.opened,
                appearanceOpen: desktop.settingsUnderTest.visible,
                dashboardOpen: bar ? bar.dashboardOpen : false
            });
        }
        function dismiss(): void {
            desktop.launcherUnderTest.opened = false;
            desktop.settingsUnderTest.visible = false;
            desktop.closeDashboards();
        }
    }
}
'''


class WaylandSmoke(unittest.TestCase):
    def test_unapproved_display_is_refused_before_startup(self):
        with patch.dict(os.environ, {"SENNTISTEN_WAYLAND_TEST_APPROVED": "0"}):
            with self.assertRaisesRegex(AssertionError, "explicit approval"):
                self.prepare()

    def prepare(self):
        self.assertEqual(os.environ.get("SENNTISTEN_WAYLAND_TEST_APPROVED"), "1",
                         "Native display tests require explicit approval; set SENNTISTEN_WAYLAND_TEST_APPROVED=1 only after approval")
        self.assertTrue(QS, "Run inside nix develop")
        display = os.environ.get("WAYLAND_DISPLAY")
        self.assertTrue(display, "An existing Wayland display is required")
        assert display is not None and QS is not None
        socket = Path(display)
        if not socket.is_absolute():
            socket = Path(os.environ["XDG_RUNTIME_DIR"]) / socket
        self.assertTrue(socket.is_socket(), socket)
        shell = RunningShell()
        self.addCleanup(shell.close)
        shell.env.update({
            "QT_QPA_PLATFORM": "wayland",
            "WAYLAND_DISPLAY": str(socket),
            "SENNTISTEN_PREVIEW": "1",
        })
        # Expose existing objects only in the disposable test copy. Unlike the
        # offscreen controller fixture, retain the real layer/popup wrappers.
        source = shell.source / "Desktop.qml"
        text = source.read_text()
        self.assertEqual(text.count("    id: desktop\n"), 1)
        source.write_text(text.replace("    id: desktop\n", "    id: desktop\n"
            "    readonly property alias barsUnderTest: bars\n"
            "    readonly property alias launcherUnderTest: launcher\n"
            "    readonly property alias settingsUnderTest: appearance\n", 1))
        source = shell.source / "desktop/Bar.qml"
        text = source.read_text()
        self.assertEqual(text.count("    id: root\n"), 1)
        source.write_text(text.replace("    id: root\n", "    id: root\n"
            "    readonly property alias controlsUnderTest: audioPanel\n", 1)
            .replace('"senntisten-bar"', '"senntisten-test-bar"'))
        source = shell.source / "desktop/Launcher.qml"
        source.write_text(source.read_text().replace('"senntisten-launcher"', '"senntisten-test-launcher"'))
        return shell, socket

    def test_native_surface_actions(self):
        shell, _ = self.prepare()
        entry = shell.source / "WaylandSmoke.qml"
        shutil.copyfile(ROOT / "tests/wayland-smoke.qml", entry)
        assert QS is not None
        result = subprocess.run(
            [QS, "--no-color", "--path", str(entry)], env=shell.env,
            capture_output=True, text=True, timeout=35,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        markers = re.findall(r"SENNTISTEN_WAYLAND_RESULT (\{.*\})", output)
        self.assertEqual(len(markers), 1, output)
        summary = json.loads(markers[0])
        expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/wayland-smoke.qml").read_text())
        self.assertEqual(sorted(summary["executed"]), sorted(expected), output)
        self.assertEqual(summary["failed"], 0, output)
        self.assertEqual(summary["skipped"], 0, output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        print(f"  Wayland QtTest: {len(expected)} real surface-action cases passed", flush=True)

    def test_compositor_pointer_opens_launcher_settings_and_controls(self):
        shell, display = self.prepare()
        shell.entry = shell.source / "PointerHost.qml"
        shell.entry.write_text(POINTER_HOST)
        shell.target = "pointer-test"
        shell.start()
        assert shell.process is not None
        pointer = VirtualPointer(display)
        self.addCleanup(pointer.close)
        monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"], text=True))
        self.assertEqual(len(monitors), 1, "Pointer smoke currently requires one monitor")
        monitor = monitors[0]
        self.assertEqual(monitor["scale"], 1, "Pointer smoke currently requires scale 1")
        self.assertEqual((monitor["x"], monitor["y"]), (0, 0), "Pointer smoke currently requires monitor origin 0,0")
        cursor = json.loads(subprocess.check_output(["hyprctl", "-j", "cursorpos"], text=True))
        self.addCleanup(pointer.move, cursor["x"], cursor["y"], monitor["width"], monitor["height"])
        deadline = time.monotonic() + 5
        layer = None
        while time.monotonic() < deadline:
            layers = json.loads(subprocess.check_output(["hyprctl", "-j", "layers"], text=True))
            candidates = [item for screen in layers.values() for level in screen["levels"].values()
                          for item in level if item["pid"] == shell.process.pid
                          and item["namespace"] == "senntisten-test-bar"]
            if candidates:
                layer = candidates[0]
                break
            time.sleep(0.04)
        self.assertIsNotNone(layer, shell.output())
        assert layer is not None
        for long_hover in (False, True):
            for name, key in (("barLauncher", "launcherOpen"), ("barAppearance", "appearanceOpen"),
                              ("barAudio", "dashboardOpen")):
                shell.call("dismiss")
                pointer.move(monitor["width"] / 2, layer["y"] + 22, monitor["width"], monitor["height"])
                x, y = shell.status()["buttons"][name]
                pointer.move(layer["x"] + x, layer["y"] + y, monitor["width"], monitor["height"])
                try:
                    shell.wait_for(lambda state: state["buttonStates"][name][0], timeout=3)
                except AssertionError as error:
                    actual_cursor = json.loads(subprocess.check_output(["hyprctl", "-j", "cursorpos"], text=True))
                    raise AssertionError(f"Compositor did not route the pointer to {name}; target={(layer['x'] + x, layer['y'] + y)}, cursor={actual_cursor}, layer={layer}\n{error}") from error
                if long_hover:
                    shell.wait_for(lambda state: state["tooltips"][name], timeout=2)
                pointer.click(layer["x"] + x, layer["y"] + y, monitor["width"], monitor["height"])
                shell.wait_for(lambda state: state[key], timeout=2)
        shell.call("dismiss")
        self.assertNotRegex(shell.output(), r"ReferenceError|TypeError|Binding loop|Unable to assign")
        print("  Compositor pointer: launcher, Settings, and Quick Controls opened before/after tooltip", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
