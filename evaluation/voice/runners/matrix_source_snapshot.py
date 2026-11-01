from __future__ import annotations

from pathlib import Path

from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256


def matrix_source_snapshot(root: Path = ROOT) -> dict[str, str]:
    """Bind a device run to code/configuration without reading secret contents."""
    files = set((root / "ios").rglob("*.swift"))
    files.update((root / "ios").rglob("Package.resolved"))
    files.update((root / "ios").rglob("*.pbxproj"))
    files.update((root / "ios/Config").glob("*.xcconfig"))
    files.update((root / "backend/main/config/development").rglob("*.json"))
    return {str(path.relative_to(root)): file_sha256(path) for path in sorted(files) if path.is_file()}
