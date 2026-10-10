from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"
SOURCE = ROOT / "tools/format-swift-arguments.swift"
BUILD = ROOT / "build/swift-formatting"


def swift_files() -> list[str]:
    excluded = [
        line.split(maxsplit=1)[1]
        for line in (IOS / ".swiftformat").read_text().splitlines()
        if line.startswith("--exclude ")
    ]

    def is_excluded(path: Path) -> bool:
        relative = path.relative_to(IOS)
        # Match excluded folders as well as their descendants.
        return any(
            fnmatch.fnmatch(str(prefix), pattern)
            for prefix in (relative, *relative.parents)
            for pattern in excluded
        ) or any(part.startswith(".") for part in relative.parts)

    return sorted(
        str(path)
        for path in IOS.rglob("*.swift")
        if not path.is_symlink() and not is_excluded(path)
    )


def argument_formatter() -> Path:
    compiler = Path(
        subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip()
    )
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
    ).strip()
    libraries = compiler.parent.parent / "lib/swift/host"
    if not (libraries / "SwiftParser.swiftmodule").exists():
        raise RuntimeError(
            "The selected Xcode toolchain must provide SwiftParser and SwiftSyntax."
        )
    BUILD.mkdir(parents=True, exist_ok=True)
    executable = BUILD / "format-swift-arguments"
    marker = BUILD / "toolchain.txt"
    toolchain = (
        subprocess.check_output(["xcrun", "swiftc", "--version"], text=True)
        + str(compiler)
        + sdk
    )
    if (
        not executable.exists()
        or executable.stat().st_mtime < SOURCE.stat().st_mtime
        or not marker.exists()
        or marker.read_text() != toolchain
    ):
        subprocess.run(
            [
                str(compiler),
                "-sdk",
                sdk,
                "-O",
                "-I",
                str(libraries),
                "-L",
                str(libraries),
                "-Xlinker",
                "-rpath",
                "-Xlinker",
                str(libraries),
                str(SOURCE),
                "-o",
                str(executable),
            ],
            check=True,
        )
        marker.write_text(toolchain)
    return executable


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Format iOS with every argument on its own line."
    )
    parser.add_argument(
        "--check", action="store_true", help="Check without changing files."
    )
    args = parser.parse_args()
    executable = argument_formatter()
    command = ["swiftformat", "."]
    if args.check:
        command.append("--lint")
    subprocess.run(command, cwd=IOS, check=True)
    subprocess.run(
        [str(executable), *(["--check"] if args.check else [])],
        input=json.dumps(swift_files()),
        text=True,
        check=True,
    )
    if not args.check:
        subprocess.run(command, cwd=IOS, check=True)


if __name__ == "__main__":
    main()
