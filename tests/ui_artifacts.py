"""Local evidence reports for native, offscreen/software Quickshell captures."""
from datetime import datetime, timezone
import hashlib
from html import escape
import json
from pathlib import Path
import struct
import subprocess
from urllib.parse import quote
from uuid import uuid4
import zlib

ROOT = Path(__file__).resolve().parents[1]


def fresh_output(path=None) -> Path:
    """Exclusively create an output directory; never reuse even an empty one."""
    if path is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        path = ROOT / "artifacts/ui" / f"{stamp}-{uuid4().hex[:8]}"
    output = Path(path).expanduser()
    # Resolve only after mkdir so existing (including dangling) symlinks fail.
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    return output.resolve()


def _git_state():
    try:
        revision = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
            text=True, check=True, timeout=5,
        ).stdout.strip()
        status = subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT,
            capture_output=True, text=True, check=True, timeout=5,
        ).stdout.strip()
        return {"revision": revision, "tracked_dirty": bool(status)}
    except (OSError, subprocess.SubprocessError):
        return {"revision": None, "tracked_dirty": None}


def _png_info(path):
    data = path.read_bytes()
    if len(data) < 33 or data[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR":
        raise ValueError("invalid PNG signature or IHDR")
    width, height = struct.unpack(">II", data[16:24])
    if width == 0 or height == 0:
        raise ValueError("PNG dimensions must be positive")
    offset = 8
    has_pixels = False
    # Check chunk boundaries and CRCs too, so a truncated capture is not evidence.
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            raise ValueError("truncated PNG chunk")
        crc = struct.unpack(">I", data[end - 4:end])[0]
        if zlib.crc32(data[offset + 4:end - 4]) != crc:
            raise ValueError("invalid PNG chunk CRC")
        if kind == b"IDAT" and size:
            has_pixels = True
        if kind == b"IEND":
            if size or end != len(data) or not has_pixels:
                raise ValueError("invalid PNG end or missing image data")
            return {"path": path.name, "width": width, "height": height,
                    "sha256": hashlib.sha256(data).hexdigest()}
        offset = end
    raise ValueError("missing or truncated PNG end")


def write_report(output: Path, metadata: dict) -> dict:
    """Write a static report, then raise ValueError if capture validation fails.

    Optional expected_images entries specify path, width, height (or min_height
    for intrinsically sized controls). steps[].image references must exist too.
    Failed runs without captures can still
    have reports. A successful run must contain at least one valid screenshot.
    Reserved inventory/provenance fields are generated here, not by callers.
    """
    output = Path(output)
    manifest = dict(metadata)
    images = []
    errors = []
    for path in sorted(output.glob("*.png")):
        try:
            if path.is_symlink():
                raise ValueError("capture must not be a symlink to an old or external artifact")
            images.append(_png_info(path))
        except (OSError, ValueError) as error:
            errors.append(f"{path.name}: {error}")
    by_name = {image["path"]: image for image in images}
    for step in metadata.get("steps", []):
        if step.get("image") and step["image"] not in by_name:
            errors.append(f"Missing valid step screenshot: {step['image']}")
    for expected in metadata.get("expected_images", []):
        image = by_name.get(expected["path"])
        if image is None:
            errors.append(f"Missing valid expected screenshot: {expected['path']}")
            continue
        if (image["width"] != expected["width"]
                or ("height" in expected and image["height"] != expected["height"])
                or ("min_height" in expected and image["height"] < expected["min_height"])):
            errors.append(f"{expected['path']}: unexpected dimensions "
                          f"{image['width']}x{image['height']}; expected {expected}")
    if metadata.get("success") and not images and not errors:
        errors.append("No native QML screenshots found")
    manifest.update({
        "success": bool(metadata.get("success")) and not errors,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "git": _git_state(),
        "environment": {"platform": "offscreen", "renderer": "software"},
        "images": images,
        "snapshots": [{"path": path.name} for path in sorted(output.glob("*.json"))
                      if path.name != "manifest.json" and path.is_file() and not path.is_symlink()],
        "logs": [{"path": path.name} for path in sorted(output.glob("*.log"))
                 if path.is_file() and not path.is_symlink()],
        "artifact_errors": errors,
        "evidence_scope": "Native QML screenshots rendered offscreen with software Qt. "
                          "The HTML report is an evidence viewer, not the shell UI. "
                          "No compositor or GPU behavior is proven.",
    })
    text = json.dumps(manifest, indent=2, ensure_ascii=True) + "\n"
    (output / "manifest.json").write_text(text, encoding="utf-8")
    html = [
        '<!doctype html><html lang="en"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '<title>Quickshell UI Evidence</title><style>',
        'body{font:16px/1.5 system-ui,sans-serif;margin:0 auto;padding:24px;max-width:1100px;'
        'background:#f5f5f5;color:#202020}a{color:#17499b}h1,h2{line-height:1.2}'
        'figure{margin:24px 0;padding:16px;background:white;border:1px solid #ccc}'
        'img{display:block;max-width:100%;height:auto}figcaption{overflow-wrap:anywhere}'
        'pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:16px;background:white}'
        'li{overflow-wrap:anywhere}',
        '</style></head><body><h1>Quickshell UI Evidence</h1>',
        f"<p><strong>{'PASS' if manifest['success'] else 'FAIL'}</strong> "
        f"{escape(str(metadata.get('kind', '')))} {escape(str(metadata.get('scene', '')))}</p>",
        '<p>' + escape(manifest["evidence_scope"]) + '</p>',
        '<p><a href="manifest.json">Machine-readable manifest</a></p>',
        '<h2>Native QML screenshots</h2>',
    ]
    for image in images:
        url = escape(quote(image["path"], safe=""), quote=True)
        label = escape(image["path"], quote=True)
        html.append(f'<figure><a href="{url}"><img src="{url}" alt="Native QML capture: {label}" '
                    f'width="{image["width"]}" height="{image["height"]}"></a>'
                    f'<figcaption>{label} ({image["width"]} x {image["height"]})</figcaption></figure>')
    for title, entries in (("Logs", manifest["logs"]), ("Snapshot JSON", manifest["snapshots"])):
        html.append(f"<h2>{title}</h2><ul>")
        for entry in entries:
            url = escape(quote(entry["path"], safe=""), quote=True)
            html.append(f'<li><a href="{url}">{escape(entry["path"])}</a></li>')
        html.append("</ul>")
    html.extend(["<h2>Run Metadata</h2><pre>" + escape(text) + "</pre>", "</body></html>"])
    (output / "index.html").write_text("\n".join(html) + "\n", encoding="utf-8")
    if errors:
        raise ValueError("; ".join(errors))
    return manifest
