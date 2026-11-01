"""Render the shared harness into native agent configuration and skill folders."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import stat
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]
STATE = ".codex/harness-manifest.json"
FIXED_OUTPUTS = {
    ".codex/config.toml",
    ".codex/hooks.json",
    ".codex/settings.json",
    ".claude/settings.json",
    ".mcp.json",
    ".mobilebuildmcp/config.yaml",
    "CLAUDE.md",
}
OUTPUT_FOLDERS = (
    ".agents/skills/",
    ".claude/skills/",
    ".codex/skills/",
    ".codex/hooks/",
    ".claude/hooks/",
)


def json_bytes(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode()


def fingerprint(content: bytes, mode: int) -> str:
    return hashlib.sha256(content + f"\nmode={mode:o}".encode()).hexdigest()


def destination(root: Path, name: str) -> Path:
    relative = PurePosixPath(name)
    if relative.is_absolute() or ".." in relative.parts or str(relative) != name:
        raise ValueError(f"Invalid generated path: {name}")
    if (
        name != STATE
        and name not in FIXED_OUTPUTS
        and not name.startswith(OUTPUT_FOLDERS)
    ):
        raise ValueError(f"Unmanaged destination: {name}")
    path = root / name
    for candidate in (path, *path.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError(f"Refusing a symlink destination: {candidate}")
    if path.exists() and not path.is_file():
        raise ValueError(f"Expected a regular file: {path}")
    return path


def render(root: Path) -> dict[str, tuple[bytes, int]]:
    source = root / "harness"
    outputs: dict[str, tuple[bytes, int]] = {}
    skills = sorted((source / "skills").iterdir())
    if not skills:
        raise ValueError("harness/skills is empty")
    for skill in skills:
        if (
            not skill.is_dir()
            or skill.is_symlink()
            or not re.fullmatch(r"[a-z0-9-]+", skill.name)
        ):
            raise ValueError(f"Invalid skill directory: {skill}")
        entry = skill / "SKILL.md"
        text = entry.read_text()
        if not text.startswith("---\n") or f"\nname: {skill.name}\n" not in text:
            raise ValueError(f"Skill name does not match its folder: {entry}")
        for path in sorted(skill.rglob("*")):
            if path.is_symlink():
                raise ValueError(f"Skill sources must be regular files: {path}")
            if (
                not path.is_file()
                or "__pycache__" in path.parts
                or path.name == ".DS_Store"
                or path.suffix == ".pyc"
            ):
                continue
            value = (path.read_bytes(), stat.S_IMODE(path.stat().st_mode))
            relative = path.relative_to(source / "skills").as_posix()
            for folder in (".agents/skills", ".claude/skills"):
                outputs[f"{folder}/{relative}"] = value

    commands = {
        "@SECURITY_HOOK@": shlex.join(
            ["python3", str(source / "hooks/security_check.py")]
        ),
        "@POST_EDIT_HOOK@": shlex.join(["python3", str(source / "hooks/post_edit.py")]),
    }
    for agent in ("codex", "claude"):
        hooks = json.loads((source / f"adapters/{agent}/hooks.json").read_text())
        for entries in hooks["hooks"].values():
            for entry in entries:
                re.compile(entry["matcher"])
                for hook in entry["hooks"]:
                    hook["command"] = commands[hook["command"]]
        if agent == "codex":
            outputs[".codex/hooks.json"] = (json_bytes(hooks), 0o644)
        else:
            settings = json.loads(
                (source / "adapters/claude/settings.json").read_text()
            )
            if "hooks" in settings:
                raise ValueError("Keep Claude hooks in adapters/claude/hooks.json")
            settings.update(hooks)
            outputs[".claude/settings.json"] = (json_bytes(settings), 0o644)

    servers = json.loads((source / "mcp/servers.json").read_text())["mcpServers"]
    config = (source / "adapters/codex/config.toml").read_text().rstrip() + "\n"
    if "mcp_servers" in tomllib.loads(config):
        raise ValueError("Keep MCP definitions in harness/mcp/servers.json")
    claude_servers = {}
    for name, server in sorted(servers.items()):
        allowed = {
            "type",
            "command",
            "args",
            "env",
            "startup_timeout_sec",
            "tool_timeout_sec",
        }
        if server.get("type") != "stdio" or set(server) - allowed:
            raise ValueError(f"Unsupported MCP configuration: {name}")
        if not isinstance(server.get("command"), str) or not isinstance(
            server.get("args"), list
        ):
            raise ValueError(f"MCP command and args are required: {name}")
        claude_servers[name] = {
            key: server[key]
            for key in ("type", "command", "args", "env")
            if key in server
        }
        config += f"\n[mcp_servers.{json.dumps(name)}]\n"
        for key in ("command", "args", "startup_timeout_sec", "tool_timeout_sec"):
            if key in server:
                config += f"{key} = {json.dumps(server[key], ensure_ascii=False)}\n"
        if server.get("env"):
            config += f"\n[mcp_servers.{json.dumps(name)}.env]\n"
            for key, value in sorted(server["env"].items()):
                config += (
                    f"{json.dumps(key)} = {json.dumps(value, ensure_ascii=False)}\n"
                )
    tomllib.loads(config)
    outputs[".codex/config.toml"] = (config.encode(), 0o644)
    outputs[".mcp.json"] = (json_bytes({"mcpServers": claude_servers}), 0o644)
    outputs[".mobilebuildmcp/config.yaml"] = (
        (source / "mcp/mobilebuildmcp.yaml").read_bytes(),
        0o644,
    )
    outputs["CLAUDE.md"] = (b"@AGENTS.md\n", 0o644)
    return outputs


def atomic_write(path: Path, content: bytes, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def synchronize(root: Path, *, check: bool = False, dry_run: bool = False) -> list[str]:
    outputs = render(root)
    state_path = destination(root, STATE)
    previous = {}
    if state_path.exists():
        state = json.loads(state_path.read_text())
        if state.get("version") != 1 or not isinstance(state.get("files"), dict):
            raise ValueError("Unsupported harness manifest")
        previous = state["files"]
    changes = []
    conflicts = []
    # Inspect every target before writing anything. Never infer ownership from a folder name.
    for name in sorted(outputs.keys() | previous.keys()):
        path = destination(root, name)
        current = (
            fingerprint(path.read_bytes(), stat.S_IMODE(path.stat().st_mode))
            if path.exists()
            else None
        )
        expected = fingerprint(*outputs[name]) if name in outputs else None
        if current == expected:
            continue
        if current is not None and current != previous.get(name):
            conflicts.append(name)
        else:
            changes.append(name)
    if conflicts:
        raise ValueError(
            "Manual or unmanaged changes; reconcile them with harness/ before syncing:\n"
            + "\n".join(conflicts)
        )
    state_content = json_bytes(
        {
            "version": 1,
            "files": {
                name: fingerprint(*value) for name, value in sorted(outputs.items())
            },
        }
    )
    state_changed = not state_path.exists() or state_path.read_bytes() != state_content
    if check and (changes or state_changed):
        raise ValueError(
            "Harness is out of sync; run make sync-harness:\n"
            + "\n".join(changes or [STATE])
        )
    if check or dry_run:
        return changes + ([STATE] if state_changed else [])
    for name in changes:
        path = destination(root, name)
        if name in outputs:
            atomic_write(path, *outputs[name])
        else:
            path.unlink()
    if state_changed:
        atomic_write(state_path, state_content, 0o644)
    return changes + ([STATE] if state_changed else [])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check", action="store_true", help="Check without changing generated files."
    )
    mode.add_argument(
        "--dry-run", action="store_true", help="Show pending paths without writing."
    )
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        lock = root / "build/harness/sync.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            changes = synchronize(root, check=args.check, dry_run=args.dry_run)
        print("Harness is up to date." if not changes else "\n".join(changes))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Harness sync failed: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
