"""Read-only architecture checks; no application imports, builds, or model calls."""

from __future__ import annotations

import argparse
import ast
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/harness/architecture"
SWIFT_SOURCE = Path(__file__).with_suffix(".swift")


def is_source(path: Path, root: Path = ROOT) -> bool:
    if not path.is_relative_to(root) or path.is_symlink():
        return False
    parts = path.relative_to(root).parts
    if any(
        part.startswith(".")
        or part in {"__pycache__", "Build", "build", "DerivedData", "Pods", "Carthage"}
        for part in parts
    ):
        return False
    if parts[:1] == ("ios",) and path.suffix == ".swift":
        return not any(
            path.is_relative_to(root / excluded)
            for excluded in (
                "ios/Config",
                "ios/Firebase",
                "ios/DoglyadNeuralModel/Resources",
            )
        )
    return (
        len(parts) >= 4
        and parts[:2] in (("backend", "main"), ("backend", "inference"))
        and parts[2] == "app"
        and path.suffix == ".py"
    )


def source_files(root: Path = ROOT) -> list[Path]:
    folders = ("ios", "backend/main/app", "backend/inference/app")
    return sorted(
        path
        for folder in folders
        for path in (root / folder).rglob("*")
        if path.is_file() and is_source(path, root)
    )


def python_errors(path: Path, root: Path = ROOT) -> list[str]:
    relative = path.relative_to(root)
    try:
        tree = ast.parse(path.read_text(), filename=str(relative))
    except SyntaxError as error:
        return [f"{relative}:{error.lineno}: python.syntax: {error.msg}"]
    # Each backend owns a separate 'app' package. Resolve relative imports in that package.
    module = list(relative.with_suffix("").parts[2:])
    package = module[:-1]
    layer = module[1] if len(module) > 2 else ""
    forbidden = {"model": ("app.service", "app.route"), "service": ("app.route",)}.get(
        layer, ()
    )
    errors = []
    for node in ast.walk(tree):
        names: list[str] = []
        if isinstance(node, ast.Import):
            names = [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            prefix = package[: len(package) - node.level + 1] if node.level else []
            base = ".".join([*prefix, *([node.module] if node.module else [])])
            names = [f"{base}.{alias.name}" for alias in node.names]
        for name in names:
            if any(
                name == boundary or name.startswith(boundary + ".")
                for boundary in forbidden
            ):
                errors.append(
                    f"{relative}:{node.lineno}: python.layer-import: {layer} must not import {name}."
                )
    return errors


def swift_checker() -> Path:
    compiler = Path(
        subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip()
    )
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
    ).strip()
    libraries = compiler.parent.parent / "lib/swift/host"
    version = subprocess.check_output(
        [str(compiler), "--version"], text=True, stderr=subprocess.STDOUT
    )
    digest = hashlib.sha256(
        SWIFT_SOURCE.read_bytes() + f"{compiler}{sdk}{version}".encode()
    ).hexdigest()[:20]
    BUILD.mkdir(parents=True, exist_ok=True)
    binary = BUILD / f"check-swift-{digest}"
    # Concurrent edit hooks share the cached analyzer, never a partly written binary.
    with (BUILD / "compile.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not binary.exists():
            temporary = binary.with_suffix(".tmp")
            subprocess.run(
                [
                    str(compiler),
                    "-sdk",
                    sdk,
                    "-I",
                    str(libraries),
                    "-L",
                    str(libraries),
                    "-module-cache-path",
                    str(BUILD / "module-cache"),
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    str(libraries),
                    str(SWIFT_SOURCE),
                    "-o",
                    str(temporary),
                ],
                check=True,
                timeout=90,
            )
            temporary.replace(binary)
    return binary


def check(files: list[Path], context: list[Path], root: Path = ROOT) -> int:
    errors = [
        error
        for path in files
        if path.suffix == ".py"
        for error in python_errors(path, root)
    ]
    for error in errors:
        print(error)
    swift = [str(path) for path in files if path.suffix == ".swift"]
    result = 0
    if swift:
        completed = subprocess.run(
            [str(swift_checker())],
            input=json.dumps(
                {
                    "files": swift,
                    "context": [
                        str(path) for path in context if path.suffix == ".swift"
                    ],
                }
            ),
            text=True,
            check=False,
            timeout=60,
        )
        result = completed.returncode
    return result or int(bool(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "files", nargs="*", help="Edited source paths; omit for the full project."
    )
    args = parser.parse_args()
    try:
        context = source_files()
        if args.files:
            paths = sorted({Path(value).resolve() for value in args.files})
            files = [path for path in paths if is_source(path) and path.is_file()]
        else:
            files = context
        result = check(files, context)
        if not result:
            print(f"Architecture checks passed ({len(files)} files).")
        return result
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Architecture check could not finish: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
