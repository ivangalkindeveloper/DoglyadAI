"""Serve one verified successful run to the local Figma development plugin."""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import threading
import time

from artifacts import publication
from configure_figma import bridge_key, configure
from preview_artifacts import preview_publication

LAYOUT_VERSION = "iphone17-screen-v10"


def serve(run: Path, timeout: int = 900, *, previews: bool = False) -> bool:
    manifest_path = configure()
    validate = preview_publication if previews else publication
    data = validate(run)
    if not data["figmaFileKey"]:
        raise ValueError(
            "Set figmaFileKey in test/secrets/config.local.json before running with --publish"
        )
    token = bridge_key()
    complete = threading.Event()
    images = {image["id"]: image for image in data["images"]}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args) -> None:
            pass

        def respond(
            self, status: int, body: bytes, kind: str = "application/json"
        ) -> None:
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header(
                "Access-Control-Allow-Headers",
                "Authorization, Content-Type, X-Doglyad-Regression-Protocol",
            )
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_OPTIONS(self) -> None:
            self.respond(204, b"")

        def is_authorized(self) -> bool:
            return secrets.compare_digest(
                self.headers.get("Authorization", ""), "Bearer " + token
            )

        def do_GET(self) -> None:
            if not self.is_authorized():
                self.respond(401, b"{}")
                return
            if self.headers.get("X-Doglyad-Regression-Protocol") != "10":
                self.respond(
                    426, b'{"error":"Restart the updated Doglyad AI Regression plugin"}'
                )
                return
            try:
                if self.path == "/manifest":
                    if validate(run) != data:
                        raise ValueError("Run manifest changed")
                    self.respond(200, json.dumps(data, ensure_ascii=False).encode())
                elif self.path.startswith("/image/") and self.path[7:] in images:
                    image = images[self.path[7:]]
                    from artifacts import sha

                    path = run / image["path"]
                    if sha(path) != image["sha256"]:
                        raise ValueError("Image changed")
                    self.respond(200, path.read_bytes(), "image/png")
                else:
                    self.respond(404, b"{}")
            except (ValueError, OSError):
                self.respond(409, b'{"error":"Run artifacts changed"}')

        def do_POST(self) -> None:
            if not self.is_authorized():
                self.respond(401, b"{}")
                return
            if self.path != "/ack":
                self.respond(404, b"{}")
                return
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size < 8192:
                    raise ValueError("Invalid response size")
                body = json.loads(self.rfile.read(size))
                if validate(run) != data:
                    raise ValueError("Run manifest changed")
                if (
                    body.get("runId") != data["runId"]
                    or body.get("fileKey") != data["figmaFileKey"]
                    or body.get("imageCount") != len(images)
                    or body.get("layoutVersion") != LAYOUT_VERSION
                    or (previews and body.get("scope") != "previews")
                    or not body.get("nodeId")
                ):
                    raise ValueError("Wrong publication acknowledgment")
                (run / "figma-receipt.json").write_text(
                    json.dumps(body, ensure_ascii=False, indent=2) + "\n"
                )
                self.respond(200, b'{"ok":true}')
                complete.set()
            except (OSError, ValueError, json.JSONDecodeError):
                self.respond(400, b'{"error":"Invalid acknowledgment"}')

    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    server.timeout = 1
    print(f"Plugin manifest: {manifest_path}", flush=True)
    print(
        "Waiting for Doglyad AI Regression in the configured Figma file. "
        "An open plugin imports automatically; no token entry is needed.",
        flush=True,
    )
    deadline = time.monotonic() + timeout
    try:
        while not complete.is_set() and time.monotonic() < deadline:
            server.handle_request()
    finally:
        server.server_close()
    return complete.is_set()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--previews", action="store_true")
    args = parser.parse_args()
    raise SystemExit(
        0 if serve(args.run.resolve(), args.timeout, previews=args.previews) else 1
    )
