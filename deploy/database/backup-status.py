"""Validate pgBackRest inventory without exposing storage credentials."""

from __future__ import annotations

import json
import math
import sys
import time


def check_backup_status(document: object, now: float | None = None) -> None:
    if not isinstance(document, list) or len(document) != 1:
        raise ValueError("Expected one backup stanza")
    stanza = document[0]
    if (
        not isinstance(stanza, dict)
        or stanza.get("name") != "doglyad_database"
        or stanza.get("status", {}).get("code") != 0
    ):
        raise ValueError("Backup repository is not healthy")
    backups = stanza.get("backup", [])
    full = [item for item in backups if item.get("type") == "full"]
    if not full:
        raise ValueError("A completed full backup is required")
    completed = max(float(item["timestamp"]["stop"]) for item in full)
    age = (time.time() if now is None else now) - completed
    if not math.isfinite(age) or age < -300 or age > 26 * 3600:
        raise ValueError("Full backup age exceeds the 26-hour limit")


if __name__ == "__main__":
    try:
        check_backup_status(json.load(sys.stdin))
    except (ValueError, KeyError, TypeError):
        print("Backup status check failed", file=sys.stderr)
        sys.exit(1)
    print("Backup repository and full-backup age are healthy")
