"""Download a public PyPI wheel in ranges and verify its published SHA-256."""

from __future__ import annotations

import concurrent.futures
import hashlib
import json
from pathlib import Path
import sys
import urllib.request


def main() -> None:
    package, version, match = sys.argv[1:]
    root = Path(__file__).resolve().parent / "wheels"
    root.mkdir(exist_ok=True)
    with urllib.request.urlopen(
        f"https://pypi.org/pypi/{package}/{version}/json", timeout=30
    ) as response:
        data = json.load(response)
    choices = [f for f in data["urls"] if match in f["filename"]]
    assert len(choices) == 1, [f["filename"] for f in choices]
    item = choices[0]
    target = root / item["filename"]
    if target.exists():
        assert (
            hashlib.file_digest(target.open("rb"), "sha256").hexdigest()
            == item["digests"]["sha256"]
        )
        return
    parts = 8
    width = (item["size"] + parts - 1) // parts

    def download(index: int) -> Path:
        path = root / f"{item['filename']}.part{index}"
        begin, end = index * width, min((index + 1) * width, item["size"]) - 1
        for attempt in range(4):
            offset = path.stat().st_size if path.exists() else 0
            if offset == end - begin + 1:
                return path
            request = urllib.request.Request(
                item["url"], headers={"Range": f"bytes={begin + offset}-{end}"}
            )
            try:
                with urllib.request.urlopen(request, timeout=40) as response:
                    assert response.status == 206, response.status
                    assert response.headers["Content-Range"].startswith(
                        f"bytes {begin + offset}-{end}/"
                    )
                    with path.open("ab") as output:
                        while block := response.read(1024 * 1024):
                            output.write(block)
                assert path.stat().st_size == end - begin + 1
                print(
                    json.dumps({"event": "part", "package": package, "index": index}),
                    flush=True,
                )
                return path
            except Exception:
                if attempt == 3:
                    raise
        raise AssertionError("unreachable")

    with concurrent.futures.ThreadPoolExecutor(parts) as executor:
        paths = list(executor.map(download, range(parts)))
    staging = target.with_suffix(".assembling")
    with staging.open("wb") as output:
        for part in paths:
            with part.open("rb") as source:
                while block := source.read(1024 * 1024):
                    output.write(block)
    actual = hashlib.file_digest(staging.open("rb"), "sha256").hexdigest()
    assert actual == item["digests"]["sha256"]
    staging.rename(target)
    for part in paths:
        part.unlink()
    receipt = {
        "filename": item["filename"],
        "url": item["url"],
        "size": item["size"],
        "sha256": actual,
    }
    (root / (item["filename"] + ".json")).write_text(
        json.dumps(receipt, indent=2) + "\n"
    )
    print(json.dumps({"event": "verified", **receipt}), flush=True)


if __name__ == "__main__":
    main()
