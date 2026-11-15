"""Bounded, streaming transport for private Yandex Disk backup files."""

from __future__ import annotations

import hashlib
import http.client
import json
import tempfile
import time
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlencode, urljoin, urlsplit


class YandexDisk:
    def __init__(self, token: str, folder: str) -> None:
        if not token or token.startswith("REPLACE_") or any(c.isspace() for c in token):
            raise ValueError("Configure the Yandex Disk OAuth token")
        if (
            not folder.startswith("/DoglyadAIDB/")
            or ".." in PurePosixPath(folder).parts
        ):
            raise ValueError("Use an environment folder inside DoglyadAIDB")
        self.token = token
        self.folder = folder.rstrip("/")
        self.directories: set[str] = set()

    def metadata(
        self, relative: str, *, is_missing_allowed: bool = False
    ) -> dict[str, Any] | None:
        status, document = self._api(
            "GET", "/resources", {"path": self._path(relative)}
        )
        if status == 404 and is_missing_allowed:
            return None
        self._expect(status, (200,))
        return document

    def list(self, relative: str = "") -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        while True:
            status, document = self._api(
                "GET",
                "/resources",
                {
                    "path": self._path(relative),
                    "limit": 1000,
                    "offset": len(items),
                    "sort": "name",
                },
            )
            self._expect(status, (200,))
            page = document["_embedded"]["items"]
            items.extend(page)
            if len(items) >= document["_embedded"]["total"]:
                return items
            if not page:
                raise ValueError("Incomplete Disk directory listing")

    def mkdir(self, relative: str = "") -> None:
        if relative in self.directories:
            return
        full = PurePosixPath(self._path(relative))
        current = ""
        for part in full.parts[1:]:
            current += "/" + part
            status, _ = self._api("PUT", "/resources", {"path": current})
            self._expect(status, (201, 409))
        metadata = self.metadata(relative)
        if metadata is None or metadata.get("type") != "dir":
            raise ValueError("Disk backup folder is not a directory")
        self.directories.add(relative)

    def upload(
        self, local: Path, relative: str, known_metadata: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        digest = self._digest(local)
        size = local.stat().st_size
        existing = known_metadata or self.metadata(relative, is_missing_allowed=True)
        if existing is not None:
            self._verify(existing, digest, size)
            return existing
        status, document = self._api(
            "GET",
            "/resources/upload",
            {"path": self._path(relative), "overwrite": "false"},
        )
        self._expect(status, (200,))
        connection, target = self._transfer(document, "PUT")
        try:
            with local.open("rb") as source:
                connection.request(
                    "PUT",
                    target,
                    body=source,
                    headers={
                        "Content-Length": str(size),
                        "Content-Type": "application/octet-stream",
                    },
                )
                response = connection.getresponse()
                self._expect(response.status, (201, 202))
        finally:
            connection.close()
        for _ in range(60):
            metadata = self.metadata(relative, is_missing_allowed=True)
            if metadata is not None:
                self._verify(metadata, digest, size)
                return metadata
            time.sleep(2)
        raise TimeoutError("Disk upload did not become available")

    def download(self, relative: str, local: Path, digest: str, size: int) -> None:
        metadata = self.metadata(relative)
        if metadata is None:
            raise ValueError("Missing remote backup file")
        self._verify(metadata, digest, size)
        status, document = self._api(
            "GET", "/resources/download", {"path": self._path(relative)}
        )
        self._expect(status, (200,))
        connection, target = self._transfer(document, "GET")
        try:
            for _ in range(5):
                connection.request("GET", target)
                response = connection.getresponse()
                if response.status not in (301, 302, 303, 307, 308):
                    break
                location = response.getheader("Location")
                if not location:
                    raise ValueError("Missing Disk download redirect")
                href = urljoin("https://" + connection.host + target, location)
                connection.close()
                connection, target = self._transfer(
                    {"href": href, "method": "GET"}, "GET"
                )
            self._expect(response.status, (200,))
            remaining = size
            with local.open("xb") as output:
                while remaining:
                    chunk = response.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("Truncated backup download")
                    output.write(chunk)
                    remaining -= len(chunk)
                if response.read(1):
                    raise ValueError("Backup download exceeds expected size")
            if self._digest(local) != digest:
                raise ValueError("Downloaded backup checksum does not match")
        finally:
            connection.close()

    def read_json(self, relative: str) -> dict[str, Any]:
        metadata = self.metadata(relative)
        if metadata is None or not 0 < metadata.get("size", 0) <= 16 * 1024 * 1024:
            raise ValueError("Invalid backup manifest size")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            self.download(relative, path, metadata["sha256"], metadata["size"])
            return json.loads(path.read_text())

    def delete(self, relative: str) -> None:
        # The caller restricts this to its own completed backup generations/checkpoints.
        status, _ = self._api(
            "DELETE",
            "/resources",
            {"path": self._path(relative), "permanently": "true"},
        )
        self._expect(status, (204, 202, 404))
        for _ in range(60):
            if self.metadata(relative, is_missing_allowed=True) is None:
                return
            time.sleep(2)
        raise TimeoutError("Old backup deletion did not finish")

    def _path(self, relative: str) -> str:
        if relative.startswith("/") or ".." in PurePosixPath(relative).parts:
            raise ValueError("Invalid backup relative path")
        return self.folder + ("/" + relative if relative else "")

    def _api(
        self, method: str, endpoint: str, query: dict[str, Any]
    ) -> tuple[int, dict[str, Any]]:
        connection = http.client.HTTPSConnection("cloud-api.yandex.net", timeout=30)
        try:
            connection.request(
                method,
                "/v1/disk" + endpoint + "?" + urlencode(query),
                headers={
                    "Authorization": "OAuth " + self.token,
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                },
            )
            response = connection.getresponse()
            payload = response.read(16 * 1024 * 1024 + 1)
            if len(payload) > 16 * 1024 * 1024:
                raise ValueError("Disk API response too large")
            # Provider errors may contain sensitive paths or URLs. Never expose them.
            document = json.loads(payload) if response.status == 200 and payload else {}
            return response.status, document
        finally:
            connection.close()

    @staticmethod
    def _transfer(
        document: dict[str, Any], method: str
    ) -> tuple[http.client.HTTPSConnection, str]:
        url = urlsplit(document["href"])
        hostname = url.hostname or ""
        if (
            document.get("method") != method
            or url.scheme != "https"
            or not hostname.endswith((".yandex.net", ".yandex.ru"))
            or url.port not in (None, 443)
            or url.username
            or url.password
            or url.fragment
        ):
            raise ValueError("Invalid Disk transfer URL")
        return http.client.HTTPSConnection(hostname, timeout=120), url.path + (
            "?" + url.query if url.query else ""
        )

    @staticmethod
    def _expect(status: int, expected: tuple[int, ...]) -> None:
        if status not in expected:
            raise RuntimeError(f"Yandex Disk request failed (HTTP {status})")

    @staticmethod
    def _digest(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
        return digest.hexdigest()

    @staticmethod
    def _verify(metadata: dict[str, Any], digest: str, size: int) -> None:
        if (
            metadata.get("type") != "file"
            or metadata.get("sha256") != digest
            or metadata.get("size") != size
        ):
            raise ValueError("Disk backup checksum or size does not match")
