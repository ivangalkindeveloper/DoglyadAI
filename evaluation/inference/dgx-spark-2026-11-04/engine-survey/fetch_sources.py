"""Fetch public upstream metadata for an engine compatibility audit."""

from __future__ import annotations

import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
REPOS = {
    "llama.cpp": "ggml-org/llama.cpp",
    "tensorrt-llm": "NVIDIA/TensorRT-LLM",
    "edge-llm": "NVIDIA/TensorRT-Edge-LLM",
    "lmdeploy": "InternLM/lmdeploy",
}


def _fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=40) as response:
        return response.read()


def _repo(item: tuple[str, str]) -> dict:
    name, repo = item
    base = "https://api.github.com/repos/" + repo
    commit = json.loads(_fetch(base + "/commits?per_page=1"))[0]
    release = json.loads(_fetch(base + "/releases/latest"))
    tree = json.loads(_fetch(base + "/git/trees/" + commit["sha"] + "?recursive=1"))
    target = ROOT / "sources" / name
    target.mkdir(parents=True, exist_ok=True)
    paths = [entry["path"] for entry in tree["tree"] if entry["type"] == "blob"]
    selected = [
        path
        for path in paths
        if any(
            term in path.lower()
            for term in (
                "gemma3",
                "gemma_3",
                "supported_models",
                "support-matrix",
                "support_matrix",
            )
        )
        and path.endswith((".md", ".rst", ".py"))
    ]
    selected += [
        path
        for path in ("pyproject.toml", "setup.py", "requirements.txt", "README.md")
        if path in paths
    ]
    files = []
    for path in selected:
        url = f"https://raw.githubusercontent.com/{repo}/{commit['sha']}/{path}"
        content = _fetch(url)
        filename = path.replace("/", "__")
        (target / filename).write_bytes(content)
        files.append(
            {
                "path": path,
                "file": filename,
                "url": url,
                "sha256": hashlib.sha256(content).hexdigest(),
            }
        )
    metadata = {
        "repo": repo,
        "commit": commit["sha"],
        "date": commit["commit"]["committer"]["date"],
        "release": release["tag_name"],
        "assets": [a["name"] for a in release["assets"]],
        "files": files,
        "candidate_paths": [
            p
            for p in paths
            if any(t in p.lower() for t in ("gemma", "install", "docker", "support"))
        ],
    }
    (ROOT / "sources" / (name + "-version.json")).write_text(
        json.dumps(metadata, indent=2) + "\n"
    )
    return {
        "repo": repo,
        "commit": commit["sha"],
        "release": release["tag_name"],
        "saved_files": len(files),
    }


def main() -> None:
    with concurrent.futures.ThreadPoolExecutor(4) as executor:
        for result in executor.map(_repo, REPOS.items()):
            print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
