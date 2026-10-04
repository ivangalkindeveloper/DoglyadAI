from __future__ import annotations

from collections import Counter
import json

import pytest

from evaluation.voice.freeform_holdout_v4 import make_cases, write_cases
from evaluation.voice.freeform_holdout_v5 import make_cases as make_v5_cases
from evaluation.voice.freeform_holdout_v5 import write_cases as write_v5_cases
from evaluation.voice.freeform_holdout_v6 import make_cases as make_v6_cases
from evaluation.voice.freeform_holdout_v6 import write_cases as write_v6_cases
from evaluation.voice.freeform_holdout_v7 import make_cases as make_v7_cases
from evaluation.voice.freeform_holdout_v7 import write_cases as write_v7_cases
from evaluation.voice.freeform_holdout_v8 import make_cases as make_v8_cases
from evaluation.voice.freeform_holdout_v8 import write_cases as write_v8_cases
from evaluation.voice.prepare_holdout_ios import (
    AUDIO_MODE,
    AUDIO_MODE_V5,
    AUDIO_MODE_V6,
    AUDIO_MODE_V7,
    AUDIO_MODE_V8,
    prepare_holdout_fixtures,
)
from evaluation.voice.score_candidate import score_candidate_report


def test_frozen_holdout_covers_each_type_and_locale(tmp_path) -> None:
    cases = make_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == len(cases)
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        ("en", "complete"): 31,
        ("en", "partial"): 31,
        ("ru", "complete"): 31,
        ("ru", "partial"): 31,
    }
    assert write_cases(tmp_path)["corpusSha256"] == "2afa01003ee2f5425e8e08f6c5b46a6335ff8db44417d1671d921972ae5152ea"


def test_second_holdout_was_frozen_before_parser_changes(tmp_path) -> None:
    cases = make_v5_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == 124
    assert (
        write_v5_cases(tmp_path)["corpusSha256"] == "875ccf611416be82d6b6d714785cc77c64289a5f8c9896776e77d824799026f9"
    )


def test_third_holdout_is_frozen_before_field_reconciliation_changes(tmp_path) -> None:
    cases = make_v6_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        ("en", "complete"): 31,
        ("en", "partial"): 31,
        ("ru", "complete"): 31,
        ("ru", "partial"): 31,
    }
    assert (
        write_v6_cases(tmp_path)["corpusSha256"] == "1699ae6e67c183ec8ebccc3ad3a78c3c55dfda356a64af393ec208b56d89c9c6"
    )
    earlier_texts = {case["spokenText"] for case in make_cases() + make_v5_cases()}
    assert all(case["spokenText"] not in earlier_texts for case in cases)


def test_fourth_holdout_is_frozen_before_cue_extraction_changes(tmp_path) -> None:
    cases = make_v7_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        ("en", "complete"): 31,
        ("en", "partial"): 31,
        ("ru", "complete"): 31,
        ("ru", "partial"): 31,
    }
    assert (
        write_v7_cases(tmp_path)["corpusSha256"] == "0d499bdbbd7e95fb23e47f77a8cdbcd7cf712df338d50b916357f23682627aa8"
    )
    earlier_texts = {case["spokenText"] for case in make_cases() + make_v5_cases() + make_v6_cases()}
    assert all(case["spokenText"] not in earlier_texts for case in cases)


def test_fifth_holdout_is_frozen_before_v7_error_fixes(tmp_path) -> None:
    cases = make_v8_cases()
    assert len(cases) == 124
    assert len({case["id"] for case in cases}) == 124
    assert (
        write_v8_cases(tmp_path)["corpusSha256"] == "0487a2a30f816df470f1144a2d4444b6fcb498626f68ebae731f481913a9d85f"
    )
    earlier_texts = {case["spokenText"] for case in make_cases() + make_v5_cases() + make_v6_cases() + make_v7_cases()}
    assert all(case["spokenText"] not in earlier_texts for case in cases)


def test_holdout_fixture_keeps_expected_provenance(tmp_path) -> None:
    fixture = prepare_holdout_fixtures(locale="ru", destination=tmp_path)
    assert fixture["audioMode"] == AUDIO_MODE
    assert fixture["textOnly"] is True
    assert fixture["measureGold"] is True
    assert len(fixture["cases"]) == 62
    assert {case["locale"] for case in fixture["cases"]} == {"ru"}
    assert fixture["holdoutV4Sha256"] == "2afa01003ee2f5425e8e08f6c5b46a6335ff8db44417d1671d921972ae5152ea"


def test_second_holdout_fixture_keeps_separate_provenance(tmp_path) -> None:
    fixture = prepare_holdout_fixtures(locale="en", version=5, destination=tmp_path)
    assert fixture["audioMode"] == AUDIO_MODE_V5
    assert len(fixture["cases"]) == 62
    assert fixture["holdoutV5Sha256"] == "875ccf611416be82d6b6d714785cc77c64289a5f8c9896776e77d824799026f9"


def test_third_holdout_fixture_keeps_separate_provenance(tmp_path) -> None:
    fixture = prepare_holdout_fixtures(locale="ru", version=6, destination=tmp_path)
    assert fixture["audioMode"] == AUDIO_MODE_V6
    assert len(fixture["cases"]) == 62
    assert fixture["holdoutV6Sha256"] == "1699ae6e67c183ec8ebccc3ad3a78c3c55dfda356a64af393ec208b56d89c9c6"


def test_fourth_holdout_fixture_keeps_separate_provenance(tmp_path) -> None:
    fixture = prepare_holdout_fixtures(locale="en", version=7, destination=tmp_path)
    assert fixture["audioMode"] == AUDIO_MODE_V7
    assert len(fixture["cases"]) == 62
    assert fixture["holdoutV7Sha256"] == "0d499bdbbd7e95fb23e47f77a8cdbcd7cf712df338d50b916357f23682627aa8"


def test_fifth_holdout_fixture_keeps_separate_provenance(tmp_path) -> None:
    fixture = prepare_holdout_fixtures(locale="ru", version=8, destination=tmp_path)
    assert fixture["audioMode"] == AUDIO_MODE_V8
    assert len(fixture["cases"]) == 62
    assert fixture["holdoutV8Sha256"] == "0487a2a30f816df470f1144a2d4444b6fcb498626f68ebae731f481913a9d85f"


def test_holdout_scorer_checks_corpus_hash(tmp_path) -> None:
    manifest = write_cases()
    case = make_cases()[0]
    report = {
        "platform": "iOS",
        "systemVersion": "26.6",
        "deviceModel": "iPhone",
        "fixtureSplit": "freeformHoldoutV4",
        "fixtureRegressionSha256": "regression-hash",
        "fixtureHoldoutV4Sha256": manifest["corpusSha256"],
        "fixtureAudioManifestSha256": None,
        "fixtureAudioMode": AUDIO_MODE,
        "results": [
            {
                "id": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "goldTextParse": {"status": "ok", "fields": case["expectedFields"], "warnings": {}},
                "recognizedTextParse": {
                    "speechAnalyzer": {"status": "skipped"},
                    "sfSpeechRecognizer": {"status": "skipped"},
                },
                "asr": {},
            }
        ],
    }
    report_path = tmp_path / "report.json"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    summary = score_candidate_report(report_path, tmp_path / "scored")
    assert summary["holdoutV4Sha256"] == manifest["corpusSha256"]
    assert summary["byLocale"]["en"]["goldTextExactCases"] == 1
    assert summary["byLocale"]["en"]["goldTextCorrectFields"] == len(case["expectedFields"])
    assert summary["byLocale"]["en"]["expectedPresentFields"] == len(case["expectedFields"])
    markdown = (tmp_path / "scored" / "summary.md").read_text(encoding="utf-8")
    assert "Input exact forms | Input correct fields" in markdown
    assert f"1/1 | {len(case['expectedFields'])}/{len(case['expectedFields'])}" in markdown

    report["fixtureHoldoutV4Sha256"] = "stale"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    with pytest.raises(ValueError, match="different corpus"):
        score_candidate_report(report_path, tmp_path / "stale")


def test_third_holdout_scorer_checks_corpus_hash(tmp_path) -> None:
    manifest = write_v6_cases()
    case = make_v6_cases()[0]
    report = {
        "platform": "iOS",
        "systemVersion": "26.6",
        "deviceModel": "iPhone",
        "fixtureSplit": "freeformHoldoutV6",
        "fixtureRegressionSha256": "regression-hash",
        "fixtureHoldoutV6Sha256": manifest["corpusSha256"],
        "fixtureAudioManifestSha256": None,
        "fixtureAudioMode": AUDIO_MODE_V6,
        "results": [
            {
                "id": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "goldTextParse": {"status": "ok", "fields": case["expectedFields"], "warnings": {}},
                "recognizedTextParse": {
                    "speechAnalyzer": {"status": "skipped"},
                    "sfSpeechRecognizer": {"status": "skipped"},
                },
                "asr": {},
            }
        ],
    }
    report_path = tmp_path / "report.json"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    summary = score_candidate_report(report_path, tmp_path / "scored")
    assert summary["holdoutV6Sha256"] == manifest["corpusSha256"]
    assert summary["byLocale"]["en"]["goldTextExactCases"] == 1

    report["fixtureHoldoutV6Sha256"] = "stale"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    with pytest.raises(ValueError, match="different corpus"):
        score_candidate_report(report_path, tmp_path / "stale")


def test_fourth_holdout_scorer_checks_corpus_hash(tmp_path) -> None:
    manifest = write_v7_cases()
    case = make_v7_cases()[0]
    report = {
        "platform": "iOS",
        "systemVersion": "26.6",
        "deviceModel": "iPhone",
        "fixtureSplit": "freeformHoldoutV7",
        "fixtureRegressionSha256": "regression-hash",
        "fixtureHoldoutV7Sha256": manifest["corpusSha256"],
        "fixtureAudioManifestSha256": None,
        "fixtureAudioMode": AUDIO_MODE_V7,
        "results": [
            {
                "id": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "goldTextParse": {"status": "ok", "fields": case["expectedFields"], "warnings": {}},
                "recognizedTextParse": {
                    "speechAnalyzer": {"status": "skipped"},
                    "sfSpeechRecognizer": {"status": "skipped"},
                },
                "asr": {},
            }
        ],
    }
    report_path = tmp_path / "report.json"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    summary = score_candidate_report(report_path, tmp_path / "scored")
    assert summary["holdoutV7Sha256"] == manifest["corpusSha256"]
    assert summary["byLocale"]["en"]["goldTextExactCases"] == 1

    report["fixtureHoldoutV7Sha256"] = "stale"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    with pytest.raises(ValueError, match="different corpus"):
        score_candidate_report(report_path, tmp_path / "stale")


def test_fifth_holdout_scorer_checks_corpus_hash(tmp_path) -> None:
    manifest = write_v8_cases()
    case = make_v8_cases()[0]
    report = {
        "platform": "iOS",
        "systemVersion": "26.6",
        "deviceModel": "iPhone",
        "fixtureSplit": "freeformHoldoutV8",
        "fixtureRegressionSha256": "regression-hash",
        "fixtureHoldoutV8Sha256": manifest["corpusSha256"],
        "fixtureAudioManifestSha256": None,
        "fixtureAudioMode": AUDIO_MODE_V8,
        "results": [
            {
                "id": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "goldTextParse": {"status": "ok", "fields": case["expectedFields"], "warnings": {}},
                "recognizedTextParse": {
                    "speechAnalyzer": {"status": "skipped"},
                    "sfSpeechRecognizer": {"status": "skipped"},
                },
                "asr": {},
            }
        ],
    }
    report_path = tmp_path / "report.json"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    summary = score_candidate_report(report_path, tmp_path / "scored")
    assert summary["holdoutV8Sha256"] == manifest["corpusSha256"]

    report["fixtureHoldoutV8Sha256"] = "stale"
    report_path.write_text(json.dumps(report), encoding="utf-8")
    with pytest.raises(ValueError, match="different corpus"):
        score_candidate_report(report_path, tmp_path / "stale")
