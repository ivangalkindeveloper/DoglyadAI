#!/usr/bin/env python3
"""security-check — a Doglyad guard hook keeping secrets and Xcode noise out of git.

Registered by the generated Codex and Claude PreToolUse adapters. It intercepts
staging and commit commands and blocks them (exit 2) when forbidden files would
end up in the commit (backend secrets, Firebase config, model weights, Xcode state).

Logic:
- commit  → check the already staged files (git diff --cached).
- bulk staging → check every pending change (git status --porcelain)
  that the command is about to stage.
- explicit paths → check the paths named in the staging command itself.

Deletions are not blocked: the point of the hook is to keep a secret out of the
repository, and a deletion does the opposite — it removes one. Paths missing from
the working tree are therefore skipped, and `git diff --cached` is filtered
through `--diff-filter=d`.

Exit 0 — allow. Exit 2 — block, with the reason sent to stderr and to the agent.
Any internal error also exits 0 (fail-open) so normal work is never broken.
"""

import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

# Forbidden path patterns (matched against the full file path in the repository).
DENY_PATTERNS: list[tuple[str, str]] = [
    (r"(^|/)(backend/(main|inference)|deploy)/secrets(/|$)", "service secrets"),
    (r"(^|/)\.env(\.|$)", "backend environment secrets (.env)"),
    (r"(^|/)GoogleService-Info\.plist$", "Firebase configuration"),
    (r"(^|/)Config/[^/]*\.xcconfig$", "build configuration (BASE_URL, keys)"),
    (r"\.xcuserstate$", "Xcode user-state noise"),
    (r"(^|/)xcschememanagement\.plist$", "Xcode scheme-management noise"),
    (r"DoglyadNeuralModel/Resources/", "MLX model weights"),
    (r"\.(pem|p8|p12|keystore|jks)$", "private key or certificate"),
    (r"(^|/)id_rsa(\.|$)", "private SSH key"),
    (r"(^|/)(secrets?|credentials?)\.(json|ya?ml|txt)$", "secrets file"),
]


def matches_deny(path: str) -> str | None:
    """Returns the reason for blocking when the path is forbidden, otherwise None."""
    for pattern, reason in DENY_PATTERNS:
        if re.search(pattern, path):
            return reason
    return None


def run_git(args: list[str]) -> list[str]:
    """Run a git command and return the non-empty stdout lines (or [] on failure)."""
    try:
        out = subprocess.run(
            ["git", *args],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=ROOT,
        )
    except Exception:
        return []
    if out.returncode != 0:
        return []
    return [line for line in out.stdout.splitlines() if line.strip()]


def porcelain_paths() -> list[str]:
    """Paths with pending changes (modified + untracked) that
    bulk staging would capture."""
    paths: list[str] = []
    for line in run_git(["status", "--porcelain"]):
        # Format: XY <path>, or XY <old> -> <new> for renames.
        rest = line[3:] if len(line) > 3 else line
        if " -> " in rest:
            rest = rest.split(" -> ", 1)[1]
        paths.append(rest.strip().strip('"'))
    return paths


def repo_root() -> str:
    """Repository root (empty string when it cannot be determined)."""
    lines = run_git(["rev-parse", "--show-toplevel"])
    return lines[0] if lines else ""


def exists_in_worktree(path: str, root: str) -> bool:
    """Whether the file exists in the working tree. If it does not, the operation
    can only be a deletion, and deleting a secret from the repository is safe."""
    if not root:
        return True
    return os.path.exists(os.path.join(root, path))


def explicit_add_paths(command: str) -> list[str]:
    """Paths listed in the staging invocations themselves. Tokens from other
    commands (for example `git restore --staged <path>`) are not collected."""
    paths: list[str] = []
    for match in re.finditer(r"\bgit\s+add\b([^&|;]*)", command):
        for token in shlex.split(match.group(1)):
            if token.startswith("-"):
                continue
            paths.append(token)
    return paths


def is_broad_add(command: str) -> bool:
    """Does the command stage everything at once (-A / . / --all / -u)?"""
    return bool(
        re.search(r"\bgit\s+add\b[^&|;]*(\s-A\b|\s--all\b|\s-u\b|\s\.(\s|$))", command)
    )


def has_git_add(command: str) -> bool:
    return bool(re.search(r"\bgit\s+add\b", command))


def has_git_commit(command: str) -> bool:
    return bool(re.search(r"\bgit\s+commit\b", command))


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    if payload.get("tool_name") not in {"Bash", "exec_command"}:
        return 0

    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command", tool_input.get("cmd", "")) or ""
    if not (has_git_add(command) or has_git_commit(command)):
        return 0

    root = repo_root()

    # Candidates for landing in the commit: {path: reason}.
    flagged: dict[str, str] = {}

    def flag(path: str) -> None:
        """Flag the path when it is forbidden and is not a deletion."""
        reason = matches_deny(path)
        if reason and exists_in_worktree(path, root):
            flagged[path] = reason

    # 1. commit — whatever is already staged (`d` excludes deletions).
    if has_git_commit(command):
        for path in run_git(["diff", "--cached", "--name-only", "--diff-filter=d"]):
            flag(path)

    # 2. bulk staging — everything that would be staged at once.
    if is_broad_add(command):
        for path in porcelain_paths():
            flag(path)

    # 3. Explicitly named paths.
    for path in explicit_add_paths(command):
        flag(path)

    if not flagged:
        return 0

    lines = [
        "🛑 security-check: command blocked because protected files would enter the commit:",
        "",
    ]
    for path, reason in sorted(flagged.items()):
        lines.append(f"  • {path} — {reason}")
    lines += [
        "",
        "Remove them from the index before committing:",
        "  git restore --staged <path>",
        "then stage allowed changes explicitly instead of using `git add -A`.",
        "If a protected file must be added intentionally, do it manually outside this agent.",
    ]
    print("\n".join(lines), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
