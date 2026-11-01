from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice.analysis.compare_grouped import compare_grouped


def _rows() -> list[dict]:
    return [
        {
            "stage": "extraction",
            "id": key,
            "locale": "ru",
            "mode": "pilot",
            "variant": "clean",
            "recognizer": recognizer,
            "method": "rules",
            "clusterId": key,
            "sourceKind": "doctorRecording",
            "recordingMode": "scenarioDictation",
            "split": "validation",
            "audioSha256": key,
            "goldSha256": "gold",
            "expectedFieldIds": ["examinationDescription"],
            "status": "ok",
            "score": {"equivalentExactCase": recognizer == "a"},
        }
        for key in ("1", "2")
        for recognizer in ("a", "b")
    ]


@pytest.mark.parametrize(
    "field,value",
    [
        ("audioSha256", "different"),
        ("goldSha256", "different"),
        ("expectedFieldIds", []),
        ("variant", "noise"),
        ("clusterId", "different"),
        ("recordingMode", "readScript"),
        ("split", "test"),
    ],
)
def test_matching_ids_do_not_hide_changed_gold_audio_or_conditions(tmp_path: Path, field: str, value: object) -> None:
    rows = _rows()
    rows[1][field] = value
    path = tmp_path / "scores.jsonl"
    path.write_text("\n".join(map(json.dumps, rows)))
    with pytest.raises(ValueError):
        compare_grouped(path, "a/rules", "b/rules", locale="ru", modes=["pilot"])


def test_paired_direction_is_left_minus_right(tmp_path: Path) -> None:
    path = tmp_path / "scores.jsonl"
    path.write_text("\n".join(map(json.dumps, _rows())))
    result = compare_grouped(path, "a/rules", "b/rules", locale="ru", modes=["pilot"], variant="clean")
    assert result["confidence"]["estimate"] == 1
    assert result["confidence"]["clusters"] == 2
