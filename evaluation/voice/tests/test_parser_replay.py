from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice.common import ROOT

from evaluation.voice.runners.parser_replay import prepare_parser_jobs, score_parser_jobs
from evaluation.voice.datasets.generate import file_sha256


def test_frozen_bundle_keeps_working_after_fixture_move_without_relaxing_hash_check(tmp_path: Path) -> None:
    source = ROOT / "evaluation/voice/datasets/fixtures/clinical_pilot_v2.json"
    bundle = tmp_path / "bundle"
    prepare_parser_jobs(source, bundle)
    metadata_path = bundle / "benchmark.json"
    metadata = json.loads(metadata_path.read_text())
    metadata["manifestPath"] = str(ROOT / "evaluation/voice/fixtures/clinical_pilot_v2.json")
    metadata_path.write_text(json.dumps(metadata))
    results = tmp_path / "empty.jsonl"
    results.write_text("")
    score = score_parser_jobs(bundle, results, tmp_path / "score.json", parser_id="test")
    assert score["manifestSha256"] == file_sha256(source)
    assert not score["isComplete"]
    metadata["manifestSha256"] = "different"
    metadata_path.write_text(json.dumps(metadata))
    with pytest.raises(ValueError, match="changed"):
        score_parser_jobs(bundle, results, tmp_path / "invalid.json", parser_id="test")


def test_stage_isolation_failure_denominators_and_no_gold_leakage(tmp_path: Path) -> None:
    cases = [
        {
            "id": key,
            "locale": "en",
            "examinationTypeId": "kidneys",
            "referenceText": "Left kidney",
            "expectedFields": {"examinationDescription": "Left kidney"},
            "audioSha256": key,
        }
        for key in ("a", "b")
    ]
    manifest = tmp_path / "corpus.json"
    manifest.write_text(json.dumps({"cases": cases}))
    asr = tmp_path / "asr.jsonl"
    asr.write_text(
        "\n".join(
            json.dumps(
                {
                    "id": case["id"],
                    "locale": "en",
                    "audioSha256": case["id"],
                    "recognizer": "test",
                    "status": "ok" if case["id"] == "a" else "failed",
                    "rawText": "Right kidney",
                }
            )
            for case in cases
        )
    )
    bundle = tmp_path / "bundle"
    prepare_parser_jobs(manifest, bundle, asr_paths=[asr], recognizer="test")
    jobs = [json.loads(line) for line in (bundle / "jobs.jsonl").read_text().splitlines()]
    assert len(jobs) == 6
    assert all(
        set(job) == {"id", "caseId", "inputStage", "locale", "examinationTypeId", "text", "inputStatus", "inputSha256"}
        for job in jobs
    )
    assert next(job for job in jobs if job["id"] == "a/correctedASR")["inputStatus"] == "missing"
    assert next(job for job in jobs if job["id"] == "b/rawASR")["inputStatus"] == "upstreamASRFailure"
    rows = [
        {
            "id": job["id"],
            "inputSha256": job["inputSha256"],
            "parserId": "test",
            "status": "ok",
            "fields": {"examinationDescription": job["text"]},
        }
        for job in jobs
        if job["inputStatus"] == "ready" and job["id"] != "b/goldText"
    ]
    results = tmp_path / "results.jsonl"
    results.write_text("\n".join(map(json.dumps, rows)))
    summary = score_parser_jobs(bundle, results, tmp_path / "scores.json", parser_id="test")
    assert not summary["isComplete"]
    assert summary["groups"]["en/goldText/unspecified/unspecified"]["missingParserResults"] == 1
    assert summary["groups"]["en/goldText/unspecified/unspecified"]["expectedFields"] == 2
    assert summary["groups"]["en/goldText/unspecified/unspecified"]["equivalentExactForms"] == 1
    assert summary["groups"]["en/rawASR/unspecified/unspecified"]["equivalentExactForms"] == 0
    assert summary["groups"]["en/rawASR/unspecified/unspecified"]["upstreamNotReady"] == 1
    assert summary["groups"]["en/correctedASR/unspecified/unspecified"]["upstreamNotReady"] == 2
    rows[0]["inputSha256"] = "wrong"
    results.write_text("\n".join(map(json.dumps, rows)))
    with pytest.raises(ValueError, match="mismatched"):
        score_parser_jobs(bundle, results, tmp_path / "bad.json", parser_id="test")
    manifest.write_text(json.dumps({"cases": cases[:1]}))
    with pytest.raises(ValueError, match="changed"):
        score_parser_jobs(bundle, results, tmp_path / "changed.json", parser_id="test")


def test_replay_uses_actual_downstream_correction_without_copying_answers(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "cases": [
                    {
                        "id": "a",
                        "locale": "en",
                        "examinationTypeId": "kidneys",
                        "referenceText": "Left kidney",
                        "expectedFields": {},
                        "audioSha256": "audio",
                    }
                ]
            }
        )
    )
    asr = tmp_path / "asr.jsonl"
    asr.write_text(
        json.dumps(
            {
                "id": "a",
                "locale": "en",
                "recognizer": "test",
                "audioSha256": "audio",
                "rawText": "left kid knee",
                "correctedText": "left kid knee",
                "status": "ok",
            }
        )
        + "\n"
    )
    corrected = tmp_path / "correction.jsonl"
    row = {
        "id": "test/a",
        "matrixCaseId": "a",
        "recognizer": "test",
        "locale": "en",
        "audioSha256": "audio",
        "asrResultSha256": file_sha256(asr),
        "rawText": "left kid knee",
        "text": "left kidney",
        "methods": {"secret": "expected answer must not leak"},
    }
    corrected.write_text(json.dumps(row) + "\n")
    output = tmp_path / "bundle"
    prepare_parser_jobs(manifest, output, asr_paths=[asr], recognizer="test", corrected_paths=[corrected])
    text = (output / "jobs.jsonl").read_text()
    assert "secret" not in text
    jobs = {job["inputStage"]: job for job in map(json.loads, text.splitlines())}
    assert jobs["rawASR"]["text"] == "left kid knee"
    assert jobs["correctedASR"]["text"] == "left kidney"
    corrected.write_text(json.dumps({**row, "rawText": "different source"}) + "\n")
    with pytest.raises(ValueError, match="frozen ASR"):
        prepare_parser_jobs(manifest, tmp_path / "bad", asr_paths=[asr], recognizer="test", corrected_paths=[corrected])

    # A recorded upstream failure is terminal, not a missing parser attempt.
    asr.write_text(
        json.dumps({"id": "a", "locale": "en", "recognizer": "test", "audioSha256": "audio", "status": "failed"}) + "\n"
    )
    failed_bundle = tmp_path / "failed-upstream"
    prepare_parser_jobs(manifest, failed_bundle, asr_paths=[asr], recognizer="test")
    job = json.loads((failed_bundle / "jobs.jsonl").read_text().splitlines()[0])
    results = tmp_path / "failed-upstream-results.jsonl"
    results.write_text(
        json.dumps(
            {"id": job["id"], "inputSha256": job["inputSha256"], "parserId": "test", "status": "ok", "fields": {}}
        )
        + "\n"
    )
    score = score_parser_jobs(failed_bundle, results, tmp_path / "failed-upstream-score.json", parser_id="test")
    assert score["isComplete"]
    assert score["groups"]["en/rawASR/unspecified/unspecified"]["equivalentExactForms"] == 0
