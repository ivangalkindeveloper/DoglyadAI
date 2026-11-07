"""Prepare a local Figma plugin with its required manifest.json filename."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shutil

TEST = Path(__file__).resolve().parents[1]
SHA256_MARKER = "/* DOGlyad_SHA256_BUNDLE */"
KEY_MARKER = "/* DOGlyad_BRIDGE_KEY */"


def bridge_key(root: Path = TEST) -> str:
    """Keep local authentication stable across runs, without manual token entry."""
    path = root / "secrets/figma-bridge-key"
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        pass
    else:
        with os.fdopen(descriptor, "w") as output:
            output.write(secrets.token_urlsafe(32) + "\n")
    path.chmod(0o600)
    key = path.read_text().strip()
    if not re.fullmatch(r"[A-Za-z0-9_-]{43}", key):
        raise ValueError(
            "Invalid test/secrets/figma-bridge-key; regenerate the local plugin"
        )
    return key


def bundled_ui(source: Path, key: str) -> str:
    ui = (source / "ui.html").read_text()
    if ui.count(SHA256_MARKER) != 1:
        raise ValueError("Figma UI must contain exactly one SHA-256 bundle marker")
    if ui.count(KEY_MARKER) != 1:
        raise ValueError("Figma UI must contain exactly one local bridge key marker")
    vendor = source / "vendor/js-sha256"
    license_text = (vendor / "LICENSE.txt").read_text()
    library = "/*\n" + license_text + "\n*/\n" + (vendor / "sha256.js").read_text()
    if "</script" in library.lower():
        raise ValueError("SHA-256 source cannot close its enclosing script element")
    return ui.replace(SHA256_MARKER, library).replace(KEY_MARKER, json.dumps(key))


def configure(plugin_id: str | None = None, root: Path = TEST) -> Path:
    source = root / "figma"
    destination = root / "cache/figma-plugin"
    output = destination / "manifest.json"
    if plugin_id is None:
        for saved in (output, source / "manifest.local.json"):
            if saved.exists():
                plugin_id = json.loads(saved.read_text()).get("id")
                if plugin_id:
                    break
    if not isinstance(plugin_id, str) or not plugin_id.isdecimal():
        raise ValueError(
            "Run python3 test/scripts/configure_figma.py <numeric Figma plugin ID> first"
        )
    data = json.loads((source / "manifest.json").read_text())
    data["id"] = plugin_id
    destination.mkdir(parents=True, exist_ok=True)
    ui = bundled_ui(source, bridge_key(root))
    shutil.copyfile(source / "code.js", destination / "code.js")
    (destination / "ui.html").write_text(ui)
    (destination / "ui.html").chmod(0o600)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin_id", nargs="?")
    args = parser.parse_args()
    try:
        print(configure(args.plugin_id))
    except ValueError as error:
        parser.error(str(error))
