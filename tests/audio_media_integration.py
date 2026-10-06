#!/usr/bin/env python3
"""Native audio/media fixtures and unavailable endpoints, never live devices."""
import json
import re
import shutil
import struct
import subprocess
import unittest
import zlib

from integration import QS, ROOT, RunningShell
from ui_artifacts import fresh_output, write_report


class AudioMediaIntegration(unittest.TestCase):
    def test_audio_media_qml(self):
        self.assertTrue(QS, "Run inside nix develop")
        assert QS is not None
        output_dir = fresh_output()
        shell = RunningShell()
        self.addCleanup(shell.close)
        shell.env["DBUS_SYSTEM_BUS_ADDRESS"] = "unix:path=" + str(shell.base / "no-system-bus")
        for key in ("WAYLAND_SOCKET", "XAUTHORITY", "DBUS_STARTER_ADDRESS", "DBUS_STARTER_BUS_TYPE"):
            shell.env.pop(key, None)
        shell.env["SENNTISTEN_CAPTURE_DIR"] = str(output_dir)
        artwork = shell.base / "fixture-artwork.png"
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        pixels = b"".join(b"\x00" + bytes((65, 110, 145, 255)) * 40 for _ in range(40))
        artwork.write_bytes(b"\x89PNG\r\n\x1a\n"
                            + chunk(b"IHDR", struct.pack(">IIBBBBB", 40, 40, 8, 6, 0, 0, 0))
                            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))
        shell.env["SENNTISTEN_ARTWORK_URL"] = artwork.as_uri()
        entry = shell.source / "AudioMediaTest.qml"
        shutil.copyfile(ROOT / "tests/audio-media-ui.qml", entry)
        try:
            proc = subprocess.run(
                [QS, "--no-color", "--path", str(entry)], env=shell.env,
                capture_output=True, text=True, timeout=60,
            )
            output = proc.stdout + proc.stderr
        except subprocess.TimeoutExpired as error:
            output = str(error.stdout) + str(error.stderr)
            (output_dir / "quickshell.log").write_text(output)
            self.fail(f"Audio/media QtTest timed out; evidence: {output_dir}\n{output}")
        (output_dir / "quickshell.log").write_text(output)
        checkpoints = re.findall(r"AUDIO_MEDIA_CHECKPOINT (\{.*\})", output)
        for index, checkpoint in enumerate(checkpoints):
            (output_dir / f"{index:03d}-checkpoint.json").write_text(checkpoint + "\n")
        match = re.search(r"SENNTISTEN_AUDIO_MEDIA_RESULT (\{.*\})", output)
        result = json.loads(match.group(1)) if match else {}
        expected = re.findall(r"function (test_\w+)\(", (ROOT / "tests/audio-media-ui.qml").read_text())
        success = (proc.returncode == 0 and result.get("failed") == 0
                   and result.get("skipped") == 0 and sorted(result.get("executed", [])) == sorted(expected))
        images = [
            {"path": f"audio-media-{theme}-{size}.png", "width": width, "height": height}
            for theme in ("catppuccin-mocha", "gruvbox")
            for size, width, height in (("wide", 380, 740), ("narrow", 300, 740), ("short-focus", 300, 240),
                                        ("unavailable", 300, 740), ("error", 300, 740))
        ]
        images.append({"path": "audio-media-local-artwork.png", "width": 300, "height": 740})
        write_report(output_dir, {"kind": "audio-media QtTest", "success": success,
                                  "result": result, "expected_images": images if success else []})
        print(f"  Audio/media evidence: {output_dir / 'index.html'}", flush=True)
        self.assertEqual(proc.returncode, 0, output)
        self.assertIsNotNone(match, output)
        self.assertEqual(result["failed"], 0, output)
        self.assertEqual(result["skipped"], 0, output)
        self.assertEqual(sorted(result["executed"]), sorted(expected), output)
        self.assertNotRegex(output, r"ReferenceError|TypeError|Binding loop|Unable to assign|ERROR:")
        print(f"  Audio/media QtTest: {len(expected)} behavioral cases passed", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
