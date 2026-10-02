from __future__ import annotations

import json
from collections import Counter
from typing import Any

from evaluation.voice.common import FIELD_IDS, LABELS, ROOT
from evaluation.voice.freeform_development import make_cases as freeform_cases
from evaluation.voice.guided_format import SCENARIOS, selected_cases, spoken_segments
from evaluation.voice.score_candidate import score_scenarios


def test_guided_pack_follows_the_labels_and_order_shown_in_the_recording_sheet() -> None:
    catalog = json.loads((ROOT / "ios/Doglyad/Resources/Localizable.xcstrings").read_text(encoding="utf-8"))
    cases = selected_cases()
    assert len(cases) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        (locale, scenario): 31 for locale in ("en", "ru") for scenario in SCENARIOS
    }
    for locale in ("en", "ru"):
        hint = catalog["strings"]["speechProcessSpeechDescription"]["localizations"][locale]["stringUnit"]["value"]
        hinted_labels = [part.split(":", 1)[0].strip(' "«»') for part in hint.split("; ")]
        assert [label.casefold() for label in hinted_labels] == [label.casefold() for label in LABELS[locale]]
    for case in cases:
        segments = spoken_segments(case)
        included = [field for field in FIELD_IDS if field in case["expectedFields"]]
        assert len(segments) == len(included)
        assert [segment.split(":", 1)[0] for segment in segments] == [
            LABELS[case["locale"]][FIELD_IDS.index(field)] for field in included
        ]
        assert all(quote in case["spokenText"] for quote in case["expectedSourceQuotes"].values())
        if case["scenario"] == "complete":
            assert set(included) == set(FIELD_IDS)
        else:
            assert included == ["patientComplaints", "examinationDescription"]


def test_freeform_pack_has_no_recording_sheet_field_labels() -> None:
    cases = freeform_cases()
    assert len(cases) == 124
    assert Counter((case["locale"], case["scenario"]) for case in cases) == {
        (locale, scenario): 31 for locale in ("en", "ru") for scenario in ("complete", "partial")
    }
    for case in cases:
        assert not any(f"{label.casefold()}:" in case["spokenText"].casefold() for label in LABELS[case["locale"]])


def test_pack_scenario_metrics_count_failed_stages_as_non_exact() -> None:
    scored: list[dict[str, Any]] = [
        {
            "locale": "ru",
            "scenario": "complete",
            "goldTextStatus": "ok",
            "goldText": {"equivalentExactCase": True},
            "speechAnalyzerASRStatus": "ok",
            "speechAnalyzerParseStatus": "ok",
            "speechAnalyzerCorrectedWER": 0.1,
            "speechAnalyzer": {"equivalentExactCase": True, "equivalentUnnoticedWrongFields": []},
            "sfSpeechRecognizerASRStatus": "failed",
            "sfSpeechRecognizerParseStatus": "skipped",
        },
        {
            "locale": "ru",
            "scenario": "complete",
            "goldTextStatus": "failed",
            "speechAnalyzerASRStatus": "failed",
            "speechAnalyzerParseStatus": "skipped",
            "sfSpeechRecognizerASRStatus": "failed",
            "sfSpeechRecognizerParseStatus": "skipped",
        },
    ]
    metrics = score_scenarios(scored, ("complete",))["ru/complete"]
    assert metrics["cases"] == 2
    assert metrics["goldTextExactCases"] == 1
    assert metrics["speechAnalyzer"]["asrCompleted"] == 1
    assert metrics["speechAnalyzer"]["asrAttempted"] == 2
    assert metrics["speechAnalyzer"]["exactCases"] == 1
    assert metrics["speechAnalyzer"]["meanWER"] == 0.1
    assert metrics["sfSpeechRecognizer"]["exactCases"] == 0
    assert metrics["sfSpeechRecognizer"]["parseAttempted"] == 0
    assert metrics["sfSpeechRecognizer"]["meanWER"] is None
