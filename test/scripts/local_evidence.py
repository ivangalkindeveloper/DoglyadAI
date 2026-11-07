"""Read only the owned Simulator's local database and compare destructive-action results."""

from __future__ import annotations

import hashlib
import io
from PIL import Image, ImageOps
import json
from pathlib import Path
import plistlib
import sqlite3
import subprocess

TABLES = {
    "reports": [
        "ZUSEXAMINATIONREPORTDB",
        "ZUSEXAMINATIONDATADB",
        "ZSETTINGSAIDB",
        "ZUSEXAMINATIONMODELREPORTDB",
        "ZUSEXAMINATIONSCANPHOTODB",
        "ZUSEXAMINATIONPHOTOREMARKSDB",
        "ZUSEXAMINATIONPHOTOREMARKPOINTDB",
        "ZUSREPORTGENERATIONDB",
    ],
    "templates": ["ZUSEXAMINATIONTEMPLATEDB"],
    "draft": ["ZUSEXAMINATIONDRAFTDB", "ZUSEXAMINATIONDRAFTPHOTODB"],
}
PREFERENCES = [
    "settingsAI",
    "userEmail",
    "isRecommendationsIncluded",
    "isPhotoRemarks",
    "isDescriptionRemarks",
    "isRemarksVisible",
    "isOnBoardingCompleted",
    "acceptedLegalDocumentDate",
    "selectedUSExaminationTemplateId",
]


def digest(value) -> str:
    return hashlib.sha256(
        json.dumps(
            value,
            sort_keys=True,
            default=lambda x: x.hex() if isinstance(x, bytes) else str(x),
        ).encode()
    ).hexdigest()


def snapshot(device: str, app_id: str) -> dict:
    if app_id != "com.medical.doglyad.local":
        raise ValueError("Local evidence requires the isolated local application")
    container = Path(
        subprocess.check_output(
            ["xcrun", "simctl", "get_app_container", device, app_id, "data"], text=True
        ).strip()
    )
    source = container / "Library/Application Support/default.store"
    result = {}
    with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True) as connection:
        for group, tables in TABLES.items():
            data = {}
            for table in tables:
                columns = [
                    row[1]
                    for row in connection.execute(f'PRAGMA table_info("{table}")')
                    if row[1] != "Z_OPT"
                ]
                if not columns:
                    raise ValueError("Local evidence schema changed: " + table)
                quoted = ",".join('"' + name + '"' for name in columns)
                data[table] = connection.execute(
                    f'SELECT {quoted} FROM "{table}" ORDER BY Z_PK'
                ).fetchall()
            result[group] = dict(
                count=len(data[tables[0]]),
                rows=sum(len(rows) for rows in data.values()),
                sha256=digest(data),
            )
        aspects = []
        for (blob,) in connection.execute(
            "SELECT ZDATA FROM ZUSEXAMINATIONDRAFTPHOTODB ORDER BY ZPOSITION"
        ):
            with Image.open(io.BytesIO(blob)) as raw:
                image = ImageOps.exif_transpose(raw)
                width, height = image.size
                aspects.append(
                    "square"
                    if width == height
                    else "landscape"
                    if width > height
                    else "portrait"
                )
        result["draftPhotoAspects"] = aspects
    preferences = plistlib.loads(
        (container / "Library/Preferences" / (app_id + ".plist")).read_bytes()
    )
    ai = json.loads(preferences["settingsAI"]) if preferences.get("settingsAI") else {}
    result["settingsAIValues"] = {
        key: ai.get(key)
        for key in ["selectedNeuralModelId", "isMarkdown", "temperature", "maxTokens"]
    }
    result["presentPreferences"] = sorted(
        key for key in PREFERENCES if key in preferences
    )
    result["settings"] = dict(
        sha256=digest({key: preferences.get(key) for key in PREFERENCES})
    )
    speech = container / "Library/Application Support/WhisperKit"
    result["speechModel"] = dict(
        count=len(list(speech.rglob("*"))) if speech.exists() else 0
    )
    return result


def verify_local(before: dict, after: dict, expected: dict) -> dict:
    if "draftPhotoAspects" in expected and sorted(after["draftPhotoAspects"]) != sorted(
        expected["draftPhotoAspects"]
    ):
        raise ValueError(
            "Imported photo aspect ratios or count differ from the selected gallery fixtures"
        )
    for key, value in expected.get("settingsAIValues", {}).items():
        if after["settingsAIValues"].get(key) != value:
            raise ValueError("AI setting did not return to its default: " + key)
    for key in expected.get("preferencesCleared", []):
        if key in after["presentPreferences"]:
            raise ValueError("Local preference was not cleared: " + key)
    for group, minimum in expected.get("minimumBefore", {}).items():
        if before[group]["count"] < minimum:
            raise ValueError("Local test precondition is empty: " + group)
    for group in expected.get("preserved", []):
        if before[group] != after[group]:
            raise ValueError("Local data unexpectedly changed: " + group)
    for group, delta in expected.get("countDelta", {}).items():
        if after[group]["count"] - before[group]["count"] != delta:
            raise ValueError("Unexpected local record count change: " + group)
    for group in expected.get("cleared", []):
        if after[group]["count"] != 0 or after[group].get("rows", 0) != 0:
            raise ValueError("Local data was not cleared: " + group)
    return dict(status="passed", expected=expected, before=before, after=after)
